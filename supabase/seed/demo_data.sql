-- 시연용 데이터: 기존 시연용 데이터를 모두 지우고 여러 상황을 확인할 수 있는 데이터를 다시 넣는다.
-- 개발용 Supabase 프로젝트에서만 실행한다. (CLAUDE.md 6-2장 "시연용 데이터")
-- 먼저 migrations/ 전부(20261104000000_mileage_badge_cap.sql까지)와 seed/courses.sql을 실행해야 한다.
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
-- │   업적: 김세민이 7월 27일부터 이번 시즌 최다완등 1위를 계속 지킨다(1위 지키기 90일),
-- │   지난 시즌(상반기)에는 두 분야 모두 1위로 끝났다(시즌 정복 배지 2개, 두 개의 왕관, 첫 정복 2개)
-- ├ 금정산 산성마을: 이번 시즌 완주 없음("첫 정복자가 되어 보세요"), 명예의 전당만 있음,
-- │   김세민은 앱 기록으로 62% 진행 → 조망을 뺀 리뷰 쓰기, 다른 사람 중도 하산 후기
-- └ 승학산 구덕문화공원: 완주 2명, 리뷰 없음, 김세민은 앱 기록으로 30% 진행 → 아직 리뷰 못 씀
--
-- 동호회 (6. 동호회)
-- ┌ 금정산 새벽산행: 회원 15명, 이번 시즌 클럽 랭킹 1위
-- ├ 승학산 노을회: 회원 10명
-- ├ 해운대 주말반: 회원 8명. 10번 회원이 7~8월에 있다가 금정산 새벽산행으로 옮겼다
-- │   (옮기기 전 완등은 해운대 주말반 실적에 남는다)
-- └ 동아대 등산 동아리: 김세민이 클럽장, 회원 5명, 가입 신청 2건 대기, 공지 2개, 일정 2개(다가오는 일정에 참석 투표)
--   (김세민이 앱에서 직접 만든 동호회에 이미 소속돼 있으면 이 클럽은 건너뛴다)
--
-- 채팅 (7. 채팅)
-- ┌ 동아대 등산 동아리 채팅방: 회원 대화 6개, 그중 최근 2개는 김세민이 아직 안 읽음
-- ├ 받은 메시지 요청: 주말산꾼이 질문을 보냄 (수락·거절해 보기)
-- ├ 이어 가는 1:1 대화: 김세민 ↔ 등산스틱
-- └ 김세민의 다른 1:1 방(리허설에서 팀원과 주고받은 방 등)은 모두 지운다
--
-- 프리미엄: 김세민의 구독을 지워 무료 상태로 시작한다 (시연 중 "결제하기"로 구독)
--
-- 쇼핑 (8. 쇼핑)
-- ┌ 상품 13개마다 시연용 사용자들의 주문(배송 완료)과 리뷰(별점·후기, 일부는 후기 없이 별점만)
-- └ 김세민: 데이하이크 22L 배낭(블루)을 5일 전 주문해 배송 완료, 리뷰는 아직 없음 → 시연에서 바로 리뷰 쓰기
--
-- 마일리지 (9. 마일리지)
-- └ 김세민: 지난 두 달 적립 430. 앱을 열면 지금까지 얻은 배지 마일리지가 한꺼번에 더해진다(하루 한도와 별도)

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
--    김세민 계정의 1:1 채팅방과 프리미엄 구독도 지운다(시연은 무료 상태에서 시작하고,
--    다른 기기에서 처음 보내는 메시지가 "메시지 요청"으로 오게).
------------------------------------------------------------
-- 1:1 채팅방 (팀원과 주고받은 방 포함. 메시지·읽음·신고가 함께 지워진다)
delete from public.chat_rooms
where kind = 'direct'
  and (requester_id in (select id from demo_me) or recipient_id in (select id from demo_me));
-- 프리미엄 구독 (시연 중 결제·마일리지 교환으로 생긴 것)
delete from public.subscriptions where user_id in (select id from demo_me);
delete from public.course_reviews
where is_demo or user_id in (select id from demo_me);
delete from public.course_attempts where is_demo;
delete from public.course_completions where is_demo;
-- 앱에서 만든 시연용 기록. 완주·진행률 기록은 activity_id로 함께 지워진다.
-- (Storage의 GPX·사진 파일은 SQL로 지울 수 없어 남는다. 필요하면 대시보드 Storage에서 지운다)
delete from public.activities
where user_id in (select id from demo_me) and title like '시연용%';
delete from auth.users where raw_app_meta_data ->> 'demo' = 'true';
-- 시연용 동호회 (소속·신청·공지·일정·투표가 함께 지워진다)
delete from public.clubs where is_demo;
-- 쇼핑: 시연용 주문·리뷰 + 김세민 계정의 주문·상품 리뷰 전부 (리허설에서 주문한 것도 지워 처음 상태로)
delete from public.product_reviews
where is_demo or user_id in (select id from demo_me);
delete from public.orders
where is_demo or user_id in (select id from demo_me);

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

