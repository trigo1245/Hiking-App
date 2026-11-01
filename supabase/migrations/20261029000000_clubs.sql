-- 동호회: 만들기(시연용 개설비 한 번 결제)·찾기·가입 신청과 승인·탈퇴, 공지, 일정과 참석 투표, 클럽 랭킹
-- 먼저 20261028000000_profile_details.sql까지 실행해야 한다.
--
-- 규칙 (CLAUDE.md 6-2장 "동호회")
-- - 한 사람은 한 번에 한 클럽에만 소속된다. 가입은 신청 → 클럽장 승인. 클럽당 50명까지.
-- - 역할은 클럽장 1명 + 회원. 클럽장은 다른 회원에게 넘기거나 클럽을 없애야 나갈 수 있다.
-- - 클럽 실적 = 소속 기간(joined_at ~ left_at) 안에 회원이 완주한 횟수의 합 (시즌별). 옮긴 회원의 과거 실적은 그때 클럽에 남는다.
-- - 클럽 목록·소개·실적·랭킹은 누구나 본다. 회원 목록·공지·일정은 그 클럽 회원만 본다.
-- - 모든 읽기·쓰기는 아래 함수로만 한다(테이블은 직접 열지 않는다). 회원의 개인정보는 어디에도 돌려주지 않는다.

------------------------------------------------------------
-- 1. 테이블
------------------------------------------------------------
create table public.clubs (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 2 and 20),
  bio text check (char_length(bio) <= 300),
  region text check (char_length(region) <= 30),
  photo_path text,
  photo_url text,
  leader_id uuid not null references auth.users (id) on delete cascade,
  max_members integer not null default 50,
  -- 시연용 개설비 결제 시각 (실제 결제 없음)
  opening_paid_at timestamptz not null default now(),
  is_demo boolean not null default false,
  created_at timestamptz not null default now()
);

-- 이름은 겹칠 수 없다 (앞뒤 공백·영문 대소문자 무시)
create unique index clubs_name_unique on public.clubs (lower(trim(name)));

