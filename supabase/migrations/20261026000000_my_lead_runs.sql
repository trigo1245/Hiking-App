-- 업적(정복자 배지)용: 내가 각 코스 랭킹 1위였던 기간
-- 먼저 20261025000000_ranking_pages_attempts.sql까지 실행해야 한다.
--
-- 다른 사용자의 완주 기록이 필요해서 기기에서 계산할 수 없다. 서버가 완주 기록을 시간 순서대로
-- 다시 짚어 가며 1위였던 구간을 구한다. 따로 저장하지 않고 부를 때마다 계산한다(기록을 지우면 결과도 바뀐다).
-- 1위 기준은 랭킹(course_ranked)과 같다. 동점이면 함께 1위다.

-- 시즌이 끝나는 시각 (한국 시간 7월 1일 0시 / 다음 해 1월 1일 0시)
create function public.season_end(p_season text)
returns timestamptz
language sql
immutable
set search_path = ''
as $$
  select make_timestamptz(
    left(p_season, 4)::integer + case when right(p_season, 1) = '2' then 1 else 0 end,
    case when right(p_season, 1) = '2' then 1 else 7 end,
    1, 0, 0, 0, 'Asia/Seoul'
  );
$$;

-- 내가 1위였던 구간. scope는 시즌(예: 2026-H2) 또는 'all'(명예의 전당).
-- ended_at: 1위를 내준 시각 또는 시즌이 끝난 시각. 지금도 1위면 null.
-- season_final: 끝난 시즌의 마지막 순간까지 1위였다(시즌 정복).
create function public.get_my_lead_runs()
returns table (
  course_id uuid,
  scope text,
  kind text,
  started_at timestamptz,
  ended_at timestamptz,
  season_final boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  with my_courses as (
    select distinct cc.course_id
    from public.course_completions cc
    where cc.user_id = (select auth.uid())
  ),
  scoped as (
    select cc.course_id, cc.season as scope, cc.user_id, cc.ascent_s, cc.completed_at
    from public.course_completions cc
    join my_courses m on m.course_id = cc.course_id
    union all
    select cc.course_id, 'all', cc.user_id, cc.ascent_s, cc.completed_at
    from public.course_completions cc
    join my_courses m on m.course_id = cc.course_id
  ),
  -- 순위가 바뀔 수 있는 순간 = 누군가 완주한 순간
  events as (
    select distinct s.course_id, s.scope, s.completed_at as at from scoped s
  ),
  standing as (
    select e.course_id, e.scope, e.at, s.user_id,
      count(*) as times, min(s.ascent_s) as best
    from events e
    join scoped s
      on s.course_id = e.course_id and s.scope = e.scope and s.completed_at <= e.at
    group by e.course_id, e.scope, e.at, s.user_id
  ),
  tops as (
    select st.*,
      max(st.times) over w as top_times,
      min(st.best) over w as top_best
    from standing st
    window w as (partition by st.course_id, st.scope, st.at)
  ),
  flags as (
    select t.course_id, t.scope, t.at, k.kind,
      bool_or(
        t.user_id = (select auth.uid())
        and case k.kind when 'most' then t.times = t.top_times else t.best = t.top_best end
      ) as leading
    from tops t
    cross join (values ('most'), ('fastest')) as k(kind)
    group by t.course_id, t.scope, t.at, k.kind
  ),
  timeline as (
    select f.*,
      lead(f.at) over w as next_at,
      coalesce(lag(f.leading) over w, false) as prev_leading
    from flags f
    window w as (partition by f.course_id, f.scope, f.kind order by f.at)
  ),
  numbered as (
    select t.*,
      sum(case when t.leading and not t.prev_leading then 1 else 0 end)
        over (partition by t.course_id, t.scope, t.kind order by t.at) as run_no
    from timeline t
  ),
  runs as (
    select n.course_id, n.scope, n.kind,
      min(n.at) as started_at,
      -- 구간 마지막 순간 다음 완주 = 1위를 내준 시각 (없으면 아직 1위)
      (array_agg(n.next_at order by n.at desc))[1] as lost_at,
      case when n.scope = 'all' then null else public.season_end(n.scope) end as scope_end
    from numbered n
    where n.leading
    group by n.course_id, n.scope, n.kind, n.run_no
  )
  select r.course_id, r.scope, r.kind, r.started_at,
    case
      when r.lost_at is not null then r.lost_at
      when r.scope_end is not null and r.scope_end <= now() then r.scope_end
      else null
    end,
    r.lost_at is null and r.scope_end is not null and r.scope_end <= now()
  from runs r;
$$;

revoke execute on function public.get_my_lead_runs() from public, anon;
grant execute on function public.get_my_lead_runs() to authenticated;