-- 공개 프로필(소개·주 활동 지역): 랭킹·리뷰에서 눌러 볼 수 있게 넣는다. 일부는 비워 둔다("아직 소개가 없어요").
update public.profiles p
set
  region = (array['부산 금정구', '부산 사하구', '해운대·기장 일대', '주말엔 경남 일대', null])[1 + d.n % 5],
  bio = case when d.n % 3 = 0 then null else (array[
    '주말마다 금정산에 올라요. 같이 걸을 분 환영해요.',
    '천천히 오래 걷는 걸 좋아해요. 정상 라면이 제일 맛있어요.',
    '새벽 산행으로 일출 보는 게 취미예요.',
    '무릎을 아끼며 꾸준히 오르는 중이에요. 하산은 늘 조심!'
  ])[1 + d.n % 4] end
from (select pg_temp.demo_user(n) as id, n from generate_series(1, 45) as n) as d
where p.id = d.id;

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

-- 승학산 동아대 · 김세민 지난 시즌 2번. 다른 사람(6~8번, 1번씩)보다 많고 빠르다
-- → 상반기 최다완등·최단시간 1위로 시즌 종료 (업적의 시즌 정복 기록)
insert into public.course_completions
  (user_id, course_id, ascent_s, completed_at, season, is_demo)
select
  me.id,
  c.id,
  case when g = 1 then 760 else 1300 end,
  t.at,
  public.season_of(t.at),
  true