-- 소속 기간. left_at이 null이면 지금 소속이다.
create table public.club_memberships (
  id bigint generated always as identity primary key,
  club_id uuid not null references public.clubs (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  is_demo boolean not null default false
);

-- 한 사람은 한 번에 한 클럽에만
create unique index club_memberships_one_active
  on public.club_memberships (user_id) where left_at is null;
create index club_memberships_club_idx on public.club_memberships (club_id);

create table public.club_join_requests (
  id bigint generated always as identity primary key,
  club_id uuid not null references public.clubs (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected', 'canceled')),
  created_at timestamptz not null default now(),
  decided_at timestamptz,
  is_demo boolean not null default false
);

-- 기다리는 신청은 한 사람당 하나
create unique index club_join_requests_one_pending
  on public.club_join_requests (user_id) where status = 'pending';

create table public.club_notices (
  id bigint generated always as identity primary key,
  club_id uuid not null references public.clubs (id) on delete cascade,
  author_id uuid not null references auth.users (id) on delete cascade,
  body text not null check (char_length(trim(body)) between 1 and 500),
  created_at timestamptz not null default now(),
  is_demo boolean not null default false
);

create table public.club_events (
  id bigint generated always as identity primary key,
  club_id uuid not null references public.clubs (id) on delete cascade,
  title text not null check (char_length(trim(title)) between 1 and 40),
  starts_at timestamptz not null,
  place text check (char_length(place) <= 60),
  memo text check (char_length(memo) <= 300),
  created_by uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  is_demo boolean not null default false
);

-- 참석 투표: going(참석) / not_going(불참)
create table public.club_event_votes (
  event_id bigint not null references public.club_events (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  answer text not null check (answer in ('going', 'not_going')),
  updated_at timestamptz not null default now(),
  is_demo boolean not null default false,
  primary key (event_id, user_id)
);

-- 테이블은 직접 열지 않는다. (함수만 security definer로 읽고 쓴다)
alter table public.clubs enable row level security;
alter table public.club_memberships enable row level security;
alter table public.club_join_requests enable row level security;
alter table public.club_notices enable row level security;
alter table public.club_events enable row level security;
alter table public.club_event_votes enable row level security;

------------------------------------------------------------
-- 2. 도움 함수 (직접 부르지 않는다)
------------------------------------------------------------
-- 지금 소속된 클럽
create function public.club_of(p_user uuid)
returns uuid
language sql
stable
set search_path = ''
as $$
  select m.club_id from public.club_memberships m
  where m.user_id = p_user and m.left_at is null;
$$;

create function public.club_member_count(p_club uuid)
returns integer
language sql
stable
set search_path = ''
as $$
  select count(*)::integer from public.club_memberships m
  where m.club_id = p_club and m.left_at is null;
$$;

-- 시즌 클럽 실적: 소속 기간 안에 회원이 완주한 횟수의 합
create function public.club_completions(p_club uuid, p_season text)
returns integer
language sql
stable
set search_path = ''
as $$
  select count(*)::integer
  from public.club_memberships m
  join public.course_completions cc
    on cc.user_id = m.user_id
   and cc.completed_at >= m.joined_at
   and (m.left_at is null or cc.completed_at < m.left_at)
  where m.club_id = p_club and cc.season = p_season;
$$;

create function public.require_club_leader(p_club uuid)
returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.clubs c where c.id = p_club and c.leader_id = auth.uid()
  ) then
    raise exception '클럽장만 할 수 있어요' using errcode = '42501';
  end if;
end;
$$;

create function public.require_club_member(p_club uuid)
returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if public.club_of(auth.uid()) is distinct from p_club then
    raise exception '이 동호회 회원만 볼 수 있어요' using errcode = '42501';
  end if;
end;
$$;

revoke execute on function public.club_of(uuid) from public, anon, authenticated;
revoke execute on function public.club_member_count(uuid) from public, anon, authenticated;
revoke execute on function public.club_completions(uuid, text) from public, anon, authenticated;
revoke execute on function public.require_club_leader(uuid) from public, anon, authenticated;
revoke execute on function public.require_club_member(uuid) from public, anon, authenticated;

------------------------------------------------------------
-- 3. 클럽 만들기·고치기·없애기
------------------------------------------------------------
-- 시연용 개설비(한 번)를 결제한 것으로 기록하고 클럽을 만든다. 만든 사람이 클럽장이 된다.
create function public.create_club(p_name text, p_bio text, p_region text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_club uuid;
begin
  if public.club_of(v_user) is not null then
    raise exception '이미 소속된 동호회가 있어요' using errcode = '23505';
  end if;
  if exists (select 1 from public.clubs where lower(trim(name)) = lower(trim(p_name))) then
    raise exception '이미 있는 동호회 이름이에요' using errcode = '23505';
  end if;

  insert into public.clubs (name, bio, region, leader_id)
  values (trim(p_name), nullif(trim(p_bio), ''), nullif(trim(p_region), ''), v_user)
  returning id into v_club;

  insert into public.club_memberships (club_id, user_id) values (v_club, v_user);
  update public.club_join_requests
  set status = 'canceled', decided_at = now()
  where user_id = v_user and status = 'pending';
  return v_club;
end;
$$;

create function public.update_club(p_club_id uuid, p_name text, p_bio text, p_region text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_club_leader(p_club_id);
  if exists (
    select 1 from public.clubs
    where lower(trim(name)) = lower(trim(p_name)) and id <> p_club_id
  ) then
    raise exception '이미 있는 동호회 이름이에요' using errcode = '23505';
  end if;
  update public.clubs
  set name = trim(p_name),
    bio = nullif(trim(p_bio), ''),
    region = nullif(trim(p_region), '')
  where id = p_club_id;
end;
$$;

-- 대표 사진 (club-photos 버킷의 공개 주소). 이전 사진 경로를 돌려준다.
create function public.set_club_photo(p_club_id uuid, p_path text, p_url text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old text;
begin
  perform public.require_club_leader(p_club_id);
  if p_path not like auth.uid()::text || '/%'
    or p_url not like '%/storage/v1/object/public/club-photos/' || p_path then
    raise exception '동호회 사진 경로가 아니에요' using errcode = '42501';
  end if;
  select photo_path into v_old from public.clubs where id = p_club_id;
  update public.clubs set photo_path = p_path, photo_url = p_url where id = p_club_id;
  return v_old;
end;
$$;

-- 클럽을 없앤다. 소속·신청·공지·일정이 함께 지워진다. 지워야 할 사진 경로를 돌려준다.
create function public.disband_club(p_club_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_photo text;
begin
  perform public.require_club_leader(p_club_id);
  select photo_path into v_photo from public.clubs where id = p_club_id;
  delete from public.clubs where id = p_club_id;
  return v_photo;
end;
$$;

create function public.transfer_club_leader(p_club_id uuid, p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_club_leader(p_club_id);
  if public.club_of(p_user_id) is distinct from p_club_id then
    raise exception '이 동호회 회원에게만 넘길 수 있어요' using errcode = '22023';
  end if;
  update public.clubs set leader_id = p_user_id where id = p_club_id;
end;
$$;

------------------------------------------------------------
-- 4. 찾기·상세 (누구나)
------------------------------------------------------------
-- 클럽 목록. p_query로 이름·지역을 찾는다. 이번 시즌 실적이 많은 순.
create function public.list_clubs(
  p_query text default null,
  p_season text default null,
  p_offset integer default 0,
  p_limit integer default 30
)
returns table (
  id uuid,
  name text,
  bio text,
  region text,
  photo_url text,
  member_count integer,
  max_members integer,
  season_completions integer
)
language sql
stable
security definer
set search_path = ''
as $$
  select c.id, c.name, c.bio, c.region, c.photo_url,
    public.club_member_count(c.id), c.max_members,
    public.club_completions(c.id, coalesce(p_season, public.season_of(now())))
  from public.clubs c
  where coalesce(trim(p_query), '') = ''
     or position(lower(trim(p_query)) in lower(c.name || ' ' || coalesce(c.region, ''))) > 0
  order by 8 desc, c.created_at
  offset greatest(p_offset, 0)
  limit least(greatest(p_limit, 1), 100);
$$;

-- 클럽 상세와 나와의 관계. my_status: leader / member / pending / other_club / none
create function public.get_club(p_club_id uuid)
returns table (
  id uuid,
  name text,
  bio text,
  region text,
  photo_url text,
  member_count integer,
  max_members integer,
  season_completions integer,
  leader_nickname text,
  leader_tag text,
  my_status text,
  pending_requests integer
)
language sql
stable
security definer
set search_path = ''
as $$
  select c.id, c.name, c.bio, c.region, c.photo_url,
    public.club_member_count(c.id), c.max_members,
    public.club_completions(c.id, public.season_of(now())),
    p.nickname, p.nickname_tag,
    case
      when c.leader_id = auth.uid() then 'leader'
      when public.club_of(auth.uid()) = c.id then 'member'
      when exists (
        select 1 from public.club_join_requests r
        where r.club_id = c.id and r.user_id = auth.uid() and r.status = 'pending'
      ) then 'pending'
      when public.club_of(auth.uid()) is not null then 'other_club'
      else 'none'
    end,
    -- 가입 신청 수는 클럽장에게만
    case when c.leader_id = auth.uid() then (
      select count(*)::integer from public.club_join_requests r
      where r.club_id = c.id and r.status = 'pending'
    ) end
  from public.clubs c
  join public.profiles p on p.id = c.leader_id
  where c.id = p_club_id;
$$;

-- 내가 소속된 클럽 id와 기다리는 가입 신청 (동호회 탭 첫 화면)
create function public.get_my_club_status()
returns table (club_id uuid, pending_club_id uuid, pending_club_name text)
language sql
stable
security definer
set search_path = ''
as $$
  select public.club_of(auth.uid()),
    r.club_id,
    c.name
  from (select 1) as one
  left join public.club_join_requests r
    on r.user_id = auth.uid() and r.status = 'pending'
  left join public.clubs c on c.id = r.club_id;
$$;

------------------------------------------------------------
-- 5. 가입 신청·승인·탈퇴
------------------------------------------------------------
create function public.request_club_join(p_club_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
begin
  if public.club_of(v_user) is not null then
    raise exception '이미 소속된 동호회가 있어요' using errcode = '23505';
  end if;
  if exists (
    select 1 from public.club_join_requests
    where user_id = v_user and status = 'pending'
  ) then
    raise exception '이미 기다리는 가입 신청이 있어요' using errcode = '23505';
  end if;
  if public.club_member_count(p_club_id) >= (
    select max_members from public.clubs where id = p_club_id
  ) then
    raise exception '인원이 가득 찼어요' using errcode = '23514';
  end if;
  insert into public.club_join_requests (club_id, user_id) values (p_club_id, v_user);
end;
$$;

create function public.cancel_club_join_request()
returns void
language sql
security definer
set search_path = ''
as $$
  update public.club_join_requests
  set status = 'canceled', decided_at = now()
  where user_id = auth.uid() and status = 'pending';
$$;

-- 클럽장이 보는 가입 신청 목록 (공개 프로필 항목만)
create function public.get_club_join_requests(p_club_id uuid)
returns table (
  request_id bigint,
  nickname text,
  nickname_tag text,
  avatar_url text,
  region text,
  requested_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.require_club_leader(p_club_id);
  return query
  select r.id, p.nickname, p.nickname_tag, p.avatar_url, p.region, r.created_at
  from public.club_join_requests r
  join public.profiles p on p.id = r.user_id
  where r.club_id = p_club_id and r.status = 'pending'
  order by r.created_at;
end;
$$;

create function public.decide_club_join_request(p_request_id bigint, p_approve boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_req public.club_join_requests;
begin
  select * into v_req from public.club_join_requests
  where id = p_request_id and status = 'pending';
  if not found then
    raise exception '이미 처리된 신청이에요' using errcode = '22023';
  end if;
  perform public.require_club_leader(v_req.club_id);

  if p_approve then
    if public.club_member_count(v_req.club_id) >= (
      select max_members from public.clubs where id = v_req.club_id
    ) then
      raise exception '인원이 가득 찼어요' using errcode = '23514';
    end if;
    if public.club_of(v_req.user_id) is not null then
      raise exception '이미 다른 동호회에 소속된 사람이에요' using errcode = '23505';
    end if;
    insert into public.club_memberships (club_id, user_id)
    values (v_req.club_id, v_req.user_id);
  end if;

  update public.club_join_requests
  set status = case when p_approve then 'approved' else 'rejected' end,
    decided_at = now()
  where id = p_request_id;
end;
$$;

-- 회원이 나간다. 클럽장은 먼저 클럽장을 넘기거나 클럽을 없애야 한다.
create function public.leave_club()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_club uuid := public.club_of(auth.uid());
begin
  if v_club is null then
    return;
  end if;
  if exists (select 1 from public.clubs where id = v_club and leader_id = auth.uid()) then
    raise exception '클럽장은 클럽장을 넘기거나 동호회를 없애야 나갈 수 있어요'
      using errcode = '22023';
  end if;
  update public.club_memberships
  set left_at = now()
  where user_id = auth.uid() and left_at is null;
  delete from public.club_event_votes v
  using public.club_events e
  where v.event_id = e.id and e.club_id = v_club and v.user_id = auth.uid()
    and e.starts_at > now();
end;
$$;

------------------------------------------------------------
-- 6. 회원끼리만 보는 것: 회원 목록, 공지, 일정·참석 투표
------------------------------------------------------------
create function public.get_club_members(p_club_id uuid)
returns table (
  user_id uuid,
  nickname text,
  nickname_tag text,
  avatar_url text,
  is_leader boolean,
  is_me boolean,
  season_completions integer,
  joined_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.require_club_member(p_club_id);
  return query
  select m.user_id, p.nickname, p.nickname_tag, p.avatar_url,
    m.user_id = c.leader_id,
    m.user_id = auth.uid(),
    (select count(*)::integer from public.course_completions cc
      where cc.user_id = m.user_id
        and cc.season = public.season_of(now())
        and cc.completed_at >= m.joined_at),
    m.joined_at
  from public.club_memberships m
  join public.clubs c on c.id = m.club_id
  join public.profiles p on p.id = m.user_id
  where m.club_id = p_club_id and m.left_at is null
  order by m.user_id = c.leader_id desc, 7 desc, m.joined_at;
end;
$$;

create function public.get_club_notices(p_club_id uuid)
returns table (
  id bigint,
  body text,
  author_nickname text,
  author_tag text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.require_club_member(p_club_id);
  return query
  select n.id, n.body, p.nickname, p.nickname_tag, n.created_at
  from public.club_notices n
  join public.profiles p on p.id = n.author_id
  where n.club_id = p_club_id
  order by n.created_at desc
  limit 50;
end;
$$;

create function public.post_club_notice(p_club_id uuid, p_body text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_club_leader(p_club_id);
  insert into public.club_notices (club_id, author_id, body)
  values (p_club_id, auth.uid(), trim(p_body));
end;
$$;

create function public.delete_club_notice(p_notice_id bigint)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_club uuid;
begin
  select club_id into v_club from public.club_notices where id = p_notice_id;
  perform public.require_club_leader(v_club);
  delete from public.club_notices where id = p_notice_id;
end;
$$;

-- 일정: 다가오는 것부터, 지난 일정은 최근 10개. 참석·불참 수와 내 답.
create function public.get_club_events(p_club_id uuid)
returns table (
  id bigint,
  title text,
  starts_at timestamptz,
  place text,
  memo text,
  going integer,
  not_going integer,
  my_answer text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.require_club_member(p_club_id);
  return query
  with picked as (
    (select e.* from public.club_events e
      where e.club_id = p_club_id and e.starts_at >= now() - interval '1 day'
      order by e.starts_at)
    union all
    (select e.* from public.club_events e
      where e.club_id = p_club_id and e.starts_at < now() - interval '1 day'
      order by e.starts_at desc limit 10)
  )
  select e.id, e.title, e.starts_at, e.place, e.memo,
    (select count(*)::integer from public.club_event_votes v
      where v.event_id = e.id and v.answer = 'going'),
    (select count(*)::integer from public.club_event_votes v
      where v.event_id = e.id and v.answer = 'not_going'),
    (select v.answer from public.club_event_votes v
      where v.event_id = e.id and v.user_id = auth.uid())
  from picked e
  order by e.starts_at >= now() - interval '1 day' desc,
    case when e.starts_at >= now() - interval '1 day' then e.starts_at end asc,
    e.starts_at desc;
end;
$$;

create function public.create_club_event(
  p_club_id uuid,
  p_title text,
  p_starts_at timestamptz,
  p_place text,
  p_memo text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_club_leader(p_club_id);
  insert into public.club_events (club_id, title, starts_at, place, memo, created_by)
  values (p_club_id, trim(p_title), p_starts_at, nullif(trim(p_place), ''),
    nullif(trim(p_memo), ''), auth.uid());
end;
$$;

create function public.delete_club_event(p_event_id bigint)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_club uuid;
begin
  select club_id into v_club from public.club_events where id = p_event_id;
  perform public.require_club_leader(v_club);
  delete from public.club_events where id = p_event_id;
end;
$$;

-- 참석 투표. p_answer가 null이면 내 답을 지운다.
create function public.vote_club_event(p_event_id bigint, p_answer text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_club uuid;
begin
  select club_id into v_club from public.club_events where id = p_event_id;
  perform public.require_club_member(v_club);
  if p_answer is null then
    delete from public.club_event_votes where event_id = p_event_id and user_id = auth.uid();
  else
    insert into public.club_event_votes (event_id, user_id, answer)
    values (p_event_id, auth.uid(), p_answer)
    on conflict (event_id, user_id)
    do update set answer = excluded.answer, updated_at = now();
  end if;
end;
$$;

-- 일정의 참석·불참 명단 (회원끼리)
create function public.get_club_event_votes(p_event_id bigint)
returns table (nickname text, nickname_tag text, avatar_url text, answer text)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_club uuid;
begin
  select club_id into v_club from public.club_events where id = p_event_id;
  perform public.require_club_member(v_club);
  return query
  select p.nickname, p.nickname_tag, p.avatar_url, v.answer
  from public.club_event_votes v
  join public.profiles p on p.id = v.user_id
  where v.event_id = p_event_id
  order by v.answer, v.updated_at;
end;
$$;

------------------------------------------------------------
-- 7. 클럽 랭킹 (누구나 전체): 시즌 클럽 완등 횟수
------------------------------------------------------------
create function public.get_club_ranking(p_season text)
returns table (
  rank_no integer,
  club_id uuid,
  name text,
  photo_url text,
  region text,
  member_count integer,
  completions integer,
  active_members integer,
  is_mine boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  with per_club as (
    select c.id,
      count(cc.id)::integer as completions,
      count(distinct cc.user_id)::integer as active_members
    from public.clubs c
    left join public.club_memberships m on m.club_id = c.id
    left join public.course_completions cc
      on cc.user_id = m.user_id
     and cc.season = p_season
     and cc.completed_at >= m.joined_at
     and (m.left_at is null or cc.completed_at < m.left_at)
    group by c.id
  )
  select (rank() over (order by pc.completions desc))::integer,
    c.id, c.name, c.photo_url, c.region,
    public.club_member_count(c.id),
    pc.completions, pc.active_members,
    c.id = public.club_of(auth.uid())
  from per_club pc
  join public.clubs c on c.id = pc.id
  order by pc.completions desc, c.created_at;
$$;

------------------------------------------------------------
-- 8. 소속 클럽 표시: 지도 정복자, 공개 프로필 (반환 형태가 바뀌어 다시 만든다)
------------------------------------------------------------
drop function public.get_conquerors(text);

create function public.get_conquerors(p_season text)
returns table (
  course_id uuid,
  kind text,
  nickname text,
  nickname_tag text,
  avatar_url text,
  score integer,
  club_name text,
  club_photo_url text
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
  ),
  picked as (
    select m.course_id, 'most'::text as kind, m.user_id, m.score from most m
    union all
    select f.course_id, 'fastest'::text, f.user_id, f.score from fastest f
  )
  -- 클럽 표시는 점수와 무관한 지금 소속 기준 (기획 5.3장)
  select x.course_id, x.kind, p.nickname, p.nickname_tag, p.avatar_url, x.score,
    c.name, c.photo_url
  from picked x
  join public.profiles p on p.id = x.user_id
  left join public.clubs c on c.id = public.club_of(x.user_id);
$$;

drop function public.get_public_profile(text, text);

create function public.get_public_profile(p_nickname text, p_tag text)
returns table (
  nickname text,
  nickname_tag text,
  avatar_url text,
  bio text,
  region text,
  is_me boolean,
  club_id uuid,
  club_name text
)
language sql
stable
security definer
set search_path = ''
as $$
  select p.nickname, p.nickname_tag, p.avatar_url, p.bio, p.region,
    p.id = auth.uid(), c.id, c.name
  from public.profiles p
  left join public.clubs c on c.id = public.club_of(p.id)
  where p.nickname = p_nickname and p.nickname_tag = p_tag;
$$;

------------------------------------------------------------
-- 9. 대표 사진 버킷 (공개). 경로: {user_id}/{club_id}/{사진 id}.jpg
------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('club-photos', 'club-photos', true, 5242880, array['image/jpeg'])
on conflict (id) do nothing;

create policy "club-photos: 본인 폴더 올리기"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'club-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "club-photos: 본인 폴더 지우기"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'club-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

------------------------------------------------------------
-- 10. 함수 실행 권한: 로그인한 사용자만
------------------------------------------------------------
do $$
declare
  f text;
begin
  foreach f in array array[
    'public.create_club(text, text, text)',
    'public.update_club(uuid, text, text, text)',
    'public.set_club_photo(uuid, text, text)',
    'public.disband_club(uuid)',
    'public.transfer_club_leader(uuid, uuid)',
    'public.list_clubs(text, text, integer, integer)',
    'public.get_club(uuid)',
    'public.get_my_club_status()',
    'public.request_club_join(uuid)',
    'public.cancel_club_join_request()',
    'public.get_club_join_requests(uuid)',
    'public.decide_club_join_request(bigint, boolean)',
    'public.leave_club()',
    'public.get_club_members(uuid)',
    'public.get_club_notices(uuid)',
    'public.post_club_notice(uuid, text)',
    'public.delete_club_notice(bigint)',
    'public.get_club_events(uuid)',
    'public.create_club_event(uuid, text, timestamptz, text, text)',
    'public.delete_club_event(bigint)',
    'public.vote_club_event(bigint, text)',
    'public.get_club_event_votes(bigint)',
    'public.get_club_ranking(text)',
    'public.get_conquerors(text)',
    'public.get_public_profile(text, text)'
  ] loop
    execute format('revoke execute on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end;
$$;
