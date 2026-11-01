-- 사진 올리기: 프로필 사진, 산행 기록 사진(본인만, 프리미엄), 리뷰 사진(모두 공개)
-- 먼저 20261026000000_my_lead_runs.sql까지 실행해야 한다.
--
-- 사진은 기기에서 줄이고 위치 정보(EXIF)를 지운 JPEG만 올린다. DB에는 Storage 경로만 둔다. (CLAUDE.md 7장)
-- 버킷 경로의 첫 폴더는 항상 본인 user_id다.
--   avatars        (공개) {user_id}/{사진 id}.jpg
--   activity-photos (비공개) {user_id}/{activity_id}/{사진 id}.jpg
--   review-photos  (공개) {user_id}/{course_id}/{사진 id}.jpg

------------------------------------------------------------
-- 1. Storage 버킷과 권한
------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars', 'avatars', true, 5242880, array['image/jpeg']),
  ('activity-photos', 'activity-photos', false, 5242880, array['image/jpeg']),
  ('review-photos', 'review-photos', true, 5242880, array['image/jpeg'])
on conflict (id) do nothing;

-- 공개 버킷은 주소만 알면 누구나 볼 수 있다(목록 조회는 막는다). 비공개 버킷은 본인만 읽는다.
create policy "activity-photos: 본인 폴더 읽기"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'activity-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- 산행 기록 사진은 프리미엄 구독자만 올린다. (권한은 DB에서 검사)
create policy "activity-photos: 구독자 본인 폴더 올리기"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'activity-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and (select public.is_subscriber())
  );

create policy "photos: 본인 폴더 올리기"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id in ('avatars', 'review-photos')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- 지우기는 구독이 끝나도 할 수 있다.
create policy "photos: 본인 폴더 지우기"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id in ('avatars', 'activity-photos', 'review-photos')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