from demo_me me
cross join demo_course c
cross join generate_series(1, 2) as g
cross join lateral (
  select case when g = 1 then timestamptz '2026-04-19 08:00:00+09'
    else timestamptz '2026-05-24 08:00:00+09' end as at
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

------------------------------------------------------------
-- 6. 동호회
------------------------------------------------------------
create function pg_temp.demo_club(n integer)
returns uuid
language sql
immutable
as $$ select ('c0000000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;

insert into public.clubs (id, name, bio, region, leader_id, is_demo, created_at)
values
  (pg_temp.demo_club(1), '금정산 새벽산행',
    '매주 토요일 새벽 5시 범어사에서 출발해요. 정상에서 일출 보고 내려와 아침 먹어요.',
    '부산 금정구', pg_temp.demo_user(2), true, timestamptz '2026-03-02 09:00:00+09'),
  (pg_temp.demo_club(2), '승학산 노을회',
    '퇴근 후 승학산에서 노을 보는 모임이에요. 천천히 걸어요.',
    '부산 사하구', pg_temp.demo_user(16), true, timestamptz '2026-04-10 09:00:00+09'),
  (pg_temp.demo_club(3), '해운대 주말반',
    null, '해운대·기장 일대', pg_temp.demo_user(26), true, timestamptz '2026-05-20 09:00:00+09');

-- 회원 (가입은 6월 1일부터라 이번 시즌 완등이 모두 실적에 들어간다)
insert into public.club_memberships (club_id, user_id, joined_at, left_at, is_demo)
select pg_temp.demo_club(1), pg_temp.demo_user(n), timestamptz '2026-06-01 09:00:00+09', null::timestamptz, true
from generate_series(1, 15) as n where n <> 10
union all
select pg_temp.demo_club(2), pg_temp.demo_user(n), timestamptz '2026-06-01 09:00:00+09', null::timestamptz, true
from generate_series(16, 25) as n
union all
select pg_temp.demo_club(3), pg_temp.demo_user(n), timestamptz '2026-06-01 09:00:00+09', null::timestamptz, true
from generate_series(26, 33) as n
-- 10번 회원: 해운대 주말반에 있다가(7~8월) 금정산 새벽산행으로 옮겼다
union all
select pg_temp.demo_club(3), pg_temp.demo_user(10),
  timestamptz '2026-07-01 09:00:00+09', timestamptz '2026-09-01 09:00:00+09', true
union all
select pg_temp.demo_club(1), pg_temp.demo_user(10),
  timestamptz '2026-09-01 09:00:00+09', null::timestamptz, true;

-- 김세민이 클럽장인 동아리 (앱에서 만든 동호회에 이미 소속돼 있으면 건너뛴다)
insert into public.clubs (id, name, bio, region, leader_id, is_demo, created_at)
select pg_temp.demo_club(4), '동아대 등산 동아리',
  '동아대 학생·졸업생 등산 모임이에요. 한 달에 두 번 금정산·승학산을 올라요.',
  '부산 사하구 하단동', me.id, true, timestamptz '2026-06-15 09:00:00+09'
from demo_me me
where not exists (
  select 1 from public.club_memberships m where m.user_id = me.id and m.left_at is null
);

insert into public.club_memberships (club_id, user_id, joined_at, is_demo)
select c.id, me.id, timestamptz '2026-06-15 09:00:00+09', true
from public.clubs c cross join demo_me me
where c.id = pg_temp.demo_club(4)
union all
select c.id, pg_temp.demo_user(n), timestamptz '2026-07-01 09:00:00+09', true
from public.clubs c cross join generate_series(34, 38) as n
where c.id = pg_temp.demo_club(4);

-- 가입 신청 대기 2건 (클럽장 김세민이 승인·거절해 본다)
insert into public.club_join_requests (club_id, user_id, created_at, is_demo)
select c.id, pg_temp.demo_user(n), now() - (n - 38) * interval '1 day', true
from public.clubs c cross join generate_series(39, 40) as n
where c.id = pg_temp.demo_club(4);

insert into public.club_notices (club_id, author_id, body, created_at, is_demo)
select c.id, c.leader_id, x.body, x.at, true
from public.clubs c
cross join (values
  ('11월 정기 산행은 금정산 범어사 코스예요. 물과 간식 챙겨 오세요!', now() - interval '2 days'),
  ('동아리 회원은 앱에서 산행을 기록하면 완등이 클럽 실적으로 쌓여요. 이번 시즌 목표는 클럽 랭킹 3위!', now() - interval '20 days')
) as x(body, at)
where c.id = pg_temp.demo_club(4);

-- 일정: 다가오는 정기 산행(참석 투표 3명) + 지난 일정
insert into public.club_events (club_id, title, starts_at, place, memo, created_by, is_demo)
select c.id, x.title, x.at, x.place, x.memo, c.leader_id, true
from public.clubs c
cross join (values
  ('11월 정기 산행', date_trunc('day', now()) + interval '6 days 8 hours',
    '범어사 매표소 앞', '범어사 코스로 올라 고당봉에서 점심 먹어요'),
  ('10월 승학산 억새 산행', date_trunc('day', now()) - interval '14 days' + interval '9 hours',
    '동아대 승학캠퍼스 정문', null)
) as x(title, at, place, memo)
where c.id = pg_temp.demo_club(4);

insert into public.club_event_votes (event_id, user_id, answer, is_demo)
select e.id, pg_temp.demo_user(n), case when n = 37 then 'not_going' else 'going' end, true
from public.club_events e
cross join generate_series(34, 37) as n
where e.club_id = pg_temp.demo_club(4) and e.title = '11월 정기 산행';

------------------------------------------------------------
-- 7. 채팅
------------------------------------------------------------
-- 동아대 등산 동아리 채팅방 (회원들 대화. 마지막 2개는 김세민이 아직 안 읽음)
insert into public.chat_rooms (kind, club_id, is_demo)
select 'club', c.id, true
from public.clubs c
where c.id = pg_temp.demo_club(4);

insert into public.chat_messages (room_id, sender_id, body, created_at, is_demo)
select r.id, x.sender, x.body, now() - x.ago, true
from public.chat_rooms r
cross join demo_me me
cross join lateral (values
  (pg_temp.demo_user(34), '이번 주 정기 산행 날씨 괜찮을까요?', interval '2 days 3 hours'),
  (me.id, '토요일 맑대요! 범어사 매표소 앞 8시예요', interval '2 days 2 hours'),
  (pg_temp.demo_user(35), '저 처음 가는데 초보도 괜찮나요?', interval '1 day 5 hours'),
  (pg_temp.demo_user(36), '범어사 코스는 완만해서 괜찮아요. 물만 넉넉히!', interval '1 day 4 hours'),
  (pg_temp.demo_user(37), '이번엔 일이 있어서 불참이에요 ㅠㅠ 사진 많이 올려 주세요', interval '3 hours'),
  (pg_temp.demo_user(34), '고당봉에서 점심 먹고 내려와요~', interval '1 hour')
) as x(sender, body, ago)
where r.club_id = pg_temp.demo_club(4);

-- 김세민이 동아리 채팅을 마지막으로 읽은 시각 (그 뒤 2개가 새 메시지)
insert into public.chat_reads (room_id, user_id, last_read_at)
select r.id, me.id, now() - interval '1 day'
from public.chat_rooms r cross join demo_me me
where r.club_id = pg_temp.demo_club(4);

-- 받은 메시지 요청: 주말산꾼(3번)이 랭킹을 보고 질문을 보냈다 (수락·거절해 본다)
insert into public.chat_rooms (kind, requester_id, recipient_id, status, is_demo)
select 'direct', pg_temp.demo_user(3), me.id, 'pending', true
from demo_me me;

insert into public.chat_messages (room_id, sender_id, body, created_at, is_demo)
select r.id, r.requester_id,
  '안녕하세요! 승학산 동아대 코스 최다완등이시던데, 평일 저녁에도 오르시나요?',
  now() - interval '5 hours', true
from public.chat_rooms r cross join demo_me me
where r.kind = 'direct' and r.requester_id = pg_temp.demo_user(3) and r.recipient_id = me.id;

-- 이어 가는 1:1 대화: 김세민 ↔ 등산스틱(34번)
insert into public.chat_rooms (kind, requester_id, recipient_id, status, is_demo)
select 'direct', me.id, pg_temp.demo_user(34), 'accepted', true
from demo_me me;

insert into public.chat_messages (room_id, sender_id, body, created_at, is_demo)
select r.id, x.sender, x.body, now() - x.ago, true
from public.chat_rooms r
cross join demo_me me
cross join lateral (values
  (me.id, '지난번 산행 사진 고마워요!', interval '3 days 2 hours'),
  (pg_temp.demo_user(34), '별말씀을요 ㅎㅎ 다음엔 승학산 노을 보러 가요', interval '3 days 1 hour'),
  (me.id, '좋아요. 일정 만들어 둘게요', interval '3 days')
) as x(sender, body, ago)
where r.kind = 'direct' and r.requester_id = me.id and r.recipient_id = pg_temp.demo_user(34);

insert into public.chat_reads (room_id, user_id, last_read_at)
select r.id, me.id, now()
from public.chat_rooms r cross join demo_me me
where r.kind = 'direct' and r.requester_id = me.id and r.recipient_id = pg_temp.demo_user(34);

------------------------------------------------------------
-- 8. 쇼핑: 시연용 사용자의 주문(배송 완료)과 상품 리뷰, 김세민의 리뷰 쓰기 전 주문
------------------------------------------------------------
-- 상품마다 리뷰를 남길 사용자: 상품 순서(sort_order)로 흩뿌려 상품마다 4~8명쯤
create temp table demo_buyer on commit drop as
select p.id as product_id, p.category, p.price, p.options, p.sort_order as s, n,
  now() - (((n * 5 + p.sort_order) % 40) + 4) * interval '1 day' as ordered_at
from public.products p
cross join generate_series(1, 45) as n
where (n * 7 + p.sort_order) % 9 = 0;

insert into public.orders (
  user_id, product_id, option_value, quantity, unit_price, total_price,
  recipient_name, recipient_phone, postcode, address, address_detail,
  created_at, is_demo
)
select pg_temp.demo_user(b.n), b.product_id,
  case when b.options is null then null
    else b.options[1 + b.n % array_length(b.options, 1)] end,
  1, b.price, b.price,
  '시연용', '01000000000', '49315', '부산광역시 사하구 낙동대로550번길 37 (시연용 주소)', null,
  b.ordered_at, true
from demo_buyer b;

create temp table demo_product_comments (category text, k integer, comment text) on commit drop;
insert into demo_product_comments values
  ('shoes', 1, '정사이즈로 샀는데 딱 맞아요. 금정산 한 바퀴 돌아도 발이 편했어요.'),
  ('shoes', 2, '밑창이 잘 잡아 줘서 젖은 바위에서도 덜 미끄러웠어요.'),
  ('shoes', 3, '처음엔 조금 딱딱했는데 두세 번 신으니 길들었어요.'),
  ('backpack', 1, '당일 산행에 물 두 병, 도시락, 바람막이까지 넉넉히 들어가요.'),
  ('backpack', 2, '등판 통풍이 잘 돼서 여름에도 등이 덜 젖었어요.'),
  ('backpack', 3, '허리 벨트가 있으니 오래 걸어도 어깨가 덜 아파요.'),
  ('poles', 1, '내리막에서 무릎이 확실히 편해졌어요. 진작 살 걸 그랬어요.'),
  ('poles', 2, '접으면 배낭 옆에 쏙 들어가서 좋아요.'),
  ('poles', 3, '가볍고 튼튼해요. 길이 조절도 쉬워요.'),
  ('clothing', 1, '정상에서 바람 불 때 걸치기 딱 좋아요. 접으면 주먹만 해요.'),
  ('clothing', 2, '땀이 금방 말라서 오르막에서도 쾌적했어요.'),
  ('clothing', 3, '사이즈는 한 치수 크게 사는 걸 추천해요.'),
  ('safety', 1, '하산이 늦어졌을 때 덕분에 안전하게 내려왔어요.'),
  ('safety', 2, '작고 가벼워서 배낭에 늘 넣어 다녀요.'),
  ('safety', 3, '혹시 몰라 샀는데 마음이 든든해요.');

-- 별점은 대부분 4~5점, 가끔 3점·2점. 넷 중 하나는 후기 없이 별점만.
insert into public.product_reviews
  (product_id, user_id, rating, comment, created_at, updated_at, is_demo)
select b.product_id, pg_temp.demo_user(b.n),
  case
    when (b.n + b.s) % 10 = 0 then 2
    when (b.n + b.s) % 5 = 0 then 3
    when (b.n + b.s) % 2 = 0 then 4
    else 5
  end,
  case when b.n % 4 = 0 then null
    else (select c.comment from demo_product_comments c
          where c.category = b.category and c.k = 1 + b.n % 3) end,
  b.ordered_at + interval '2 days',
  b.ordered_at + interval '2 days',
  true
from demo_buyer b;

-- 김세민: 5일 전 주문해 배송이 끝난 배낭 (리뷰는 시연에서 직접 쓴다)
insert into public.orders (
  user_id, product_id, option_value, quantity, unit_price, total_price,
  recipient_name, recipient_phone, postcode, address, address_detail,
  created_at, is_demo
)
select me.id, p.id, '블루', 1, p.price, p.price,
  coalesce(pp.name, '김세민'), coalesce(pp.phone, '01000000000'), pp.postcode,
  coalesce(pp.address, '부산광역시 사하구 낙동대로550번길 37 (시연용 주소)'), pp.address_detail,
  now() - interval '5 days', true
from demo_me me
join public.products p on p.id = 'dayhike-22'
left join public.private_profiles pp on pp.user_id = me.id;

------------------------------------------------------------
-- 9. 마일리지: 김세민의 지난 두 달 적립 내역 430
--    (앱을 열면 지금까지 얻은 배지 마일리지가 한꺼번에 더해진다. 배지는 하루 한도와 별도)
--    이 SQL의 다른 insert는 모두 시연용(is_demo)이라 적립 트리거가 마일리지를 주지 않는다.
------------------------------------------------------------
delete from public.mileage_ledger
where is_demo or user_id in (select id from demo_me);

insert into public.mileage_ledger (user_id, amount, reason, label, source_key, created_at, is_demo)
select me.id, x.amount, x.reason, x.label, 'demo:' || x.k, now() - x.ago, true
from demo_me me
cross join lateral (
  -- 산행 기록 10번 (10씩)
  select k, 10 as amount, 'activity' as reason, '산행 기록 · 주말 산행' as label,
    (60 - k * 5) * interval '1 day' as ago
  from generate_series(1, 10) as k
  union all
  -- 코스 완주 8번 (30씩)
  select 10 + k, 30, 'completion',
    case when k % 2 = 0 then '코스 완주 · 승학산 동아대 코스' else '코스 완주 · 금정산 범어사 코스' end,
    (58 - k * 6) * interval '1 day'
  from generate_series(1, 8) as k
  union all
  select 20, 20, 'course_review', '코스 리뷰 · 금정산 범어사 코스', interval '40 days'
  union all
  select 21, 20, 'course_review', '코스 리뷰 · 승학산 구덕문화공원 코스', interval '25 days'
  union all
  select 22, 20, 'product_review', '상품 리뷰 · 카본 접이식 스틱 (2개)', interval '20 days'
  union all
  select 23, 10, 'product_review_photo', '상품 리뷰 사진 · 카본 접이식 스틱 (2개)', interval '20 days'
  union all
  select 24, 20, 'product_review', '상품 리뷰 · 헤드랜턴 400루멘', interval '9 days'
) as x;

commit;

------------------------------------------------------------
-- 시연용 데이터만 지우기 (필요할 때 아래 줄들의 주석을 풀고 실행)
------------------------------------------------------------
-- delete from public.course_reviews where is_demo;
-- delete from public.course_attempts where is_demo;
-- delete from public.course_completions where is_demo;
-- delete from auth.users where raw_app_meta_data ->> 'demo' = 'true';
-- delete from public.product_reviews where is_demo;
-- delete from public.orders where is_demo;
-- delete from public.mileage_ledger where is_demo;
