-- 코스 경로의 점마다 고도(해발 m). 구독자 맞춤 예상 소요시간·난이도(경사 보정)에 쓴다.
-- 값은 tool/fetch_course_elevations.dart가 SRTM 30m에서 받아 seed/courses.sql로 넣는다.
-- 경로 좌표(path)와 같은 순서·개수다. 없으면 null (예상 소요시간을 보여 주지 않는다).

alter table public.courses
  add column elevations_m double precision[];

-- 앱이 읽는 코스 목록에 고도를 더한다. (기존 칸은 그대로, 맨 뒤에 추가)
create or replace view public.course_catalog
with (security_invoker = true) as
select
  c.id,
  c.slug,
  c.name,
  c.start_name,
  c.end_name,
  c.distance_m,
  c.official_time_min,
  c.official_difficulty,
  c.updated_at,
  m.name as mountain_name,
  m.region,
  m.height_m,
  m.summit_name,
  extensions.st_y(m.summit) as summit_lat,
  extensions.st_x(m.summit) as summit_lon,
  extensions.st_asgeojson(c.path)::jsonb as path,
  c.elevations_m
from public.courses c
join public.mountains m on m.id = c.mountain_id;
