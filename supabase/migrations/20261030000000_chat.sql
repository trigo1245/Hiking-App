-- 채팅: 동호회 채팅방(회원만, 가입 전 대화도 본다) + 1:1 채팅(메시지 요청 → 상대가 수락)
-- 먼저 20261029000000_clubs.sql까지 실행해야 한다.
--
-- 규칙 (CLAUDE.md 6-2장 "채팅")
-- - 동호회 채팅방은 동호회마다 하나. 지금 회원만 읽고 쓴다(탈퇴하면 바로 못 본다). 가입 전 대화도 볼 수 있다.
--   클럽장은 다른 회원의 메시지를 가릴 수 있다.
-- - 1:1 채팅은 두 사람 사이에 하나. 처음 보낸 사람(요청자)은 상대가 수락하기 전까지 첫 메시지 하나만 보낸다.
--   상대가 거절하거나, 대화 중 한쪽이 차단하면 둘 다 더 보낼 수 없다.
-- - 메시지는 글자만, 500자. 내 메시지는 지울 수 있고("삭제된 메시지예요"), 다른 사람 메시지는 신고할 수 있다.
-- - 앱은 Realtime으로 "새 메시지가 있다"는 신호만 받고, 내용은 아래 함수로 다시 받는다.
-- - 앱이 꺼져 있을 때 알림(푸시)은 없다.

------------------------------------------------------------
-- 1. 테이블
------------------------------------------------------------
create table public.chat_rooms (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('club', 'direct')),
  club_id uuid unique references public.clubs (id) on delete cascade,
  -- 1:1: 요청한 사람과 받은 사람
  requester_id uuid references auth.users (id) on delete cascade,
  recipient_id uuid references auth.users (id) on delete cascade,
  -- 1:1 상태: pending(요청) / accepted / declined(거절) / blocked(차단)
  status text not null default 'accepted'
    check (status in ('pending', 'accepted', 'declined', 'blocked')),
  blocked_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  is_demo boolean not null default false,
  check (
    (kind = 'club' and club_id is not null and requester_id is null)
    or (kind = 'direct' and club_id is null and requester_id is not null
        and recipient_id is not null and requester_id <> recipient_id)
  )
);

-- 두 사람 사이의 1:1 채팅방은 하나 (누가 먼저 보냈든)
create unique index chat_rooms_direct_pair on public.chat_rooms (
  least(requester_id, recipient_id), greatest(requester_id, recipient_id)
) where kind = 'direct';

