-- profiles: 사용자 공개 정보. auth.users 한 명당 한 행.
-- 가입(익명 포함) 시 트리거가 자동으로 행을 만든다.

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  nickname text not null,
  created_at timestamptz not null default now()
);

-- RLS: 1단계 정책은 "본인 행만 읽기·쓰기"
alter table public.profiles enable row level security;

create policy "profiles: 본인 행 읽기"
  on public.profiles for select
  to authenticated
  using ((select auth.uid()) = id);

create policy "profiles: 본인 행 수정"
  on public.profiles for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- Data API 노출. ("Automatically expose new tables"를 끈 상태라 직접 열어 준다)
-- 행 생성은 트리거만 하므로 insert 권한은 주지 않는다.
-- 익명 로그인 사용자도 authenticated 역할이다.
grant select, update (nickname) on public.profiles to authenticated;

-- 가입 시 프로필 자동 생성
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, nickname)
  values (
    new.id,
    coalesce(
      nullif(new.raw_user_meta_data ->> 'name', ''),
      nullif(new.raw_user_meta_data ->> 'full_name', ''),
      '등산객' || upper(substr(replace(new.id::text, '-', ''), 1, 4))
    )
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 이 마이그레이션 전에 가입한 사용자에게도 프로필을 만들어 준다.
insert into public.profiles (id, nickname)
select
  id,
  coalesce(
    nullif(raw_user_meta_data ->> 'name', ''),
    nullif(raw_user_meta_data ->> 'full_name', ''),
    '등산객' || upper(substr(replace(id::text, '-', ''), 1, 4))
  )
from auth.users
on conflict (id) do nothing;
