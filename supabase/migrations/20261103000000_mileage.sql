-- 마일리지: 참여(산행·완주·리뷰·배지)에 따라 쌓고, 프리미엄 교환권(7일·30일)으로만 쓴다.
-- 20261102000000_shop_ads.sql 다음에 실행한다.
--
-- - 적립은 서버가 한다: 기록·완주·리뷰가 생기면 트리거가 넣는다. 배지는 기기가 계산하므로 앱이
--   claim_badge_mileage로 알리면 서버가 중복을 걸러 넣는다.
-- - 같은 일로는 처음 1번만 적립한다(source_key 유일). 지웠다 다시 써도 다시 주지 않고, 이미 준 것은 회수하지 않는다.
-- - 프리미엄 구독 중이면 1.5배. 하루(한국 시간) 적립 한도 200(프리미엄 300). 한도를 넘으면 적립하지 않는다.
-- - 속도 이상(is_flagged) 기록과 시연용(is_demo) 행은 적립하지 않는다.
-- - 유효기간은 없다. 상품 구매·포토북에는 쓰지 않는다.

------------------------------------------------------------
-- 1. 장부 (적립 +, 사용 -). 잔액은 합계로 계산한다.
------------------------------------------------------------
create table public.mileage_ledger (
  id bigserial primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  amount integer not null,
  -- activity / completion / course_review / product_review / product_review_photo / badge / redeem / demo
  reason text not null,
  label text not null,
  -- 같은 일로 두 번 적립하지 않기 위한 키 (사용은 null)
  source_key text,
  created_at timestamptz not null default now(),
  is_demo boolean not null default false,
  unique (user_id, source_key)
);

create index mileage_ledger_user_idx on public.mileage_ledger (user_id, created_at desc);

alter table public.mileage_ledger enable row level security;

create policy "mileage_ledger: 본인 행 읽기"
  on public.mileage_ledger for select
  to authenticated
  using ((select auth.uid()) = user_id);

grant select on public.mileage_ledger to authenticated;

-- 적립되면 앱이 바로 "+N 마일리지"를 보여 줄 수 있게 신호를 보낸다 (본인 행만 RLS로 간다).
alter publication supabase_realtime add table public.mileage_ledger;

------------------------------------------------------------
-- 2. 적립 규칙 (앱에서 직접 부르지 않는다)
------------------------------------------------------------
create function public.mileage_subscriber(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.subscriptions s
    where s.user_id = p_user and s.canceled_at is null and s.expires_at > now()
  );
$$;