-- 마지막으로 읽은 시각 (안 읽은 수·"여기까지 읽었어요"에 쓴다)
create table public.chat_reads (
  room_id uuid not null references public.chat_rooms (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  last_read_at timestamptz not null default now(),
  primary key (room_id, user_id)
);

create table public.chat_messages (
  id bigint generated always as identity primary key,
  room_id uuid not null references public.chat_rooms (id) on delete cascade,
  sender_id uuid not null references auth.users (id) on delete cascade,
  body text check (char_length(body) <= 500),
  created_at timestamptz not null default now(),
  -- 보낸 사람이 지웠다 (내용은 비운다)
  deleted_at timestamptz,
  -- 클럽장이 가렸다
  hidden boolean not null default false,
  is_demo boolean not null default false
);

create index chat_messages_room_idx on public.chat_messages (room_id, id desc);

-- 신고는 쌓아 두기만 한다 (처리 화면은 없다)
create table public.chat_reports (
  id bigint generated always as identity primary key,
  message_id bigint not null references public.chat_messages (id) on delete cascade,
  reporter_id uuid not null references auth.users (id) on delete cascade,
  reason text check (char_length(reason) <= 200),
  created_at timestamptz not null default now(),
  unique (message_id, reporter_id)
);

------------------------------------------------------------
-- 2. 읽기 권한 (Realtime도 이 규칙으로 걸러서 보낸다)
------------------------------------------------------------
create function public.can_read_chat_room(p_room uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.chat_rooms r
    where r.id = p_room
      and (
        (r.kind = 'club' and r.club_id = public.club_of(auth.uid()))
        or (r.kind = 'direct' and auth.uid() in (r.requester_id, r.recipient_id))
      )
  );
$$;

alter table public.chat_rooms enable row level security;
alter table public.chat_reads enable row level security;
alter table public.chat_messages enable row level security;
alter table public.chat_reports enable row level security;

-- Realtime 신호를 받으려면 읽기 정책이 있어야 한다. 쓰기는 모두 아래 함수로만 한다.
create policy "chat_rooms: 참여자 읽기"
  on public.chat_rooms for select
  to authenticated
  using ((select public.can_read_chat_room(id)));

create policy "chat_messages: 참여자 읽기"
  on public.chat_messages for select
  to authenticated
  using ((select public.can_read_chat_room(room_id)));

grant select on public.chat_rooms, public.chat_messages to authenticated;

-- Realtime으로 새 메시지·상태 변화를 알린다
alter publication supabase_realtime add table public.chat_messages, public.chat_rooms;

------------------------------------------------------------
-- 3. 방 찾기·만들기
------------------------------------------------------------
-- 내 동호회 채팅방 (처음 열 때 만든다)
create function public.get_club_chat_room(p_club_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room uuid;
begin
  perform public.require_club_member(p_club_id);
  select id into v_room from public.chat_rooms where club_id = p_club_id;
  if v_room is null then
    insert into public.chat_rooms (kind, club_id) values ('club', p_club_id)
    on conflict (club_id) do nothing
    returning id into v_room;
    if v_room is null then
      select id into v_room from public.chat_rooms where club_id = p_club_id;
    end if;
  end if;
  return v_room;
end;
$$;

-- 그 사람과의 1:1 채팅방 (없으면 null)
create function public.find_direct_room(p_nickname text, p_tag text)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select r.id
  from public.profiles p
  join public.chat_rooms r
    on r.kind = 'direct'
   and least(r.requester_id, r.recipient_id) = least(p.id, auth.uid())
   and greatest(r.requester_id, r.recipient_id) = greatest(p.id, auth.uid())
  where p.nickname = p_nickname and p.nickname_tag = p_tag;
$$;

-- 메시지 요청: 1:1 채팅방을 만들고 첫 메시지를 보낸다. 이미 있으면 그 방 id를 돌려준다(메시지는 보내지 않는다).
create function public.start_direct_chat(p_nickname text, p_tag text, p_body text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_other uuid;
  v_room uuid;
begin
  select id into v_other from public.profiles
  where nickname = p_nickname and nickname_tag = p_tag;
  if v_other is null then
    raise exception '사용자를 찾지 못했어요' using errcode = '22023';
  end if;
  if v_other = v_me then
    raise exception '나에게는 메시지를 보낼 수 없어요' using errcode = '22023';
  end if;

  v_room := public.find_direct_room(p_nickname, p_tag);
  if v_room is not null then
    return v_room;
  end if;

  insert into public.chat_rooms (kind, requester_id, recipient_id, status)
  values ('direct', v_me, v_other, 'pending')
  returning id into v_room;
  insert into public.chat_messages (room_id, sender_id, body)
  values (v_room, v_me, trim(p_body));
  insert into public.chat_reads (room_id, user_id) values (v_room, v_me);
  return v_room;
end;
$$;

------------------------------------------------------------
-- 4. 목록·방 정보·메시지
------------------------------------------------------------
-- 안 읽은 수: 마지막으로 읽은 뒤(동호회는 처음이면 가입한 뒤) 다른 사람이 보낸 메시지
create function public.chat_unread(p_room uuid, p_user uuid)
returns integer
language sql
stable
set search_path = ''
as $$
  select count(*)::integer
  from public.chat_messages m
  where m.room_id = p_room
    and m.sender_id <> p_user
    and m.deleted_at is null
    and m.created_at > coalesce(
      (select last_read_at from public.chat_reads where room_id = p_room and user_id = p_user),
      (select mm.joined_at from public.chat_rooms r
        join public.club_memberships mm on mm.club_id = r.club_id
        where r.id = p_room and mm.user_id = p_user and mm.left_at is null),
      '-infinity'::timestamptz
    );
$$;

revoke execute on function public.chat_unread(uuid, uuid) from public, anon, authenticated;

-- 내 1:1 대화 목록 (최근 메시지 순). 받은 요청도 함께, i_am_requester로 구분한다.
create function public.get_my_direct_chats()
returns table (
  room_id uuid,
  status text,
  i_am_requester boolean,
  other_nickname text,
  other_tag text,
  other_avatar_url text,
  last_body text,
  last_at timestamptz,
  unread integer
)
language sql
stable
security definer
set search_path = ''
as $$
  select r.id, r.status, r.requester_id = auth.uid(),
    p.nickname, p.nickname_tag, p.avatar_url,
    case when lm.deleted_at is not null then '삭제된 메시지예요' else lm.body end,
    lm.created_at,
    public.chat_unread(r.id, auth.uid())
  from public.chat_rooms r
  join public.profiles p
    on p.id = case when r.requester_id = auth.uid() then r.recipient_id else r.requester_id end
  left join lateral (
    select m.body, m.created_at, m.deleted_at from public.chat_messages m
    where m.room_id = r.id order by m.id desc limit 1
  ) lm on true
  where r.kind = 'direct' and auth.uid() in (r.requester_id, r.recipient_id)
  order by lm.created_at desc nulls last;
$$;

-- 배지용: 1:1 안 읽은 수, 받은 요청 수, 내 동호회 채팅 안 읽은 수
create function public.get_chat_badges()
returns table (direct_unread integer, pending_requests integer, club_unread integer)
language sql
stable
security definer
set search_path = ''
as $$
  select
    coalesce((
      select sum(public.chat_unread(r.id, auth.uid()))::integer from public.chat_rooms r
      where r.kind = 'direct' and auth.uid() in (r.requester_id, r.recipient_id)
        and r.status = 'accepted'
    ), 0),
    (select count(*)::integer from public.chat_rooms r
      where r.kind = 'direct' and r.recipient_id = auth.uid() and r.status = 'pending'),
    coalesce((
      select public.chat_unread(r.id, auth.uid()) from public.chat_rooms r
      where r.kind = 'club' and r.club_id = public.club_of(auth.uid())
    ), 0);
$$;

-- 방 정보: 제목(동호회 이름 / 상대 닉네임#태그), 상태, 내가 보낼 수 있는지, 내가 마지막으로 읽은 시각
create function public.get_chat_room(p_room_id uuid)
returns table (
  kind text,
  club_id uuid,
  title text,
  other_nickname text,
  other_tag text,
  other_avatar_url text,
  status text,
  i_am_requester boolean,
  i_am_leader boolean,
  can_send boolean,
  my_last_read_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.can_read_chat_room(p_room_id) then
    raise exception '이 대화에 참여하고 있지 않아요' using errcode = '42501';
  end if;
  return query
  select r.kind, r.club_id,
    coalesce(c.name, p.nickname),
    p.nickname, p.nickname_tag, p.avatar_url,
    r.status,
    r.requester_id = auth.uid(),
    c.leader_id = auth.uid(),
    case
      when r.kind = 'club' then true
      when r.status = 'accepted' then true
      -- 요청 중에는 받은 사람이 수락해야 대화가 시작된다
      else false
    end,
    (select cr.last_read_at from public.chat_reads cr
      where cr.room_id = r.id and cr.user_id = auth.uid())
  from public.chat_rooms r
  left join public.clubs c on c.id = r.club_id
  left join public.profiles p
    on r.kind = 'direct'
   and p.id = case when r.requester_id = auth.uid() then r.recipient_id else r.requester_id end
  where r.id = p_room_id;
end;
$$;

-- 메시지 (최근 것부터 p_limit개, p_before_id보다 앞의 것). 지운·가린 메시지는 내용 없이 표시만.
create function public.get_chat_messages(
  p_room_id uuid,
  p_before_id bigint default null,
  p_limit integer default 50
)
returns table (
  id bigint,
  sender_nickname text,
  sender_tag text,
  sender_avatar_url text,
  is_mine boolean,
  body text,
  state text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.can_read_chat_room(p_room_id) then
    raise exception '이 대화에 참여하고 있지 않아요' using errcode = '42501';
  end if;
  return query
  select m.id, p.nickname, p.nickname_tag, p.avatar_url,
    m.sender_id = auth.uid(),
    case when m.deleted_at is null and not m.hidden then m.body end,
    case when m.deleted_at is not null then 'deleted'
         when m.hidden then 'hidden' else 'normal' end,
    m.created_at
  from public.chat_messages m
  join public.profiles p on p.id = m.sender_id
  where m.room_id = p_room_id
    and (p_before_id is null or m.id < p_before_id)
  order by m.id desc
  limit least(greatest(p_limit, 1), 100);
end;
$$;

------------------------------------------------------------
-- 5. 보내기·읽음·요청 응답·차단·지우기·가리기·신고
------------------------------------------------------------
create function public.send_chat_message(p_room_id uuid, p_body text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.chat_rooms;
begin
  if not public.can_read_chat_room(p_room_id) then
    raise exception '이 대화에 참여하고 있지 않아요' using errcode = '42501';
  end if;
  select * into v_room from public.chat_rooms where id = p_room_id;
  if v_room.kind = 'direct' and v_room.status = 'pending' then
    raise exception '상대가 수락하면 대화를 이어 갈 수 있어요' using errcode = '42501';
  end if;
  if v_room.kind = 'direct' and v_room.status in ('declined', 'blocked') then
    raise exception '이 대화에는 더 보낼 수 없어요' using errcode = '42501';
  end if;
  if char_length(trim(p_body)) = 0 then
    raise exception '메시지를 입력해 주세요' using errcode = '22023';
  end if;
  insert into public.chat_messages (room_id, sender_id, body)
  values (p_room_id, auth.uid(), trim(p_body));
  perform public.mark_chat_read(p_room_id);
end;
$$;

create function public.mark_chat_read(p_room_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.can_read_chat_room(p_room_id) then
    return;
  end if;
  insert into public.chat_reads (room_id, user_id, last_read_at)
  values (p_room_id, auth.uid(), now())
  on conflict (room_id, user_id) do update set last_read_at = now();
end;
$$;

-- 받은 요청에 답한다 (받은 사람만)
create function public.respond_chat_request(p_room_id uuid, p_accept boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.chat_rooms
  set status = case when p_accept then 'accepted' else 'declined' end
  where id = p_room_id and kind = 'direct' and status = 'pending'
    and recipient_id = auth.uid();
  if not found then
    raise exception '이미 답한 요청이에요' using errcode = '22023';
  end if;
end;
$$;

-- 1:1 대화 차단 (둘 다 더 보낼 수 없다)
create function public.block_direct_chat(p_room_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.chat_rooms
  set status = 'blocked', blocked_by = auth.uid()
  where id = p_room_id and kind = 'direct'
    and auth.uid() in (requester_id, recipient_id);
  if not found then
    raise exception '차단하지 못했어요' using errcode = '22023';
  end if;
end;
$$;

-- 내 메시지 지우기 (내용을 비우고 "삭제된 메시지예요"로 남긴다)
create function public.delete_chat_message(p_message_id bigint)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.chat_messages
  set deleted_at = now(), body = null
  where id = p_message_id and sender_id = auth.uid() and deleted_at is null;
  if not found then
    raise exception '내 메시지만 지울 수 있어요' using errcode = '42501';
  end if;
end;
$$;

-- 클럽장이 동호회 채팅의 메시지를 가린다
create function public.hide_chat_message(p_message_id bigint)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_club uuid;
begin
  select r.club_id into v_club
  from public.chat_messages m join public.chat_rooms r on r.id = m.room_id
  where m.id = p_message_id and r.kind = 'club';
  if v_club is null then
    raise exception '동호회 채팅의 메시지만 가릴 수 있어요' using errcode = '22023';
  end if;
  perform public.require_club_leader(v_club);
  update public.chat_messages set hidden = true where id = p_message_id;
end;
$$;

create function public.report_chat_message(p_message_id bigint, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room uuid;
begin
  select room_id into v_room from public.chat_messages where id = p_message_id;
  if v_room is null or not public.can_read_chat_room(v_room) then
    raise exception '신고할 수 없는 메시지예요' using errcode = '42501';
  end if;
  insert into public.chat_reports (message_id, reporter_id, reason)
  values (p_message_id, auth.uid(), nullif(trim(p_reason), ''))
  on conflict (message_id, reporter_id) do nothing;
end;
$$;

------------------------------------------------------------
-- 6. 함수 실행 권한: 로그인한 사용자만
------------------------------------------------------------
do $$
declare
  f text;
begin
  foreach f in array array[
    'public.can_read_chat_room(uuid)',
    'public.get_club_chat_room(uuid)',
    'public.find_direct_room(text, text)',
    'public.start_direct_chat(text, text, text)',
    'public.get_my_direct_chats()',
    'public.get_chat_badges()',
    'public.get_chat_room(uuid)',
    'public.get_chat_messages(uuid, bigint, integer)',
    'public.send_chat_message(uuid, text)',
    'public.mark_chat_read(uuid)',
    'public.respond_chat_request(uuid, boolean)',
    'public.block_direct_chat(uuid)',
    'public.delete_chat_message(bigint)',
    'public.hide_chat_message(bigint)',
    'public.report_chat_message(bigint, text)'
  ] loop
    execute format('revoke execute on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end;
$$;
