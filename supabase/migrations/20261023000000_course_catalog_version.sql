-- 코스 목록이 바뀌었는지만 알려 주는 함수.
-- 앱은 이 값(코스 수, 마지막 수정 시각)을 기기에 저장된 값과 비교해서
-- 다를 때만 코스 전체를 내려받는다. (데이터 전송량 절약)

create function public.get_course_catalog_version()
returns table (
  course_count integer,
  latest_update timestamptz
)
language sql
stable
set search_path = ''
as $$
  select count(*)::integer, max(c.updated_at)
  from public.courses c;
$$;

revoke execute on function public.get_course_catalog_version() from public, anon;
grant execute on function public.get_course_catalog_version() to authenticated;