------------------------------------------------------------
-- 2. 산행 기록 사진 (본인만, 기록 하나에 10장까지)
------------------------------------------------------------
create table public.activity_photos (
  id uuid primary key,
  activity_id uuid not null references public.activities (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  path text not null unique,
  created_at timestamptz not null default now()
);

create index activity_photos_activity_idx on public.activity_photos (activity_id);

alter table public.activity_photos enable row level security;

create policy "activity_photos: 본인 행 읽기"
  on public.activity_photos for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "activity_photos: 구독자 본인 기록에 추가"
  on public.activity_photos for insert
  to authenticated
  with check (
    (select auth.uid()) = user_id
    and (select public.is_subscriber())
    and exists (
      select 1 from public.activities a
      where a.id = activity_id and a.user_id = (select auth.uid())
    )
  );

create policy "activity_photos: 본인 행 지우기"
  on public.activity_photos for delete
  to authenticated
  using ((select auth.uid()) = user_id);

grant select, insert, delete on public.activity_photos to authenticated;

------------------------------------------------------------
-- 3. 리뷰 사진 (모두 공개, 리뷰 하나에 3장까지). 리뷰를 지우면 함께 지워진다.
------------------------------------------------------------
create table public.review_photos (
  id uuid primary key,
  course_id uuid not null,
  user_id uuid not null,
  path text not null unique,
  created_at timestamptz not null default now(),
  foreign key (course_id, user_id)
    references public.course_reviews (course_id, user_id) on delete cascade
);

create index review_photos_review_idx on public.review_photos (course_id, user_id);

alter table public.review_photos enable row level security;

-- 다른 사람 리뷰의 사진은 get_course_reviews로 받는다.
create policy "review_photos: 본인 행 읽기"
  on public.review_photos for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "review_photos: 본인 리뷰에 추가"
  on public.review_photos for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "review_photos: 본인 행 지우기"
  on public.review_photos for delete
  to authenticated
  using ((select auth.uid()) = user_id);

grant select, insert, delete on public.review_photos to authenticated;

-- 장수 제한 (산행 기록 10장, 리뷰 3장)
create function public.check_photo_limit()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_count integer;
begin
  if tg_table_name = 'activity_photos' then
    select count(*) into v_count from public.activity_photos
    where activity_id = new.activity_id;
    if v_count >= 10 then
      raise exception '산행 기록 사진은 10장까지 올릴 수 있어요' using errcode = '23514';
    end if;
  else
    select count(*) into v_count from public.review_photos
    where course_id = new.course_id and user_id = new.user_id;
    if v_count >= 3 then
      raise exception '리뷰 사진은 3장까지 올릴 수 있어요' using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;

create trigger activity_photos_limit
  before insert on public.activity_photos
  for each row execute function public.check_photo_limit();

create trigger review_photos_limit
  before insert on public.review_photos
  for each row execute function public.check_photo_limit();

------------------------------------------------------------
-- 4. 프로필 사진: 직접 올린 사진으로 바꾸거나 카카오·구글 사진으로 되돌린다.
------------------------------------------------------------
-- 직접 올린 사진의 Storage 경로. null이면 카카오·구글 사진을 쓰는 중이다.
alter table public.profiles add column custom_avatar_path text;

-- p_url은 avatars 버킷의 공개 주소. 이전에 올린 사진 경로를 돌려준다(앱이 그 파일을 지운다).
create function public.set_my_avatar(p_path text, p_url text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_old text;
begin
  if p_path is null
    or p_path not like v_user::text || '/%'
    or p_url not like '%/storage/v1/object/public/avatars/' || p_path then
    raise exception '내 프로필 사진 경로가 아니에요' using errcode = '42501';
  end if;

  select custom_avatar_path into v_old from public.profiles where id = v_user;
  update public.profiles
  set avatar_url = p_url, custom_avatar_path = p_path
  where id = v_user;
  return v_old;
end;
$$;

-- 카카오·구글 프로필 사진으로 되돌린다. 지워야 할 이전 사진 경로를 돌려준다.
create function public.reset_my_avatar()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_old text;
begin
  select custom_avatar_path into v_old from public.profiles where id = v_user;
  update public.profiles p
  set custom_avatar_path = null,
    avatar_url = (
      select coalesce(
        nullif(u.raw_user_meta_data ->> 'avatar_url', ''),
        nullif(u.raw_user_meta_data ->> 'picture', '')
      )
      from auth.users u where u.id = v_user
    )
  where p.id = v_user;
  return v_old;
end;
$$;

revoke execute on function public.set_my_avatar(text, text) from public, anon;
revoke execute on function public.reset_my_avatar() from public, anon;
grant execute on function public.set_my_avatar(text, text) to authenticated;
grant execute on function public.reset_my_avatar() to authenticated;

------------------------------------------------------------
-- 5. 리뷰 목록에 사진 경로를 더한다. (반환 형태가 바뀌어 다시 만든다)
------------------------------------------------------------
drop function public.get_course_reviews(uuid, text, integer, integer);

create function public.get_course_reviews(
  p_course_id uuid,
  p_sort text default 'recent',
  p_offset integer default 0,
  p_limit integer default 30
)
returns table (
  nickname text,
  nickname_tag text,
  avatar_url text,
  difficulty smallint,
  risk smallint,
  view smallint,
  crowd smallint,
  comment text,
  updated_at timestamptz,
  is_mine boolean,
  completion_count integer,
  best_progress real,
  total_count integer,
  photo_paths text[]
)
language sql
stable
security definer
set search_path = ''
as $$
  with base as (
    select
      r.*,
      (select count(*)::integer from public.course_completions cc
        where cc.course_id = r.course_id and cc.user_id = r.user_id) as completions,
      (select max(a.progress) from public.course_attempts a
        where a.course_id = r.course_id and a.user_id = r.user_id) as progress
    from public.course_reviews r
    where r.course_id = p_course_id
  )
  select p.nickname, p.nickname_tag, p.avatar_url,
    b.difficulty, b.risk, b.view, b.crowd, b.comment, b.updated_at,
    b.user_id = auth.uid(),
    b.completions,
    b.progress,
    (count(*) over ())::integer,
    coalesce(
      (select array_agg(ph.path order by ph.created_at)
        from public.review_photos ph
        where ph.course_id = b.course_id and ph.user_id = b.user_id),
      '{}'
    )
  from base b
  join public.profiles p on p.id = b.user_id
  order by
    case when p_sort = 'completions' then b.completions end desc nulls last,
    b.updated_at desc
  offset greatest(p_offset, 0)
  limit least(greatest(p_limit, 1), 100);
$$;

revoke execute on function public.get_course_reviews(uuid, text, integer, integer) from public, anon;
grant execute on function public.get_course_reviews(uuid, text, integer, integer) to authenticated;
