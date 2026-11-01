-- 프로필 편집(공개)과 개인정보(본인만)
-- 먼저 20261027000000_photos.sql까지 실행해야 한다.
--
-- 공개 프로필: 프로필 사진, 닉네임#태그, 소개(300자), 주 활동 지역(자유 입력). 다른 사용자가 랭킹·리뷰에서 눌러 본다.
-- 개인정보: 이름, 휴대폰 번호, 주소. 본인만 읽고 쓴다. 공개 함수(랭킹·리뷰·프로필 보기)에는 연결하지 않는다.
--   동호회 가입·포토북 배송처럼 필요한 기능에서만 쓴다(그때 비어 있으면 앱이 입력을 받는다).

------------------------------------------------------------
-- 1. 공개 프로필
------------------------------------------------------------
alter table public.profiles
  add column bio text check (char_length(bio) <= 300),
  add column region text check (char_length(region) <= 30);

-- 닉네임·소개·주 활동 지역을 바꾼다. 닉네임: 2~10자, 한글·영문·숫자.
-- 바꾼 닉네임과 지금 태그의 조합이 비어 있으면 태그를 그대로 두고, 이미 쓰이면 새 태그를 준다.
-- 바뀐(또는 그대로인) 태그를 돌려준다.
create function public.update_my_profile(
  p_nickname text,
  p_bio text,
  p_region text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_nickname text := trim(p_nickname);
  v_old_nickname text;
  v_tag text;
begin
  if v_nickname !~ '^[가-힣A-Za-z0-9]{2,10}$' then
    raise exception '닉네임은 2~10자의 한글·영문·숫자로 정해 주세요' using errcode = '22023';
  end if;

  select nickname, nickname_tag into v_old_nickname, v_tag
  from public.profiles where id = v_user;
  if not found then
    raise exception '프로필이 없어요' using errcode = '42501';
  end if;

  if v_nickname <> v_old_nickname and exists (
    select 1 from public.profiles
    where nickname = v_nickname and nickname_tag = v_tag and id <> v_user
  ) then
    v_tag := public.free_nickname_tag(v_nickname);
  end if;

  update public.profiles
  set nickname = v_nickname,
    nickname_tag = v_tag,
    bio = nullif(trim(p_bio), ''),
    region = nullif(trim(p_region), '')
  where id = v_user;
  return v_tag;
end;
$$;

-- 다른 사용자의 공개 프로필 (랭킹·리뷰에서 닉네임#태그를 눌렀을 때). 개인정보는 돌려주지 않는다.
create function public.get_public_profile(p_nickname text, p_tag text)
returns table (
  nickname text,
  nickname_tag text,
  avatar_url text,
  bio text,
  region text,
  is_me boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select p.nickname, p.nickname_tag, p.avatar_url, p.bio, p.region,
    p.id = auth.uid()
  from public.profiles p
  where p.nickname = p_nickname and p.nickname_tag = p_tag;
$$;

revoke execute on function public.update_my_profile(text, text, text) from public, anon;
revoke execute on function public.get_public_profile(text, text) from public, anon;
grant execute on function public.update_my_profile(text, text, text) to authenticated;
grant execute on function public.get_public_profile(text, text) to authenticated;

------------------------------------------------------------
-- 2. 개인정보 (본인만)
------------------------------------------------------------
create table public.private_profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  name text check (char_length(name) between 1 and 20),
  -- 숫자만 저장한다. 예: 01012345678
  phone text check (phone ~ '^01[0-9]{8,9}$'),
  postcode text check (postcode ~ '^[0-9]{5}$'),
  address text check (char_length(address) <= 200),
  address_detail text check (char_length(address_detail) <= 100),
  updated_at timestamptz not null default now()
);

alter table public.private_profiles enable row level security;

create policy "private_profiles: 본인 행 읽기"
  on public.private_profiles for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "private_profiles: 본인 행 추가"
  on public.private_profiles for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "private_profiles: 본인 행 수정"
  on public.private_profiles for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "private_profiles: 본인 행 지우기"
  on public.private_profiles for delete
  to authenticated
  using ((select auth.uid()) = user_id);

grant select, insert, update, delete on public.private_profiles to authenticated;

create trigger private_profiles_set_updated_at
  before update on public.private_profiles
  for each row execute function public.set_updated_at();
