-- 2단계: 경쟁(정복 랭킹)
-- 완주 판정은 앱이 하고(코스 매칭), 랭킹 계산은 이 파일의 함수들이 DB에서 한다.
-- 먼저 20261020000000_create_courses.sql을 실행해야 한다.

------------------------------------------------------------
-- 1. 프로필: 닉네임 태그(#0000), 프로필 사진, 시연용 표시
------------------------------------------------------------
alter table public.profiles
  add column nickname_tag text,
  add column avatar_url text,
  add column is_demo boolean not null default false;

-- 이 닉네임에서 아직 안 쓴 4자리 태그를 고른다.
create function public.free_nickname_tag(p_nickname text)
returns text
language plpgsql
volatile
set search_path = ''
as $$
declare
  v_tag text;
begin
  for i in 1..50 loop
    v_tag := lpad((floor(random() * 10000))::integer::text, 4, '0');
    if not exists (
      select 1 from public.profiles
      where nickname = p_nickname and nickname_tag = v_tag
    ) then
      return v_tag;
    end if;
  end loop;
  raise exception '닉네임 %에 남은 태그가 없어요', p_nickname;
end;
$$;

-- 이미 가입한 사용자에게 태그를 하나씩 준다.
do $$
declare
  r record;
begin
  for r in select id, nickname from public.profiles where nickname_tag is null loop
    update public.profiles
    set nickname_tag = public.free_nickname_tag(r.nickname)
    where id = r.id;
  end loop;
end;
$$;

-- 카카오·구글 프로필 사진
update public.profiles p
set avatar_url = coalesce(
  nullif(u.raw_user_meta_data ->> 'avatar_url', ''),
  nullif(u.raw_user_meta_data ->> 'picture', '')
)
from auth.users u
where u.id = p.id;

alter table public.profiles
  alter column nickname_tag set not null,
  add constraint profiles_nickname_tag_format check (nickname_tag ~ '^[0-9]{4}$'),
  add constraint profiles_nickname_tag_unique unique (nickname, nickname_tag);

-- 가입할 때 태그·프로필 사진·시연용 표시까지 채운다. (기존 함수를 바꾼다)
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_nickname text;
begin
  v_nickname := coalesce(
    nullif(new.raw_user_meta_data ->> 'name', ''),
    nullif(new.raw_user_meta_data ->> 'full_name', ''),
    '등산객' || upper(substr(replace(new.id::text, '-', ''), 1, 4))
  );
  insert into public.profiles (id, nickname, nickname_tag, avatar_url, is_demo)
  values (
    new.id,
    v_nickname,
    public.free_nickname_tag(v_nickname),
    coalesce(
      nullif(new.raw_user_meta_data ->> 'avatar_url', ''),
      nullif(new.raw_user_meta_data ->> 'picture', '')
    ),
    coalesce((new.raw_app_meta_data ->> 'demo')::boolean, false)
  );
  return new;
end;
$$;

revoke execute on function public.free_nickname_tag(text) from public, anon, authenticated;

------------------------------------------------------------
-- 2. 완주 기록
------------------------------------------------------------
-- 시즌: 상반기(1~6월) H1 / 하반기(7~12월) H2, 한국 시간 기준. 예: 2026-H2
create function public.season_of(p_time timestamptz)
returns text
language sql
stable
set search_path = ''
as $$
  select to_char(p_time at time zone 'Asia/Seoul', 'YYYY')
    || '-H'
    || case when extract(month from p_time at time zone 'Asia/Seoul') <= 6
         then '1' else '2' end;
$$;

create table public.course_completions (
  id uuid primary key default gen_random_uuid(),
  -- 어떤 기록으로 완주했는지 (시연용 데이터는 null)
  activity_id uuid references public.activities (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  course_id uuid not null references public.courses (id) on delete cascade,
  -- 들머리 → 정상 등정 시간(초). 하산은 넣지 않는다.
  ascent_s integer not null check (ascent_s > 0),
  -- 정상에 도착한 시각
  completed_at timestamptz not null,
  season text not null,
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  unique (activity_id, course_id)
);

create index course_completions_course_season_idx
  on public.course_completions (course_id, season);
create index course_completions_user_idx
  on public.course_completions (user_id);

-- 본인 완주 기록만 직접 읽을 수 있다. 넣기는 아래 함수로만 한다.
alter table public.course_completions enable row level security;

create policy "course_completions: 본인 행 읽기"
  on public.course_completions for select
  to authenticated
  using ((select auth.uid()) = user_id);

grant select on public.course_completions to authenticated;

-- 앱이 판정한 완주 결과를 저장한다. 같은 기록을 다시 올리면 결과를 바꿔 넣는다.
-- p_completions: [{"course_id": "...", "ascent_s": 2700, "completed_at": "2026-10-20T01:30:00Z"}, ...]
create function public.record_course_completions(
  p_activity_id uuid,
  p_completions jsonb
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

  delete from public.course_completions where activity_id = p_activity_id;

  -- 속도 이상 표시가 있는 기록은 완주로 인정하지 않는다. (CLAUDE.md 6-2장)
  if v_flagged then
    return 0;
  end if;

  insert into public.course_completions
    (activity_id, user_id, course_id, ascent_s, completed_at, season)
  select
    p_activity_id,
    v_user,
    (c ->> 'course_id')::uuid,
    (c ->> 'ascent_s')::integer,
    (c ->> 'completed_at')::timestamptz,
    public.season_of((c ->> 'completed_at')::timestamptz)
  from jsonb_array_elements(p_completions) as c
  where exists (
    select 1 from public.courses co where co.id = (c ->> 'course_id')::uuid
  );

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

------------------------------------------------------------
-- 3. 랭킹 (다른 사용자에게는 순위·닉네임#태그·프로필 사진·기록만 보인다)
------------------------------------------------------------
-- 랭킹에서 볼 수 있는 줄 수. 일반 사용자는 10명(+ 내 순위).
-- 구독 기능을 만들 때 구독자는 전체를 보도록 이 함수만 바꾼다. (권한은 DB에서 검사)
create function public.ranking_visible_rows()
returns integer
language sql
stable
set search_path = ''
as $$
  select 10;
$$;

-- p_kind: 'most'(최다완등) 또는 'fastest'(최단시간)
-- p_season: '2026-H2' 같은 시즌, null이면 역대 기록(명예의 전당)
-- score: 최다완등이면 완주 횟수, 최단시간이면 가장 빠른 등정 시간(초)
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
  is_me boolean
)
language sql
stable
security definer
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
      -- 정렬 키: 최단시간은 작을수록, 최다완등은 클수록 앞
      case when p_kind = 'fastest' then pu.best else -pu.times end as sort_key,
      -- 같은 기록이면 먼저 달성한 사람이 앞
      case when p_kind = 'fastest' then pu.first_at else pu.last_at end as tie_at
    from per_user pu
  ),
  ranked as (
    select
      s.*,
      (rank() over (order by s.sort_key))::integer as rank_no,
      row_number() over (order by s.sort_key, s.tie_at) as row_no
    from scored s
  )
  select
    r.rank_no,
    p.nickname,
    p.nickname_tag,
    p.avatar_url,
    r.score,
    r.user_id = auth.uid() as is_me
  from ranked r
  join public.profiles p on p.id = r.user_id
  where r.row_no <= public.ranking_visible_rows()
     or r.user_id = auth.uid()
  order by r.row_no;
$$;

-- 코스 상세 위쪽 요약: 완주 수, 평균 등정 시간, 내 최고 기록, 내 완주 수
create function public.get_course_stats(p_course_id uuid)
returns table (
  completion_count integer,
  average_ascent_s integer,
  my_best_ascent_s integer,
  my_count integer
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    count(*)::integer,
    round(avg(cc.ascent_s))::integer,
    min(cc.ascent_s) filter (where cc.user_id = auth.uid()),
    (count(*) filter (where cc.user_id = auth.uid()))::integer
  from public.course_completions cc
  where cc.course_id = p_course_id;
$$;

-- 지도에 표시할 코스별 정복자 (시즌 기준). 코스마다 최다완등·최단시간 1명씩.
create function public.get_conquerors(p_season text)
returns table (
  course_id uuid,
  kind text,
  nickname text,
  nickname_tag text,
  avatar_url text,
  score integer
)
language sql
stable
security definer
set search_path = ''
as $$
  with per_user as (
    select
      cc.course_id,
      cc.user_id,
      count(*)::integer as times,
      min(cc.ascent_s) as best,
      min(cc.completed_at) as first_at,
      max(cc.completed_at) as last_at
    from public.course_completions cc
    where cc.season = p_season
    group by cc.course_id, cc.user_id
  ),
  most as (
    select distinct on (pu.course_id) pu.course_id, pu.user_id, pu.times as score
    from per_user pu
    order by pu.course_id, pu.times desc, pu.last_at asc
  ),
  fastest as (
    select distinct on (pu.course_id) pu.course_id, pu.user_id, pu.best as score
    from per_user pu
    order by pu.course_id, pu.best asc, pu.first_at asc
  )
  select m.course_id, 'most'::text, p.nickname, p.nickname_tag, p.avatar_url, m.score
  from most m join public.profiles p on p.id = m.user_id
  union all
  select f.course_id, 'fastest'::text, p.nickname, p.nickname_tag, p.avatar_url, f.score
  from fastest f join public.profiles p on p.id = f.user_id;
$$;

-- 함수 실행 권한: 로그인한 사용자만
revoke execute on function public.record_course_completions(uuid, jsonb) from public, anon;
revoke execute on function public.get_course_ranking(uuid, text, text) from public, anon;
revoke execute on function public.get_course_stats(uuid) from public, anon;
revoke execute on function public.get_conquerors(text) from public, anon;
grant execute on function public.record_course_completions(uuid, jsonb) to authenticated;
grant execute on function public.get_course_ranking(uuid, text, text) to authenticated;
grant execute on function public.get_course_stats(uuid) to authenticated;
grant execute on function public.get_conquerors(text) to authenticated;
