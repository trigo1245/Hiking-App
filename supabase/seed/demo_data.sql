-- 시연용 데이터: 기존 시연용 데이터를 모두 지우고 여러 상황을 확인할 수 있는 데이터를 다시 넣는다.
-- 개발용 Supabase 프로젝트에서만 실행한다. (CLAUDE.md 6-2장 "시연용 데이터")
-- 먼저 migrations/ 전부(20261025000000_ranking_pages_attempts.sql까지)와 seed/courses.sql을 실행해야 한다.
-- 여러 번 실행해도 된다.
--
-- 순서: ① 이 SQL 실행 → ② 앱 내 정보의 "시연용 기록 다시 만들기 (8개)"
--   ②는 김세민 계정의 실제 GPS 같은 기록 8개를 만들어 올린다(완주 3+1번, 62%·30% 하산, 속도 이상, 공원 산책).
--   ①이 김세민 계정의 "시연용…" 기록을 지우므로, 반드시 ①을 먼저 한다.
--
-- 코스별로 확인할 수 있는 상황 (직접 만든 코스 4개에만 넣는다. 자동 생성 코스에는 넣지 않는다)
-- ┌ 금정산 범어사: 이번 시즌 40명(30명 넘어 전체 순위 나눠 받기·검색), 같은 기록 동점,
-- │   김세민은 앱 기록 3번으로 30위권(상세에는 "내 순위"로 따로 보임, 전체 순위에서 "내 순위" 이동),
-- │   리뷰 35개(전체 보기 나눠 받기, 완등 많은 순), 중도 하산 후기 5개(조망 없음, "N%까지 다녀옴")
-- ├ 승학산 동아대: 6명, 김세민이 최다완등 정복자(지도에 사진), 최단시간은 다른 사람,
-- │   지난 시즌 기록(명예의 전당에만), 리뷰 정확히 3개(전체 보기 버튼 없음) 중 하나는 김세민 것(고치기·지우기)
-- ├ 금정산 산성마을: 이번 시즌 완주 없음("첫 정복자가 되어 보세요"), 명예의 전당만 있음,
-- │   김세민은 앱 기록으로 62% 진행 → 조망을 뺀 리뷰 쓰기, 다른 사람 중도 하산 후기
-- └ 승학산 구덕문화공원: 완주 2명, 리뷰 없음, 김세민은 앱 기록으로 30% 진행 → 아직 리뷰 못 씀

begin;

-- 김세민 구글 계정 (찾지 못하면 김세민 몫은 건너뛴다. 이때는 이름 조건을 실제 이름·이메일로 바꾼다)
create temp table demo_me on commit drop as
select id
from auth.users
where raw_app_meta_data ->> 'provider' = 'google'
  and (raw_user_meta_data ->> 'full_name' = '김세민'
    or raw_user_meta_data ->> 'name' = '김세민')
order by created_at
limit 1;

