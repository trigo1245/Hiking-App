-- 2단계: 리뷰(평점)와 프리미엄 구독
-- 먼저 20261021000000_create_competition.sql을 실행해야 한다.

------------------------------------------------------------
-- 1. 리뷰 (CLAUDE.md 6-2장 "리뷰")
--    난이도·경사위험·조망·혼잡도 1~5점, 한 줄 후기 200자, 완주한 사람만 코스당 1개
------------------------------------------------------------
create table public.course_reviews (
  course_id uuid not null references public.courses (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  -- 1 쉬움 ~ 5 어려움
  difficulty smallint not null check (difficulty between 1 and 5),
  -- 1 안전 ~ 5 위험
  risk smallint not null check (risk between 1 and 5),
  -- 1 아쉬움 ~ 5 최고
  view smallint not null check (view between 1 and 5),
  -- 1 한산 ~ 5 붐빔
  crowd smallint not null check (crowd between 1 and 5),
  comment text check (char_length(comment) <= 200),
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (course_id, user_id)
);

-- 본인 리뷰만 직접 읽을 수 있다. 다른 사람 리뷰는 아래 함수로 공개 항목만 본다.
alter table public.course_reviews enable row level security;

create policy "course_reviews: 본인 행 읽기"
  on public.course_reviews for select
  to authenticated
  using ((select auth.uid()) = user_id);

grant select on public.course_reviews to authenticated;

-- 코스 리뷰 목록 (최근 수정 순, 50개)
create function public.get_course_reviews(p_course_id uuid)
returns table (
  nickname text,
  nickname_tag text,
  avatar_url text,
  difficulty smallint,
  risk smallint,
  view smallint,
  crowd smallint,
  comment text,
  updated_at timestamptz,
  is_mine boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select p.nickname, p.nickname_tag, p.avatar_url,
    r.difficulty, r.risk, r.view, r.crowd, r.comment, r.updated_at,
    r.user_id = auth.uid()
  from public.course_reviews r
  join public.profiles p on p.id = r.user_id
  where r.course_id = p_course_id
  order by r.updated_at desc
  limit 50;
$$;

-- 항목별 평균
create function public.get_review_summary(p_course_id uuid)
returns table (
  review_count integer,
  avg_difficulty double precision,
  avg_risk double precision,
  avg_view double precision,
  avg_crowd double precision
)
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer,
    avg(r.difficulty)::double precision,
    avg(r.risk)::double precision,
    avg(r.view)::double precision,
    avg(r.crowd)::double precision
  from public.course_reviews r
  where r.course_id = p_course_id;
$$;

-- 내 리뷰 쓰기·고치기. 그 코스를 완주한 기록이 있어야 한다.
create function public.upsert_my_review(
  p_course_id uuid,
  p_difficulty smallint,
  p_risk smallint,
  p_view smallint,
  p_crowd smallint,
  p_comment text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.course_completions cc
    where cc.course_id = p_course_id and cc.user_id = auth.uid()
  ) then
    raise exception '이 코스를 완주한 사람만 리뷰를 쓸 수 있어요'
      using errcode = '42501';
  end if;

  insert into public.course_reviews
    (course_id, user_id, difficulty, risk, view, crowd, comment)
  values (
    p_course_id, auth.uid(), p_difficulty, p_risk, p_view, p_crowd,
    nullif(trim(p_comment), '')
  )
  on conflict (course_id, user_id) do update set
    difficulty = excluded.difficulty,
    risk = excluded.risk,
    view = excluded.view,
    crowd = excluded.crowd,
    comment = excluded.comment,
    updated_at = now();
end;
$$;

create function public.delete_my_review(p_course_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.course_reviews
  where course_id = p_course_id and user_id = auth.uid();
$$;

------------------------------------------------------------
-- 2. 프리미엄 구독 (시연용 결제)
--    실제 결제(PG 연동)는 이후 단계. 지금은 결제 버튼을 누르면 바로 구독이 기록된다.
--    권한은 화면이 아니라 DB에서 검사한다. (CLAUDE.md 7장)
------------------------------------------------------------
create table public.subscriptions (
  user_id uuid primary key references auth.users (id) on delete cascade,
  plan text not null default 'premium',
  started_at timestamptz not null,
  expires_at timestamptz not null,
  canceled_at timestamptz,
  -- 실제 결제 없이 시연용으로 만든 구독
  is_demo boolean not null default true,
  updated_at timestamptz not null default now()
);

alter table public.subscriptions enable row level security;

create policy "subscriptions: 본인 행 읽기"
  on public.subscriptions for select
  to authenticated
  using ((select auth.uid()) = user_id);

grant select on public.subscriptions to authenticated;

-- 지금 구독 중인지. 다른 함수에서 권한을 검사할 때 쓴다.
create function public.is_subscriber()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.subscriptions s
    where s.user_id = auth.uid()
      and s.canceled_at is null
      and s.expires_at > now()
  );
$$;

-- 랭킹에서 볼 수 있는 줄 수: 구독자는 전체, 일반 사용자는 10명(+ 내 순위)
create or replace function public.ranking_visible_rows()
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select case when public.is_subscriber() then 1000000 else 10 end;
$$;

-- 내 구독 상태
create function public.get_my_subscription()
returns table (
  plan text,
  started_at timestamptz,
  expires_at timestamptz,
  is_active boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select s.plan, s.started_at, s.expires_at,
    s.canceled_at is null and s.expires_at > now()
  from public.subscriptions s
  where s.user_id = auth.uid();
$$;

-- 시연용 결제: 지금부터 한 달 구독
create function public.start_demo_subscription()
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.subscriptions
    (user_id, plan, started_at, expires_at, canceled_at, is_demo, updated_at)
  values (auth.uid(), 'premium', now(), now() + interval '1 month', null, true, now())
  on conflict (user_id) do update set
    plan = excluded.plan,
    started_at = excluded.started_at,
    expires_at = excluded.expires_at,
    canceled_at = null,
    is_demo = true,
    updated_at = now();
$$;

-- 해지: 시연 편의를 위해 남은 기간과 상관없이 바로 끝낸다.
create function public.cancel_subscription()
returns void
language sql
security definer
set search_path = ''
as $$
  update public.subscriptions
  set canceled_at = now(), expires_at = now(), updated_at = now()
  where user_id = auth.uid();
$$;

------------------------------------------------------------
-- 함수 실행 권한: 로그인한 사용자만
------------------------------------------------------------
revoke execute on function public.get_course_reviews(uuid) from public, anon;
revoke execute on function public.get_review_summary(uuid) from public, anon;
revoke execute on function public.upsert_my_review(uuid, smallint, smallint, smallint, smallint, text) from public, anon;
revoke execute on function public.delete_my_review(uuid) from public, anon;
revoke execute on function public.is_subscriber() from public, anon;
revoke execute on function public.get_my_subscription() from public, anon;
revoke execute on function public.start_demo_subscription() from public, anon;
revoke execute on function public.cancel_subscription() from public, anon;

grant execute on function public.get_course_reviews(uuid) to authenticated;
grant execute on function public.get_review_summary(uuid) to authenticated;
grant execute on function public.upsert_my_review(uuid, smallint, smallint, smallint, smallint, text) to authenticated;
grant execute on function public.delete_my_review(uuid) to authenticated;
grant execute on function public.is_subscriber() to authenticated;
grant execute on function public.get_my_subscription() to authenticated;
grant execute on function public.start_demo_subscription() to authenticated;
grant execute on function public.cancel_subscription() to authenticated;
