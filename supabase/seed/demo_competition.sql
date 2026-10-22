-- 시연용 경쟁 데이터 (개발용 Supabase 프로젝트에서만 실행한다. CLAUDE.md 6-2장)
-- 먼저 migrations/20261021000000_create_competition.sql 과 seed/courses.sql 을 실행해야 한다.
-- 여러 번 실행해도 된다. (실행할 때마다 시연용 완주 기록을 지우고 다시 넣는다)
-- 시연용 데이터는 직접 만든 코스 4개에만 넣는다. 자동 생성 코스(slug가 auto-로 시작)에는 넣지 않는다.
-- 지우는 방법은 맨 아래에 있다.

begin;

------------------------------------------------------------
-- 1. 시연용 사용자 12명 (로그인은 할 수 없는 계정)
--    가입 트리거가 프로필(닉네임#태그)을 만들고, demo 표시로 profiles.is_demo = true가 된다.
------------------------------------------------------------
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change
)
select
  '00000000-0000-0000-0000-000000000000',
  ('d0000000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid,
  'authenticated',
  'authenticated',
  'demo' || n || '@hikingapp.invalid',
  '',
  now(),
  '{"provider": "demo", "providers": ["demo"], "demo": true}'::jsonb,
  jsonb_build_object('name', name),
  now(),
  now(),
  '', '', '', ''
from (values
  (1, '산타는다람쥐'), (2, '고당봉지킴이'), (3, '주말산꾼'), (4, '억새바람'),
  (5, '새벽등산러'), (6, '부산산악회장'), (7, '천천히오르기'), (8, '금정산토박이'),
  (9, '하단동산책'), (10, '정상인증샷'), (11, '등산초보'), (12, '바위타는곰')
) as d(n, name)
on conflict (id) do nothing;

------------------------------------------------------------
-- 2. 시연용 완주 기록
------------------------------------------------------------
delete from public.course_completions where is_demo;

-- 하반기(이번 시즌): 사람·코스마다 1~5회, 공식 시간의 75~135% 사이 기록
insert into public.course_completions
  (user_id, course_id, ascent_s, completed_at, season, is_demo)
select
  ('d0000000-0000-4000-8000-' || lpad(u.n::text, 12, '0'))::uuid,
  c.id,
  greatest(
    300,
    (coalesce(c.official_time_min, 60) * 60
      * (0.75 + ((u.n * 7 + c.n * 3 + g) % 11) * 0.06))::integer
  ),
  t.at,
  public.season_of(t.at),
  true
from generate_series(1, 12) as u(n)
cross join (
  select id, official_time_min, (row_number() over (order by slug))::integer as n
  from public.courses
  where slug not like 'auto-%'  -- 자동 생성 코스에는 시연용 기록을 넣지 않는다
) as c
cross join lateral generate_series(1, ((u.n + c.n) % 5) + 1) as g
cross join lateral (
  select timestamptz '2026-07-05 09:00:00+09'
    + ((u.n * 13 + c.n * 5 + g * 9) % 100) * interval '1 day' as at
) as t;

-- 상반기(지난 시즌): 1~4번 사용자의 아주 빠른 기록. 명예의 전당(역대)에만 보인다.
insert into public.course_completions
  (user_id, course_id, ascent_s, completed_at, season, is_demo)
select
  ('d0000000-0000-4000-8000-' || lpad(u.n::text, 12, '0'))::uuid,
  c.id,
  greatest(300, (coalesce(c.official_time_min, 60) * 60 * (0.55 + u.n * 0.03))::integer),
  t.at,
  public.season_of(t.at),
  true
from generate_series(1, 4) as u(n)
cross join (
  select * from public.courses where slug not like 'auto-%'
) as c
cross join lateral (
  select timestamptz '2026-04-12 08:00:00+09' + u.n * interval '7 days' as at
) as t;

------------------------------------------------------------
-- 3. 김세민 구글 계정의 시연용 완주 기록
--    금정산 범어사 코스는 6회(최다완등 정복자), 승학산 동아대 코스는 1회(순위 밖 "내 순위" 확인용)
--    이름으로 찾지 못하면 건너뛴다. 이때는 아래 이름 조건을 실제 구글 이름이나 이메일로 바꾼다.
------------------------------------------------------------
do $$
declare
  v_me uuid;
begin
  select id into v_me
  from auth.users
  where raw_app_meta_data ->> 'provider' = 'google'
    and (raw_user_meta_data ->> 'full_name' = '김세민'
      or raw_user_meta_data ->> 'name' = '김세민')
  order by created_at
  limit 1;

  if v_me is null then
    raise notice '김세민 구글 계정을 찾지 못해 내 시연 기록은 건너뛰었어요.';
    return;
  end if;

  insert into public.course_completions
    (user_id, course_id, ascent_s, completed_at, season, is_demo)
  select v_me, c.id, 2700 + g * 60, at, public.season_of(at), true
  from public.courses c
  cross join generate_series(1, 6) as g
  cross join lateral (
    select timestamptz '2026-08-02 07:30:00+09' + g * interval '9 days' as at
  ) as t
  where c.slug = 'geumjeongsan-beomeosa';

  insert into public.course_completions
    (user_id, course_id, ascent_s, completed_at, season, is_demo)
  select v_me, c.id, 1800, timestamptz '2026-09-21 10:00:00+09',
    public.season_of(timestamptz '2026-09-21 10:00:00+09'), true
  from public.courses c
  where c.slug = 'seunghaksan-donga';

  raise notice '김세민 계정(%)에 시연용 완주 기록을 넣었어요.', v_me;
end;
$$;

commit;

------------------------------------------------------------
-- 시연용 데이터 지우기 (필요할 때 아래 두 줄의 주석을 풀고 실행)
------------------------------------------------------------
-- delete from public.course_completions where is_demo;
-- delete from auth.users where raw_app_meta_data ->> 'demo' = 'true';
