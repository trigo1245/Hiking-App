-- 동호회: 클럽 랭킹 명예의 전당, 클럽장의 회원 내보내기
-- 20261029000000_clubs.sql 다음에 실행한다.

------------------------------------------------------------
-- 1. 클럽 랭킹: p_season이 null이면 명예의 전당 (모든 시즌 합계)
--    실적은 시즌과 같이 "소속 기간 안에 회원이 완주한 횟수"다.
------------------------------------------------------------
create or replace function public.get_club_ranking(p_season text)
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
     and (p_season is null or cc.season = p_season)
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
-- 2. 회원 내보내기 (클럽장만). 탈퇴와 같게 소속을 끝낸다.
--    - 소속 기간 안의 완등은 그 동호회 실적에 남는다.
--    - 동호회 채팅·공지·일정은 바로 못 본다 (지금 회원만 보므로).
--    - 아직 지나지 않은 일정의 참석 답은 지운다.
--    - 다시 가입 신청할 수 있다 (클럽장이 거절하면 된다).
------------------------------------------------------------
create function public.kick_club_member(p_club_id uuid, p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_club_leader(p_club_id);
  if p_user_id = auth.uid() then
    raise exception '클럽장은 자기 자신을 내보낼 수 없어요' using errcode = '22023';
  end if;
  if public.club_of(p_user_id) is distinct from p_club_id then
    raise exception '이 동호회 회원이 아니에요' using errcode = '22023';
  end if;
  update public.club_memberships
  set left_at = now()
  where club_id = p_club_id and user_id = p_user_id and left_at is null;
  delete from public.club_event_votes v
  using public.club_events e
  where v.event_id = e.id and e.club_id = p_club_id and v.user_id = p_user_id
    and e.starts_at > now();
end;
$$;

revoke execute on function public.kick_club_member(uuid, uuid) from public, anon;
grant execute on function public.kick_club_member(uuid, uuid) to authenticated;
