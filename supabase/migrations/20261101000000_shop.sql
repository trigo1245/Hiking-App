-- 쇼핑 (일반 사용자 화면만, 시연용 결제): 상품, 주문, 상품 리뷰
-- 20261031000000_club_hall_of_fame_kick.sql 다음에 실행한다.
--
-- - 상품은 이 파일 맨 아래에서 넣는다(판매자 화면이 없으므로 고정 목록). 여러 번 실행해도 된다.
-- - 주문은 실제 결제 없이 place_order로 만든다. 배송지는 개인정보(private_profiles)를 주문할 때 그대로 복사해 둔다.
-- - 배송 상태는 저장하지 않고 주문 시각에서 계산한다(시연용): 1분 안 결제 완료 → 2분 안 배송 중 → 배송 완료.
-- - 상품 리뷰는 그 상품의 배송이 끝난 주문이 있는 사람만 쓴다. 상품당 1인 1개, 사진 3장(공개 버킷 review-photos).
--   사진 경로: {user_id}/product-{product_id}/{사진 id}.jpg

------------------------------------------------------------
-- 1. 상품
------------------------------------------------------------
create table public.products (
  id text primary key,
  category text not null
    check (category in ('shoes', 'backpack', 'poles', 'clothing', 'safety')),
  name text not null,
  description text not null,
  price integer not null check (price > 0),
  -- 고르는 옵션 이름(예: 사이즈)과 값. 옵션이 없으면 둘 다 null.
  option_name text,
  options text[],
  -- 상품 카드 그림의 색 번호 (사진 대신 코드로 그린다)
  art smallint not null default 0,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

alter table public.products enable row level security;

create policy "products: 로그인한 사용자 읽기"
  on public.products for select
  to authenticated
  using (true);

grant select on public.products to authenticated;

------------------------------------------------------------
-- 2. 주문 (본인만 읽는다. 만들기는 place_order로만)
------------------------------------------------------------
create table public.orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  product_id text not null references public.products (id),
  option_value text,
  quantity integer not null check (quantity between 1 and 5),
  unit_price integer not null,
  total_price integer not null,
  -- 주문할 때의 배송지 (나중에 개인정보를 바꿔도 이 주문의 배송지는 그대로)
  recipient_name text not null,
  recipient_phone text not null,
  postcode text,
  address text not null,
  address_detail text,
  created_at timestamptz not null default now(),
  is_demo boolean not null default false
);

create index orders_user_idx on public.orders (user_id, created_at desc);

alter table public.orders enable row level security;

create policy "orders: 본인 행 읽기"
  on public.orders for select
  to authenticated
  using ((select auth.uid()) = user_id);

grant select on public.orders to authenticated;

-- 시연용 배송 상태: 주문하고 1분 안 결제 완료, 2분 안 배송 중, 그 뒤 배송 완료
create function public.order_status(p_created_at timestamptz)
returns text
language sql
stable
set search_path = ''
as $$
  select case
    when now() - p_created_at < interval '1 minute' then 'paid'
    when now() - p_created_at < interval '2 minutes' then 'shipping'
    else 'delivered'
  end;
$$;

