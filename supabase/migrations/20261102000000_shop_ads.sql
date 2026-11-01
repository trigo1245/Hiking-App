-- 쇼핑 광고 상품: 상품에 광고 순서(ad_rank)를 두고, 상품 목록 함수가 함께 돌려준다.
-- 20261101000000_shop.sql 다음에 실행한다. 여러 번 실행해도 된다.
--
-- - ad_rank가 null이 아니면 광고 상품이다(작을수록 먼저). 바꾸려면 아래 update를 고쳐 다시 실행한다.
-- - 쇼핑 화면 맨 위 광고 칸은 최대 2개. 광고 상품이 더 많으면 화면에 들어올 때마다 번갈아 보여 주고,
--   칸에 들어가지 못한 광고 상품은 일반 상품처럼 목록에 나온다(앱의 ShopLayout).

alter table public.products add column if not exists ad_rank smallint;

-- 등산화가 3개가 되도록 하나 더 (카테고리 안에서도 광고가 번갈아 보이게)
insert into public.products
  (id, category, name, description, price, option_name, options, art, sort_order)
values
  ('trail-runner', 'shoes', '가벼운 트레일 러닝화',
   '한 짝 280g의 가벼운 러닝화. 짧은 코스를 빠르게 다녀오거나 둘레길을 걸을 때 좋아요.',
   109000, '사이즈', array['240', '250', '260', '270', '280'], 12, 12)
on conflict (id) do update
set category = excluded.category, name = excluded.name,
  description = excluded.description, price = excluded.price,
  option_name = excluded.option_name, options = excluded.options,
  art = excluded.art, sort_order = excluded.sort_order;

-- 광고 상품 4개: 등산화 3개 + 배낭 1개
update public.products set ad_rank = null;
update public.products p
set ad_rank = a.rank
from (values
  ('ridge-mid-boots', 1),
  ('ridge-35', 2),
  ('trail-runner', 3),
  ('trail-light-shoes', 4)
) as a(id, rank)
where p.id = a.id;

-- 반환 형태가 바뀌어 다시 만든다.
drop function if exists public.get_products();

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
  review_count integer,
  ad_rank smallint
)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, p.category, p.name, p.description, p.price, p.option_name, p.options,
    p.art,
    round((select avg(r.rating) from public.product_reviews r where r.product_id = p.id), 1),
    (select count(*)::integer from public.product_reviews r where r.product_id = p.id),
    p.ad_rank
  from public.products p
  order by p.sort_order, p.name;
$$;

revoke execute on function public.get_products() from public, anon;
grant execute on function public.get_products() to authenticated;
