-- 마일리지: 배지 적립은 하루 한도에서 뺀다.
-- 20261103000000_mileage.sql 다음에 실행한다. 여러 번 실행해도 된다.
--
-- 배지는 단계마다 평생 한 번만 받는 보상이다. 처음 앱을 열 때 지금까지 얻은 배지가 한꺼번에 들어오면서
-- 하루 한도를 다 써 버려 그날 기록·리뷰 적립이 막혔다. 그래서 한도는 반복할 수 있는 행동
-- (산행 기록·완주·리뷰·리뷰 사진)에만 걸고, 배지는 한도 없이 주고 한도 계산에도 넣지 않는다.

-- 오늘(한국 시간) 받은 적립 합계 (배지 제외)
create or replace function public.mileage_earned_today(p_user uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(sum(amount), 0)::integer
  from public.mileage_ledger
  where user_id = p_user and amount > 0 and reason <> 'badge'
    and (created_at at time zone 'Asia/Seoul')::date = (now() at time zone 'Asia/Seoul')::date;
$$;

-- p_partial이 null이면 하루 한도를 보지 않는다(배지).
create or replace function public.mileage_award(
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
  if p_partial is not null then
    v_left := v_cap - public.mileage_earned_today(p_user);
    if v_left <= 0 or (not p_partial and v_left < v_amount) then
      return 0;
    end if;
    v_amount := least(v_amount, v_left);
  end if;
  insert into public.mileage_ledger (user_id, amount, reason, label, source_key)
  values (p_user, v_amount, p_reason, p_label, p_key)
  on conflict (user_id, source_key) do nothing;
  return v_amount;
end;
$$;

revoke execute on function public.mileage_earned_today(uuid) from public, anon, authenticated;
revoke execute on function public.mileage_award(uuid, text, text, text, integer, boolean)
  from public, anon, authenticated;

-- 배지 적립: 한도 없이 (배지·단계마다 처음 1번만)
create or replace function public.claim_badge_mileage(p_claims jsonb)
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
      '배지 · ' || left(coalesce(v_claim ->> 'name', v_id), 20), v_base, null);
  end loop;
  return v_total;
end;
$$;
