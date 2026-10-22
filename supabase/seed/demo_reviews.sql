-- 시연용 리뷰 (개발용 Supabase 프로젝트에서만 실행한다)
-- 먼저 migrations/20261022000000_create_reviews_and_subscriptions.sql 과
-- seed/demo_competition.sql(시연용 사용자·완주 기록)을 실행해야 한다.
-- 여러 번 실행해도 된다. (시연용 리뷰를 지우고 다시 넣는다)

begin;

delete from public.course_reviews where is_demo;

-- 그 코스를 완주한 시연용 사용자 중 일부가 리뷰를 남긴다.
insert into public.course_reviews
  (course_id, user_id, difficulty, risk, view, crowd, comment, is_demo, created_at, updated_at)
select
  c.id,
  u.id,
  -- 코스마다 경향이 다르게 보이도록 사용자 번호·코스 번호로 점수를 흩뿌린다.
  (1 + (u.n + c.n * 2) % 5)::smallint,
  (1 + (u.n * 2 + c.n) % 4)::smallint,
  (2 + (u.n + c.n) % 4)::smallint,
  (1 + (u.n * 3 + c.n) % 5)::smallint,
  (array[
    '정상 조망이 정말 좋아요. 날씨 좋은 날 추천해요.',
    '초반 계단 구간이 생각보다 힘들어요.',
    '주말 오전에는 사람이 많아서 천천히 올라야 해요.',
    '길이 잘 정비돼 있어서 초보도 갈 만해요.',
    '비 온 다음 날은 바위가 미끄러워요. 조심하세요.',
    null,
    '해 질 무렵 내려오는 길 풍경이 예뻐요.',
    '물을 넉넉히 챙기세요. 중간에 살 곳이 없어요.'
  ])[1 + (u.n + c.n) % 8],
  true,
  now() - ((u.n * 3 + c.n) % 40) * interval '1 day',
  now() - ((u.n * 3 + c.n) % 40) * interval '1 day'
from (
  select id, (row_number() over (order by email))::integer as n
  from auth.users
  where raw_app_meta_data ->> 'demo' = 'true'
) as u
cross join (
  select id, (row_number() over (order by slug))::integer as n
  from public.courses
  where slug not like 'auto-%'  -- 자동 생성 코스에는 시연용 리뷰를 넣지 않는다
) as c
where (u.n + c.n) % 3 <> 0
  and exists (
    select 1 from public.course_completions cc
    where cc.course_id = c.id and cc.user_id = u.id
  );

commit;

-- 지우기: delete from public.course_reviews where is_demo;
