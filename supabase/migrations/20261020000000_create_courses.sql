-- 2단계: 산(mountains)과 코스(courses). 코스 데이터는 supabase/seed/courses.sql로 넣는다.
-- 경로 계산(코스 매칭의 겹침 비율 등)에 PostGIS를 쓴다.

create extension if not exists postgis with schema extensions;

create table public.mountains (
  id uuid primary key default gen_random_uuid(),
  -- 사람이 읽는 고유 이름 (data/trails/courses.json의 id). 다시 넣을 때 이 값으로 덮어쓴다.
  slug text not null unique,
  name text not null,
  region text,
  height_m double precision,
  summit_name text not null,
  summit extensions.geometry(Point, 4326) not null,
  source text,
  created_at timestamptz not null default now()
);

create table public.courses (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  mountain_id uuid not null references public.mountains (id) on delete cascade,
  name text not null,
  start_name text not null,
  end_name text not null,
  -- 들머리 → 정상 방향 (CLAUDE.md 6-2장)
  path extensions.geometry(LineString, 4326) not null,
  distance_m double precision not null,
  official_time_min integer,
  official_difficulty text,
  source text,
  license text,
  updated_at timestamptz not null default now()
);

create index courses_path_gix on public.courses using gist (path);
create index courses_mountain_idx on public.courses (mountain_id);

-- 기록이 어느 코스를 완주했는지 (코스 매칭 단계에서 채움)
alter table public.activities
  add constraint activities_course_id_fkey
  foreign key (course_id) references public.courses (id) on delete set null;

-- RLS: 산·코스 정보는 로그인한 사용자 모두 읽기만 가능. 넣기·고치기는 SQL Editor(관리자)에서만.
alter table public.mountains enable row level security;
alter table public.courses enable row level security;

create policy "mountains: 로그인 사용자 읽기"
  on public.mountains for select
  to authenticated
  using (true);

create policy "courses: 로그인 사용자 읽기"
  on public.courses for select
  to authenticated
  using (true);

grant select on public.mountains, public.courses to authenticated;

-- 앱이 읽는 코스 목록. 경로를 GeoJSON으로 바꿔 돌려준다.
-- security_invoker: 뷰를 읽는 사용자의 권한(RLS)으로 실행한다.
create view public.course_catalog
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
  extensions.st_asgeojson(c.path)::jsonb as path
from public.courses c
join public.mountains m on m.id = c.mountain_id;

grant select on public.course_catalog to authenticated;
