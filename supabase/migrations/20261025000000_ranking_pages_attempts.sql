-- 랭킹·리뷰 나눠 받기, 코스 진행률(중도 하산 기록), 리뷰 작성 자격 변경
-- 먼저 20261021000000_create_competition.sql, 20261022000000_create_reviews_and_subscriptions.sql을 실행해야 한다.
--
-- - 코스 상세: 랭킹은 누구나 상위 10명 + 내 순위, 리뷰는 최근 3개만 받는다.
-- - 전체 순위(프리미엄)·전체 리뷰는 별도 화면에서 30개씩 나눠 받는다. (전송량 절약)
-- - 정상까지 가지 않은 산행도 코스를 몇 %까지 갔는지 남긴다. 랭킹에는 완주만 들어간다.
-- - 리뷰는 완주했거나 코스의 40% 이상 다녀온 사람이 쓸 수 있다. 조망 점수는 완주한 사람만 매긴다.

------------------------------------------------------------
-- 1. 랭킹
------------------------------------------------------------
-- 순위 계산을 한 곳에 모은다. (직접 부르지 않고 아래 함수들 안에서만 쓴다)
create function public.course_ranked(
  p_course_id uuid,
  p_kind text,
  p_season text
)
returns table (
  user_id uuid,
  score integer,
  rank_no integer,
  row_no bigint
)
language sql
stable
set search_path = ''
as $$
  with per_user as (
    select
      cc.user_id,
      count(*)::integer as times,
      min(cc.ascent_s) as best,
      min(cc.completed_at) as first_at,
      max(cc.completed_at) as last_at
    from public.course_completions cc
    where cc.course_id = p_course_id
      and (p_season is null or cc.season = p_season)
    group by cc.user_id
  ),
  scored as (
    select
      pu.user_id,
      case when p_kind = 'fastest' then pu.best else pu.times end as score,
      case when p_kind = 'fastest' then pu.best else -pu.times end as sort_key,
      case when p_kind = 'fastest' then pu.first_at else pu.last_at end as tie_at
    from per_user pu
  )
  select
    s.user_id,
    s.score,
    (rank() over (order by s.sort_key))::integer,
    row_number() over (order by s.sort_key, s.tie_at)
  from scored s;
$$;

revoke execute on function public.course_ranked(uuid, text, text)
  from public, anon, authenticated;

-- 코스 상세용: 누구나 상위 10명 + 내 순위. total_count는 순위에 오른 전체 인원.
drop function public.get_course_ranking(uuid, text, text);

create function public.get_course_ranking(
  p_course_id uuid,
  p_kind text,
  p_season text default null
)
returns table (
  rank_no integer,
  nickname text,
  nickname_tag text,
  avatar_url text,
  score integer,
  is_me boolean,
  total_count integer
)
language sql
stable
security definer
set search_path = ''
as $$
  with ranked as (
    select r.*, (count(*) over ())::integer as total
    from public.course_ranked(p_course_id, p_kind, p_season) r
  )
  select
    r.rank_no,
    p.nickname,
    p.nickname_tag,
    p.avatar_url,
    r.score,
    r.user_id = auth.uid(),
    r.total
  from ranked r
  join public.profiles p on p.id = r.user_id
  where r.row_no <= 10 or r.user_id = auth.uid()
  order by r.row_no;
$$;

-- 전체 순위 화면용: 30명씩 나눠 받는다. 볼 수 있는 범위는 ranking_visible_rows()가 정한다
-- (구독자 전체, 일반 사용자 10명 + 내 순위). p_query로 닉네임#태그를 찾을 수 있다.
create function public.get_course_ranking_page(
  p_course_id uuid,
  p_kind text,
  p_season text default null,
  p_offset integer default 0,
  p_limit integer default 30,
  p_query text default null
)
returns table (
  rank_no integer,
  nickname text,
  nickname_tag text,
  avatar_url text,
  score integer,
  is_me boolean,
  total_count integer
)
language sql
stable
security definer
set search_path = ''
as $$
  with visible as (
    select r.*, p.nickname, p.nickname_tag, p.avatar_url
    from public.course_ranked(p_course_id, p_kind, p_season) r
    join public.profiles p on p.id = r.user_id
    where r.row_no <= public.ranking_visible_rows() or r.user_id = auth.uid()
  ),
  filtered as (
    select v.*, (count(*) over ())::integer as total
    from visible v
    where coalesce(trim(p_query), '') = ''
       or position(lower(trim(p_query)) in lower(v.nickname || '#' || v.nickname_tag)) > 0
  )
  select f.rank_no, f.nickname, f.nickname_tag, f.avatar_url, f.score,
    f.user_id = auth.uid(), f.total
  from filtered f
  order by f.row_no
  offset greatest(p_offset, 0)
  limit least(greatest(p_limit, 1), 100);