create function pg_temp.demo_user(n integer)
returns uuid
language sql
immutable
as $$ select ('d0000000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;

create temp table demo_course on commit drop as
select slug, id, coalesce(official_time_min, 60) as official
from public.courses
where slug in (
  'geumjeongsan-beomeosa', 'seunghaksan-donga',
  'geumjeongsan-sanseong', 'seunghaksan-gudeok'
);

------------------------------------------------------------
-- 1. 지우기: 시연용 행 전부 + 김세민 계정의 리뷰와 "시연용…" 기록
--    (시연용 사용자를 지우면 프로필·완주·리뷰·진행률도 함께 지워진다)
--    김세민 계정의 프리미엄 구독(앱의 시연용 결제)은 지우지 않는다.
------------------------------------------------------------
delete from public.course_reviews
where is_demo or user_id in (select id from demo_me);
delete from public.course_attempts where is_demo;
delete from public.course_completions where is_demo;
-- 앱에서 만든 시연용 기록. 완주·진행률 기록은 activity_id로 함께 지워진다.
-- (Storage의 GPX 파일은 SQL로 지울 수 없어 남는다. 필요하면 대시보드 Storage > tracks에서 지운다)
delete from public.activities
where user_id in (select id from demo_me) and title like '시연용%';
delete from auth.users where raw_app_meta_data ->> 'demo' = 'true';

------------------------------------------------------------
-- 2. 시연용 사용자 45명 (로그인할 수 없는 계정). 가입 트리거가 프로필(닉네임#태그)을 만든다.
------------------------------------------------------------
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change
)
select
  '00000000-0000-0000-0000-000000000000',
  pg_temp.demo_user(n::integer),
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
from unnest(array[
  '산타는다람쥐', '고당봉지킴이', '주말산꾼', '억새바람', '새벽등산러',
  '부산산악회장', '천천히오르기', '금정산토박이', '하단동산책', '정상인증샷',
  '등산초보', '바위타는곰', '솔바람', '능선러버', '물한모금',
  '구름위산책', '산성막걸리', '범어사종소리', '아침이슬', '등산화두켤레',
  '산딸기', '해운대산꾼', '낙동강노을', '배낭여행자', '케이블카싫어',
  '오르막장인', '내리막장인', '쉬엄쉬엄', '산새소리', '돌탑쌓기',
  '정상라면', '단풍놀이', '야간산행', '등산스틱', '계단왕',
  '숲속도서관', '산행일지', '바람막이', '초록발자국', '하산주',
  '중턱까지만', '반만올라요', '무릎조심', '오늘은여기까지', '다음엔정상'
]) with ordinality as d(name, n)
on conflict (id) do nothing;

------------------------------------------------------------
-- 3. 완주 기록
------------------------------------------------------------
-- 금정산 범어사 · 이번 시즌: 1~33번은 4~8번, 34~40번은 1~3번 (동점이 생긴다)
insert into public.course_completions
  (user_id, course_id, ascent_s, completed_at, season, is_demo)
select
  pg_temp.demo_user(u.n),
  c.id,
  (c.official * 60 * (0.75 + ((u.n * 7 + g * 3) % 11) * 0.06))::integer,
  t.at,
  public.season_of(t.at),
  true
from demo_course c
cross join generate_series(1, 40) as u(n)
cross join lateral generate_series(
  1, case when u.n <= 33 then 4 + u.n % 5 else 1 + u.n % 3 end
) as g
cross join lateral (
  select timestamptz '2026-07-05 09:00:00+09'
    + ((u.n * 13 + g * 9) % 105) * interval '1 day' as at
) as t
where c.slug = 'geumjeongsan-beomeosa';

-- 금정산 범어사 · 지난 시즌(상반기): 1~10번의 아주 빠른 기록 (명예의 전당에만 보인다)
insert into public.course_completions
  (user_id, course_id, ascent_s, completed_at, season, is_demo)
select
  pg_temp.demo_user(u.n),
  c.id,
  (c.official * 60 * (0.55 + u.n * 0.015))::integer,
  t.at,
  public.season_of(t.at),
  true
from demo_course c
cross join generate_series(1, 10) as u(n)
cross join lateral (
  select timestamptz '2026-04-05 08:00:00+09' + u.n * interval '7 days' as at
) as t
where c.slug = 'geumjeongsan-beomeosa';

-- 승학산 동아대 · 이번 시즌: 1~5번 1~3번씩, 3번 사용자가 최단시간 1위
insert into public.course_completions
  (user_id, course_id, ascent_s, completed_at, season, is_demo)
select
  pg_temp.demo_user(u.n),
  c.id,
  case when u.n = 3 and g = 1 then (c.official * 60 * 0.6)::integer
    else (c.official * 60 * (0.8 + ((u.n * 5 + g) % 7) * 0.07))::integer end,
  t.at,
  public.season_of(t.at),
  true
from demo_course c
cross join generate_series(1, 5) as u(n)
cross join lateral generate_series(1, 1 + u.n % 3) as g
cross join lateral (
  select timestamptz '2026-07-20 10:00:00+09'
    + ((u.n * 11 + g * 17) % 80) * interval '1 day' as at
) as t
where c.slug = 'seunghaksan-donga';

-- 승학산 동아대 · 지난 시즌: 6~8번
insert into public.course_completions
  (user_id, course_id, ascent_s, completed_at, season, is_demo)
select
  pg_temp.demo_user(u.n),
  c.id,
  (c.official * 60 * 0.7)::integer + u.n * 10,
  t.at,
  public.season_of(t.at),
  true
from demo_course c
cross join generate_series(6, 8) as u(n)
cross join lateral (
  select timestamptz '2026-05-10 09:00:00+09' + u.n * interval '3 days' as at
) as t
where c.slug = 'seunghaksan-donga';

-- 승학산 동아대 · 김세민 4번 (앱 기록 1번과 합쳐 5번 → 최다완등 정복자)
insert into public.course_completions
  (user_id, course_id, ascent_s, completed_at, season, is_demo)
select
  me.id,
  c.id,
  1200 + g * 30,
  t.at,
  public.season_of(t.at),
  true
from demo_me me
cross join demo_course c
cross join generate_series(1, 4) as g
cross join lateral (
  select timestamptz '2026-07-12 08:00:00+09' + g * interval '15 days' as at
) as t
where c.slug = 'seunghaksan-donga';

-- 금정산 산성마을 · 이번 시즌 완주 없음. 상반기 10~14번, 2025 하반기 15~20번 (명예의 전당에만)
insert into public.course_completions
  (user_id, course_id, ascent_s, completed_at, season, is_demo)
select
  pg_temp.demo_user(u.n),
  c.id,
  (c.official * 60 * (0.8 + (u.n % 5) * 0.05))::integer,
  t.at,
  public.season_of(t.at),
  true
from demo_course c
cross join generate_series(10, 20) as u(n)
cross join lateral (
  select case when u.n <= 14
    then timestamptz '2026-05-03 09:00:00+09' + (u.n - 10) * interval '5 days'
    else timestamptz '2025-09-07 09:00:00+09' + (u.n - 15) * interval '10 days'
  end as at
) as t
where c.slug = 'geumjeongsan-sanseong';

-- 승학산 구덕문화공원 · 이번 시즌 2명
insert into public.course_completions
  (user_id, course_id, ascent_s, completed_at, season, is_demo)
select
  pg_temp.demo_user(u.n),
  c.id,
  (c.official * 60 * (0.9 + (u.n - 21) * 0.1))::integer,
  t.at,
  public.season_of(t.at),
  true
from demo_course c
cross join generate_series(21, 22) as u(n)
cross join lateral (
  select timestamptz '2026-09-20 09:00:00+09' + (u.n - 21) * interval '13 days' as at
) as t
where c.slug = 'seunghaksan-gudeok';

------------------------------------------------------------
-- 4. 중도 하산(진행률) 기록
------------------------------------------------------------
-- 금정산 범어사: 41~45번이 45~85%까지 (완주는 없다)
insert into public.course_attempts
  (user_id, course_id, progress, attempted_at, is_demo)
select
  pg_temp.demo_user(u.n),
  c.id,
  0.45 + (u.n - 41) * 0.1,
  timestamptz '2026-08-10 09:00:00+09' + (u.n - 41) * interval '9 days',
  true
from demo_course c
cross join generate_series(41, 45) as u(n)
where c.slug = 'geumjeongsan-beomeosa';

-- 금정산 산성마을: 30~33번 (33번은 36%라 리뷰를 쓰지 못한다)
insert into public.course_attempts
  (user_id, course_id, progress, attempted_at, is_demo)
select
  pg_temp.demo_user(u.n),
  c.id,
  (array[0.42, 0.55, 0.68, 0.36])[u.n - 29],
  timestamptz '2026-08-24 09:00:00+09' + (u.n - 30) * interval '6 days',
  true
from demo_course c
cross join generate_series(30, 33) as u(n)
where c.slug = 'geumjeongsan-sanseong';

------------------------------------------------------------
-- 5. 리뷰 (조망은 완주한 사람만 매긴다)
------------------------------------------------------------
create temp table demo_comments on commit drop as
select * from unnest(array[
  '정상 조망이 정말 좋아요. 날씨 좋은 날 추천해요.',
  '초반 계단 구간이 생각보다 힘들어요.',
  '주말 오전에는 사람이 많아서 천천히 올라야 해요.',
  '길이 잘 정비돼 있어서 초보도 갈 만해요.',
  '비 온 다음 날은 바위가 미끄러워요. 조심하세요.',
  null,
  '해 질 무렵 내려오는 길 풍경이 예뻐요.',
  '물을 넉넉히 챙기세요. 중간에 살 곳이 없어요.',
  '중턱 쉼터까지만 다녀왔어요. 거기까지도 경사가 꽤 있어서 다음에는 아침 일찍 출발해서 정상까지 가 보려고요. 무릎이 약하신 분들은 스틱을 꼭 챙기시고, 내려올 때 특히 천천히 내려오세요.',
  null
]) with ordinality as t(comment, k);

-- 리뷰 한 줄 넣기: 사용자 번호(n)로 점수와 후기를 흩뿌린다.
insert into public.course_reviews
  (course_id, user_id, difficulty, risk, view, crowd, comment, is_demo, created_at, updated_at)
select
  c.id,
  pg_temp.demo_user(r.n),
  (1 + (r.n + c.official) % 5)::smallint,
  (1 + (r.n * 2 + c.official) % 4)::smallint,
  case when r.completed then (2 + (r.n + c.official) % 4)::smallint end,
  (1 + (r.n * 3) % 5)::smallint,
  case when r.completed
    then (select comment from demo_comments where k = 1 + r.n % 8)
    else (select comment from demo_comments where k = 9 + r.n % 2) end,
  true,
  now() - ((r.n * 3) % 40) * interval '1 day',
  now() - ((r.n * 3) % 40) * interval '1 day'
from demo_course c
join (
  -- 범어사: 완주자 1~30번 + 중도 하산 41~45번 = 35개
  select 'geumjeongsan-beomeosa' as slug, n, n <= 30 as completed
  from generate_series(1, 30) as n
  union all
  select 'geumjeongsan-beomeosa', n, false from generate_series(41, 45) as n
  -- 동아대: 1, 2번 (김세민 리뷰를 더하면 3개)
  union all
  select 'seunghaksan-donga', n, true from generate_series(1, 2) as n
  -- 산성마을: 지난 시즌 완주자 10~12번 + 중도 하산 30, 31번 = 5개
  union all
  select 'geumjeongsan-sanseong', n, true from generate_series(10, 12) as n
  union all
  select 'geumjeongsan-sanseong', n, false from generate_series(30, 31) as n
) as r on r.slug = c.slug;

-- 김세민의 동아대 리뷰 (고치기·지우기 확인용)
insert into public.course_reviews
  (course_id, user_id, difficulty, risk, view, crowd, comment, is_demo, created_at, updated_at)
select c.id, me.id, 2, 2, 5, 3,
  '짧지만 계단이 많아요. 정상 조망은 최고예요.',
  true, now() - interval '3 days', now() - interval '3 days'
from demo_me me
cross join demo_course c
where c.slug = 'seunghaksan-donga';

commit;

------------------------------------------------------------
-- 시연용 데이터만 지우기 (필요할 때 아래 줄들의 주석을 풀고 실행)
------------------------------------------------------------
-- delete from public.course_reviews where is_demo;
-- delete from public.course_attempts where is_demo;
-- delete from public.course_completions where is_demo;
-- delete from auth.users where raw_app_meta_data ->> 'demo' = 'true';
