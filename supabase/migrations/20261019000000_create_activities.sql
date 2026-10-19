-- activities: 등산 기록 요약. 경로(GPX)는 Storage의 tracks 버킷에 따로 저장한다.
-- id는 기기에서 만든 UUID를 그대로 쓴다. 같은 기록을 다시 올려도 upsert라 중복되지 않는다.

create table public.activities (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  title text not null,
  started_at timestamptz not null,
  ended_at timestamptz not null,
  elapsed_s integer not null check (elapsed_s >= 0),
  moving_s integer not null check (moving_s >= 0),
  distance_m double precision not null check (distance_m >= 0),
  elevation_gain_m double precision not null check (elevation_gain_m >= 0),
  max_altitude_m double precision,
  point_count integer not null check (point_count >= 0),
  -- tracks 버킷 안의 경로: {user_id}/{id}.gpx
  gpx_path text,
  is_flagged boolean not null default false,
  -- 2단계 코스 매칭에서 채운다. (courses 테이블을 만들 때 외래 키를 건다)
  course_id uuid,
  -- 시연용 데이터 표시 (CLAUDE.md 6-2장)
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index activities_user_started_idx
  on public.activities (user_id, started_at desc);

-- RLS: 1단계 정책은 "본인 행만 읽기·쓰기"
alter table public.activities enable row level security;

create policy "activities: 본인 행 읽기"
  on public.activities for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "activities: 본인 행 추가"
  on public.activities for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "activities: 본인 행 수정"
  on public.activities for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "activities: 본인 행 삭제"
  on public.activities for delete
  to authenticated
  using ((select auth.uid()) = user_id);

-- Data API 노출 ("Automatically expose new tables"를 끈 상태라 직접 열어 준다)
grant select, insert, update, delete on public.activities to authenticated;

-- 수정할 때마다 updated_at 갱신
create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger activities_set_updated_at
  before update on public.activities
  for each row execute function public.set_updated_at();

-- Storage: GPX 파일을 담는 비공개 버킷
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('tracks', 'tracks', false, 10485760, array['application/gpx+xml'])
on conflict (id) do nothing;

-- 경로의 첫 폴더가 본인 user_id인 파일만 읽기·쓰기 가능
create policy "tracks: 본인 폴더 읽기"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'tracks'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "tracks: 본인 폴더 올리기"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'tracks'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- 같은 파일을 다시 올릴 때(upsert) 필요
create policy "tracks: 본인 폴더 덮어쓰기"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'tracks'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'tracks'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "tracks: 본인 폴더 지우기"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'tracks'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