$$;

revoke execute on function public.get_course_ranking(uuid, text, text) from public, anon;
revoke execute on function public.get_course_ranking_page(uuid, text, text, integer, integer, text)
  from public, anon;
grant execute on function public.get_course_ranking(uuid, text, text) to authenticated;
grant execute on function public.get_course_ranking_page(uuid, text, text, integer, integer, text)
  to authenticated;

------------------------------------------------------------
-- 2. 코스 진행률 (정상까지 가지 않은 산행)
------------------------------------------------------------
create table public.course_attempts (
  activity_id uuid references public.activities (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  course_id uuid not null references public.courses (id) on delete cascade,
  -- 들머리에서 출발해 코스를 따라 간 비율 (0~1). 완주한 코스는 course_completions에 넣는다.
  progress real not null check (progress > 0 and progress <= 1),
  attempted_at timestamptz not null,
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  unique (activity_id, course_id)
);

create index course_attempts_user_course_idx
  on public.course_attempts (user_id, course_id);

alter table public.course_attempts enable row level security;

create policy "course_attempts: 본인 행 읽기"
  on public.course_attempts for select
  to authenticated
  using ((select auth.uid()) = user_id);

grant select on public.course_attempts to authenticated;

-- 앱이 계산한 진행률을 저장한다. 같은 기록을 다시 올리면 바꿔 넣는다.
-- p_attempts: [{"course_id": "...", "progress": 0.62, "attempted_at": "2026-10-20T01:30:00Z"}, ...]
create function public.record_course_attempts(
  p_activity_id uuid,
  p_attempts jsonb
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_flagged boolean;
  v_count integer;
begin
  select a.is_flagged into v_flagged
  from public.activities a
  where a.id = p_activity_id and a.user_id = v_user;

  if not found then
    raise exception '내 기록이 아니거나 아직 서버에 없는 기록이에요'
      using errcode = '42501';
  end if;

  delete from public.course_attempts where activity_id = p_activity_id;

  -- 속도 이상 기록은 완주와 마찬가지로 진행률도 인정하지 않는다.
  if v_flagged then
    return 0;
  end if;

  insert into public.course_attempts
    (activity_id, user_id, course_id, progress, attempted_at)
  select
    p_activity_id,
    v_user,
    (a ->> 'course_id')::uuid,
    least(1, greatest(0.01, (a ->> 'progress')::real)),
    (a ->> 'attempted_at')::timestamptz
  from jsonb_array_elements(p_attempts) as a
  where exists (
    select 1 from public.courses co where co.id = (a ->> 'course_id')::uuid
  );

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke execute on function public.record_course_attempts(uuid, jsonb) from public, anon;
grant execute on function public.record_course_attempts(uuid, jsonb) to authenticated;

------------------------------------------------------------
-- 3. 리뷰
------------------------------------------------------------
-- 조망은 정상까지 간 사람만 매긴다. 중도 하산 후기는 조망이 비어 있다.
alter table public.course_reviews alter column view drop not null;

-- 리뷰 쓰기 자격: 완주했거나, 이 코스를 40% 이상 다녀왔다.
create or replace function public.upsert_my_review(
  p_course_id uuid,
  p_difficulty smallint,
  p_risk smallint,
  p_view smallint,
  p_crowd smallint,
  p_comment text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_completed boolean;
begin
  v_completed := exists (
    select 1 from public.course_completions cc
    where cc.course_id = p_course_id and cc.user_id = auth.uid()
  );

  if not v_completed and not exists (
    select 1 from public.course_attempts a
    where a.course_id = p_course_id and a.user_id = auth.uid()
      and a.progress >= 0.4
  ) then
    raise exception '이 코스를 40%% 이상 다녀온 사람만 리뷰를 쓸 수 있어요'
      using errcode = '42501';
  end if;

  insert into public.course_reviews
    (course_id, user_id, difficulty, risk, view, crowd, comment)
  values (
    p_course_id, auth.uid(), p_difficulty, p_risk,
    -- 완주하지 않았으면 조망은 비워 둔다.
    case when v_completed then p_view end,
    p_crowd,
    nullif(trim(p_comment), '')
  )
  on conflict (course_id, user_id) do update set
    difficulty = excluded.difficulty,
    risk = excluded.risk,
    view = excluded.view,
    crowd = excluded.crowd,
    comment = excluded.comment,
    updated_at = now();
end;
$$;

-- 리뷰 목록: 나눠 받기, 정렬(recent 최신순 / completions 완등 많은 순),
-- 작성자의 이 코스 완등 횟수와 최대 진행률(완등이 없을 때 보여 준다)
drop function public.get_course_reviews(uuid);

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
  total_count integer
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
    (count(*) over ())::integer
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