-- 오늘(한국 시간) 받은 적립 합계
create function public.mileage_earned_today(p_user uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(sum(amount), 0)::integer
  from public.mileage_ledger
  where user_id = p_user and amount > 0
    and (created_at at time zone 'Asia/Seoul')::date = (now() at time zone 'Asia/Seoul')::date;
$$;

-- 적립 한 건. 이미 같은 키로 받았거나 하루 한도를 넘으면 0.
-- p_partial이 true면 한도까지 남은 만큼만 준다(기록·리뷰). false면 다 줄 수 없을 때 건너뛴다(배지: 다음 날 다시 받는다).
create function public.mileage_award(
  p_user uuid,
  p_key text,
  p_reason text,
  p_label text,
  p_base integer,
  p_partial boolean default true
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_premium boolean := public.mileage_subscriber(p_user);
  v_amount integer := case when v_premium then ceil(p_base * 1.5)::integer else p_base end;
  v_cap integer := case when v_premium then 300 else 200 end;
  v_left integer;
begin
  if p_user is null or exists (
    select 1 from public.mileage_ledger where user_id = p_user and source_key = p_key
  ) then
    return 0;
  end if;
  v_left := v_cap - public.mileage_earned_today(p_user);
  if v_left <= 0 or (not p_partial and v_left < v_amount) then
    return 0;
  end if;
  v_amount := least(v_amount, v_left);
  insert into public.mileage_ledger (user_id, amount, reason, label, source_key)
  values (p_user, v_amount, p_reason, p_label, p_key)
  on conflict (user_id, source_key) do nothing;
  return v_amount;
end;
$$;

revoke execute on function public.mileage_subscriber(uuid) from public, anon, authenticated;
revoke execute on function public.mileage_earned_today(uuid) from public, anon, authenticated;
revoke execute on function public.mileage_award(uuid, text, text, text, integer, boolean)
  from public, anon, authenticated;

------------------------------------------------------------
-- 3. 자동 적립 (트리거)
------------------------------------------------------------
-- 산행 기록: 1km 이상, 하루 2번까지 10
create function public.mileage_on_activity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.is_flagged or new.is_demo or coalesce(new.distance_m, 0) < 1000 then
    return new;
  end if;
  if (select count(*) from public.mileage_ledger
      where user_id = new.user_id and reason = 'activity'
        and (created_at at time zone 'Asia/Seoul')::date
          = (now() at time zone 'Asia/Seoul')::date) >= 2 then
    return new;
  end if;
  perform public.mileage_award(
    new.user_id, 'activity:' || new.id, 'activity',
    '산행 기록 · ' || coalesce(nullif(new.title, ''), '산행'), 10);
  return new;
end;
$$;

create trigger mileage_on_activity
  after insert on public.activities
  for each row execute function public.mileage_on_activity();

-- 코스 완주: 같은 코스는 하루 1번 30
create function public.mileage_on_completion()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text;
begin
  if new.activity_id is null or new.is_demo then
    return new;
  end if;
  select m.name || ' ' || c.name into v_name
  from public.courses c left join public.mountains m on m.id = c.mountain_id
  where c.id = new.course_id;
  perform public.mileage_award(
    new.user_id,
    'completion:' || new.course_id || ':'
      || ((new.completed_at at time zone 'Asia/Seoul')::date)::text,
    'completion', '코스 완주 · ' || coalesce(v_name, '코스'), 30);
  return new;
end;
$$;

create trigger mileage_on_completion
  after insert on public.course_completions
  for each row execute function public.mileage_on_completion();

-- 코스 리뷰: 코스마다 처음 1번 20
create function public.mileage_on_course_review()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text;
begin
  if new.is_demo then
    return new;
  end if;
  select m.name || ' ' || c.name into v_name
  from public.courses c left join public.mountains m on m.id = c.mountain_id
  where c.id = new.course_id;
  perform public.mileage_award(
    new.user_id, 'course_review:' || new.course_id, 'course_review',
    '코스 리뷰 · ' || coalesce(v_name, '코스'), 20);
  return new;
end;
$$;

create trigger mileage_on_course_review
  after insert on public.course_reviews
  for each row execute function public.mileage_on_course_review();

-- 상품 리뷰: 상품마다 처음 1번 20, 사진을 처음 붙이면 10 더
create function public.mileage_on_product_review()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.is_demo then
    return new;
  end if;
  perform public.mileage_award(
    new.user_id, 'product_review:' || new.product_id, 'product_review',
    '상품 리뷰 · ' || coalesce((select name from public.products where id = new.product_id), '상품'),
    20);
  return new;
end;
$$;

create trigger mileage_on_product_review
  after insert on public.product_reviews
  for each row execute function public.mileage_on_product_review();

create function public.mileage_on_product_review_photo()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.mileage_award(
    new.user_id, 'product_review_photo:' || new.product_id, 'product_review_photo',
    '상품 리뷰 사진 · ' || coalesce((select name from public.products where id = new.product_id), '상품'),
    10);
  return new;
end;
$$;

create trigger mileage_on_product_review_photo
  after insert on public.product_review_photos
  for each row execute function public.mileage_on_product_review_photo();

------------------------------------------------------------
-- 4. 앱에서 부르는 함수
------------------------------------------------------------
-- 배지 적립: 앱이 얻은 배지를 알린다 [{"id": "first_step", "level": 1, "tier": "gold", "name": "첫 걸음"}, ...]
-- 단계 색으로 금액을 정한다(동 30, 은 50, 금 100). 배지·단계마다 처음 1번만.
-- 하루 한도에 걸리면 건너뛰고 다음 날 다시 알릴 때 받는다. 받은 합계를 돌려준다.
create function public.claim_badge_mileage(p_claims jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_claim jsonb;
  v_id text;
  v_level integer;
  v_base integer;
  v_total integer := 0;
begin
  if auth.uid() is null then
    return 0;
  end if;
  for v_claim in select * from jsonb_array_elements(coalesce(p_claims, '[]'::jsonb)) loop
    v_id := v_claim ->> 'id';
    v_level := (v_claim ->> 'level')::integer;
    v_base := case v_claim ->> 'tier'
      when 'bronze' then 30 when 'silver' then 50 when 'gold' then 100 end;
    if v_id !~ '^[a-z_]{1,40}$' or v_level not between 1 and 3 or v_base is null then
      continue;
    end if;
    v_total := v_total + public.mileage_award(
      auth.uid(), 'badge:' || v_id || ':' || v_level, 'badge',
      '배지 · ' || left(coalesce(v_claim ->> 'name', v_id), 20), v_base, false);
  end loop;
  return v_total;
end;
$$;

-- 내 마일리지: 잔액, 오늘 받은 양, 오늘 한도, 프리미엄 여부(1.5배)
create function public.get_my_mileage()
returns table (balance integer, earned_today integer, daily_cap integer, premium boolean)
language sql
stable
security definer
set search_path = ''
as $$
  select
    coalesce((select sum(amount) from public.mileage_ledger where user_id = auth.uid()), 0)::integer,
    public.mileage_earned_today(auth.uid()),
    case when public.mileage_subscriber(auth.uid()) then 300 else 200 end,
    public.mileage_subscriber(auth.uid());
$$;

-- 적립·사용 내역 (최근 것부터 나눠 받는다)
create function public.get_my_mileage_history(
  p_offset integer default 0,
  p_limit integer default 30
)
returns table (id bigint, amount integer, reason text, label text, created_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select l.id, l.amount, l.reason, l.label, l.created_at
  from public.mileage_ledger l
  where l.user_id = auth.uid()
  order by l.created_at desc, l.id desc
  offset greatest(p_offset, 0)
  limit least(greatest(p_limit, 1), 50);
$$;

-- 프리미엄 교환권: '7d'(500) 또는 '30d'(1800). 구독 중이면 끝나는 날을 늘리고, 아니면 지금부터 시작한다.
-- 새로 끝나는 시각을 돌려준다.
create function public.redeem_mileage(p_item text)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cost integer;
  v_days interval;
  v_label text;
  v_balance integer;
  v_expires timestamptz;
begin
  if auth.uid() is null then
    raise exception '로그인이 필요해요' using errcode = '42501';
  end if;
  case p_item
    when '7d' then v_cost := 500; v_days := interval '7 days'; v_label := '프리미엄 7일 교환권';
    when '30d' then v_cost := 1800; v_days := interval '30 days'; v_label := '프리미엄 30일 교환권';
    else raise exception '없는 교환권이에요' using errcode = '22023';
  end case;

  -- 같은 사람이 동시에 두 번 교환하지 못하게 잠근다.
  perform pg_advisory_xact_lock(hashtext('mileage:' || auth.uid()::text));
  select coalesce(sum(amount), 0) into v_balance
  from public.mileage_ledger where user_id = auth.uid();
  if v_balance < v_cost then
    raise exception '마일리지가 % 모자라요', v_cost - v_balance using errcode = '22023';
  end if;

  insert into public.mileage_ledger (user_id, amount, reason, label)
  values (auth.uid(), -v_cost, 'redeem', v_label);

  insert into public.subscriptions
    (user_id, plan, started_at, expires_at, canceled_at, is_demo, updated_at)
  values (auth.uid(), 'premium', now(), now() + v_days, null, true, now())
  on conflict (user_id) do update set
    plan = 'premium',
    started_at = case
      when subscriptions.canceled_at is null and subscriptions.expires_at > now()
        then subscriptions.started_at else now() end,
    expires_at = case
      when subscriptions.canceled_at is null and subscriptions.expires_at > now()
        then subscriptions.expires_at + v_days else now() + v_days end,
    canceled_at = null,
    updated_at = now()
  returning expires_at into v_expires;
  return v_expires;
end;
$$;

do $$
declare
  f text;
begin
  foreach f in array array[
    'public.claim_badge_mileage(jsonb)',
    'public.get_my_mileage()',
    'public.get_my_mileage_history(integer, integer)',
    'public.redeem_mileage(text)'
  ] loop
    execute format('revoke execute on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end;
$$;