create function public.place_order(
  p_product_id text,
  p_option text,
  p_quantity integer
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_product public.products;
  v_info public.private_profiles;
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception '로그인이 필요해요' using errcode = '42501';
  end if;
  select * into v_product from public.products where id = p_product_id;
  if not found then
    raise exception '판매하지 않는 상품이에요' using errcode = '22023';
  end if;
  if p_quantity is null or p_quantity < 1 or p_quantity > 5 then
    raise exception '수량은 1~5개로 골라 주세요' using errcode = '22023';
  end if;
  if v_product.options is not null
     and (p_option is null or not (p_option = any (v_product.options))) then
    raise exception '옵션(%)을 골라 주세요', v_product.option_name using errcode = '22023';
  end if;

  select * into v_info from public.private_profiles where user_id = auth.uid();
  if coalesce(trim(v_info.name), '') = ''
     or coalesce(v_info.phone, '') = ''
     or coalesce(trim(v_info.address), '') = '' then
    raise exception '배송받을 이름·휴대폰 번호·주소를 먼저 입력해 주세요' using errcode = '22023';
  end if;

  insert into public.orders (
    user_id, product_id, option_value, quantity, unit_price, total_price,
    recipient_name, recipient_phone, postcode, address, address_detail
  ) values (
    auth.uid(), v_product.id,
    case when v_product.options is null then null else p_option end,
    p_quantity, v_product.price, v_product.price * p_quantity,
    v_info.name, v_info.phone, v_info.postcode, v_info.address, v_info.address_detail
  )
  returning id into v_id;
  return v_id;
end;
$$;

------------------------------------------------------------
-- 3. 상품 리뷰 (모두에게 공개, 읽기는 함수로)
------------------------------------------------------------
create table public.product_reviews (
  product_id text not null references public.products (id),
  user_id uuid not null references auth.users (id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  comment text check (char_length(comment) <= 200),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  is_demo boolean not null default false,
  primary key (product_id, user_id)
);

alter table public.product_reviews enable row level security;

create policy "product_reviews: 본인 행 읽기"
  on public.product_reviews for select
  to authenticated
  using ((select auth.uid()) = user_id);

grant select on public.product_reviews to authenticated;

create table public.product_review_photos (
  id uuid primary key,
  product_id text not null,
  user_id uuid not null,
  path text not null unique,
  created_at timestamptz not null default now(),
  foreign key (product_id, user_id)
    references public.product_reviews (product_id, user_id) on delete cascade
);

create index product_review_photos_review_idx
  on public.product_review_photos (product_id, user_id);

alter table public.product_review_photos enable row level security;

create policy "product_review_photos: 본인 행 읽기"
  on public.product_review_photos for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "product_review_photos: 본인 리뷰에 추가"
  on public.product_review_photos for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "product_review_photos: 본인 행 지우기"
  on public.product_review_photos for delete
  to authenticated
  using ((select auth.uid()) = user_id);

grant select, insert, delete on public.product_review_photos to authenticated;

create function public.check_product_photo_limit()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (select count(*) from public.product_review_photos
      where product_id = new.product_id and user_id = new.user_id) >= 3 then
    raise exception '리뷰 사진은 3장까지 올릴 수 있어요' using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger product_review_photos_limit
  before insert on public.product_review_photos
  for each row execute function public.check_product_photo_limit();

-- 이 상품의 배송이 끝난 주문이 있는지 (리뷰 자격)
create function public.can_review_product(p_product_id text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.orders o
    where o.user_id = auth.uid() and o.product_id = p_product_id
      and public.order_status(o.created_at) = 'delivered'
  );
$$;

create function public.upsert_my_product_review(
  p_product_id text,
  p_rating integer,
  p_comment text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.can_review_product(p_product_id) then
    raise exception '배송이 끝난 상품만 리뷰를 쓸 수 있어요' using errcode = '42501';
  end if;
  if p_rating is null or p_rating < 1 or p_rating > 5 then
    raise exception '별점을 골라 주세요' using errcode = '22023';
  end if;
  insert into public.product_reviews (product_id, user_id, rating, comment)
  values (p_product_id, auth.uid(), p_rating, nullif(trim(p_comment), ''))
  on conflict (product_id, user_id) do update
  set rating = excluded.rating, comment = excluded.comment, updated_at = now();
end;
$$;

-- 지운 리뷰의 사진 경로를 돌려준다 (앱이 Storage에서 파일을 지운다).
create function public.delete_my_product_review(p_product_id text)
returns text[]
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_paths text[];
begin
  select coalesce(array_agg(path), '{}') into v_paths
  from public.product_review_photos
  where product_id = p_product_id and user_id = auth.uid();
  delete from public.product_reviews
  where product_id = p_product_id and user_id = auth.uid();
  return v_paths;
end;
$$;

-- 내 리뷰와 리뷰 자격. 리뷰가 없으면 rating이 null이다.
create function public.get_my_product_review(p_product_id text)
returns table (can_review boolean, rating smallint, comment text)
language sql
stable
security definer
set search_path = ''
as $$
  select public.can_review_product(p_product_id), r.rating, r.comment
  from (select 1) as one
  left join public.product_reviews r
    on r.product_id = p_product_id and r.user_id = auth.uid();
$$;

-- 상품 리뷰 목록: p_sort = 'recent'(최신순) | 'rating'(별점 높은 순). 30개씩 나눠 받는다.
create function public.get_product_reviews(
  p_product_id text,
  p_sort text default 'recent',
  p_offset integer default 0,
  p_limit integer default 30
)
returns table (
  nickname text,
  nickname_tag text,
  avatar_url text,
  rating smallint,
  comment text,
  created_at timestamptz,
  is_mine boolean,
  photo_paths text[],
  total_count integer
)
language sql
stable
security definer
set search_path = ''
as $$
  with base as (
    select r.*, (count(*) over ())::integer as total
    from public.product_reviews r
    where r.product_id = p_product_id
  )
  select p.nickname, p.nickname_tag, p.avatar_url, b.rating, b.comment,
    b.created_at, b.user_id = auth.uid(),
    coalesce(
      (select array_agg(ph.path order by ph.created_at)
        from public.product_review_photos ph
        where ph.product_id = b.product_id and ph.user_id = b.user_id),
      '{}'
    ),
    b.total
  from base b
  join public.profiles p on p.id = b.user_id
  order by
    case when p_sort = 'rating' then b.rating end desc nulls last,
    b.created_at desc
  offset greatest(p_offset, 0)
  limit least(greatest(p_limit, 1), 50);
$$;

create function public.get_my_orders()
returns table (
  id uuid,
  product_id text,
  product_name text,
  category text,
  art smallint,
  option_name text,
  option_value text,
  quantity integer,
  total_price integer,
  recipient_name text,
  recipient_phone text,
  postcode text,
  address text,
  address_detail text,
  created_at timestamptz,
  status text,
  has_review boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select o.id, o.product_id, p.name, p.category, p.art, p.option_name, o.option_value,
    o.quantity, o.total_price, o.recipient_name, o.recipient_phone, o.postcode,
    o.address, o.address_detail, o.created_at, public.order_status(o.created_at),
    exists (
      select 1 from public.product_reviews r
      where r.product_id = o.product_id and r.user_id = o.user_id
    )
  from public.orders o
  join public.products p on p.id = o.product_id
  where o.user_id = auth.uid()
  order by o.created_at desc;
$$;

-- 상품 목록 (별점 평균·리뷰 수 포함)
create function public.get_products()
returns table (
  id text,
  category text,
  name text,
  description text,
  price integer,
  option_name text,
  options text[],
  art smallint,
  rating_avg numeric,
  review_count integer
)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, p.category, p.name, p.description, p.price, p.option_name, p.options,
    p.art,
    round((select avg(r.rating) from public.product_reviews r where r.product_id = p.id), 1),
    (select count(*)::integer from public.product_reviews r where r.product_id = p.id)
  from public.products p
  order by p.sort_order, p.name;
$$;

------------------------------------------------------------
-- 4. 함수 실행 권한: 로그인한 사용자만
------------------------------------------------------------
do $$
declare
  f text;
begin
  foreach f in array array[
    'public.place_order(text, text, integer)',
    'public.get_my_orders()',
    'public.can_review_product(text)',
    'public.upsert_my_product_review(text, integer, text)',
    'public.delete_my_product_review(text)',
    'public.get_my_product_review(text)',
    'public.get_product_reviews(text, text, integer, integer)',
    'public.get_products()'
  ] loop
    execute format('revoke execute on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end;
$$;

------------------------------------------------------------
-- 5. 상품 목록 (가상의 상품. 실제 브랜드·상품이 아니다)
------------------------------------------------------------
insert into public.products
  (id, category, name, description, price, option_name, options, art, sort_order)
values
  ('trail-light-shoes', 'shoes', '산길 경량 등산화',
   '가벼운 메시 소재로 동네 산과 둘레길에 알맞아요. 밑창 홈이 깊어 흙길에서도 덜 미끄러져요.',
   129000, '사이즈', array['240', '250', '260', '270', '280'], 0, 10),
  ('ridge-mid-boots', 'shoes', '능선 미드컷 등산화',
   '발목을 감싸는 미드컷이라 바위길과 내리막에서 발목을 잡아 줘요. 방수 안감이 들어 있어요.',
   189000, '사이즈', array['240', '250', '260', '270', '280'], 1, 11),
  ('dayhike-22', 'backpack', '데이하이크 22L 배낭',
   '당일 산행에 필요한 물·간식·바람막이가 들어가는 크기예요. 등판이 통풍돼요.',
   79000, '색상', array['블루', '그레이', '오렌지'], 2, 20),
  ('ridge-35', 'backpack', '종주 35L 배낭',
   '긴 코스에 알맞은 35L. 허리 벨트로 무게를 나눠 어깨가 덜 아파요. 레인커버 포함.',
   139000, '색상', array['블랙', '그린'], 3, 21),
  ('carbon-poles', 'poles', '카본 접이식 스틱 (2개)',
   '한 개 210g의 가벼운 카본 스틱. 3단으로 접혀 배낭 옆에 꽂을 수 있어요. 급경사 내리막에서 무릎 부담을 줄여 줘요.',
   89000, null, null, 4, 30),
  ('alu-poles', 'poles', '알루미늄 스틱 (2개)',
   '튼튼하고 값이 부담 없는 입문용 스틱. 길이를 돌려서 맞춰요.',
   39000, null, null, 5, 31),
  ('wind-jacket', 'clothing', '바람막이 재킷',
   '정상에서 땀이 식을 때 걸치는 얇은 바람막이. 주머니에 접어 넣을 수 있어요.',
   99000, '사이즈', array['S', 'M', 'L', 'XL'], 6, 40),
  ('dry-tee', 'clothing', '속건 반팔 티셔츠',
   '땀이 빨리 마르는 기능성 원단이라 오르막에서도 덜 끈적여요.',
   29000, '사이즈', array['S', 'M', 'L', 'XL'], 7, 41),
  ('warm-gloves', 'clothing', '보온 등산 장갑',
   '손바닥에 미끄럼 방지 처리를 한 겨울 장갑. 터치스크린을 쓸 수 있어요.',
   25000, '사이즈', array['M', 'L'], 8, 42),
  ('headlamp-400', 'safety', '헤드랜턴 400루멘',
   '해 지기 전 하산이 늦어질 때를 대비하는 머리 랜턴. USB로 충전해요.',
   35000, null, null, 9, 50),
  ('first-aid-kit', 'safety', '휴대용 응급 키트',
   '밴드·소독 솜·압박 붕대·은박 담요가 든 손바닥만 한 응급 키트예요.',
   25000, null, null, 10, 51),
  ('safety-whistle', 'safety', '안전 호루라기 나침반',
   '조난 때 멀리까지 들리는 호루라기와 작은 나침반을 하나로 묶었어요.',
   12000, null, null, 11, 52)
on conflict (id) do update
set category = excluded.category, name = excluded.name,
  description = excluded.description, price = excluded.price,
  option_name = excluded.option_name, options = excluded.options,
  art = excluded.art, sort_order = excluded.sort_order;
