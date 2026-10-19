// 만든 코스를 Supabase에 넣는 SQL로 바꾼다.
//
// 사용법 (먼저 tool/build_courses.dart로 코스를 만든다):
//   dart run tool/export_courses_sql.dart
//
// 출력: supabase/seed/courses.sql
// SQL Editor에서 실행한다. slug가 같으면 덮어쓰므로 여러 번 실행해도 된다.
import 'dart:convert';
import 'dart:io';

void main() {
  final config = jsonDecode(
    File('data/trails/courses.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final out = StringBuffer()
    ..writeln('-- 자동 생성 파일: dart run tool/export_courses_sql.dart')
    ..writeln('-- 원본: data/trails/courses.json, data/trails/courses/*.geojson')
    ..writeln('-- 먼저 migrations/20261020000000_create_courses.sql을 실행해야 한다.')
    ..writeln()
    ..writeln('begin;')
    ..writeln();

  for (final m in (config['mountains'] as List).cast<Map<String, dynamic>>()) {
    final summit = m['summit'] as Map<String, dynamic>;
    out.writeln(
      'insert into public.mountains '
      '(slug, name, region, height_m, summit_name, summit, source)\n'
      'values (${_s(m['id'])}, ${_s(m['name'])}, ${_s(m['region'])}, '
      '${m['height_m']}, ${_s(summit['name'])}, '
      'extensions.st_setsrid(extensions.st_makepoint(${summit['lon']}, ${summit['lat']}), 4326), '
      "'브이월드 검색·OpenStreetMap 대조')\n"
      'on conflict (slug) do update set name = excluded.name, region = excluded.region, '
      'height_m = excluded.height_m, summit_name = excluded.summit_name, '
      'summit = excluded.summit, source = excluded.source;',
    );
    out.writeln();
  }

  for (final c in (config['courses'] as List).cast<Map<String, dynamic>>()) {
    final feature = jsonDecode(
      File('data/trails/courses/${c['id']}.geojson').readAsStringSync(),
    ) as Map<String, dynamic>;
    final p = feature['properties'] as Map<String, dynamic>;
    final geometry = jsonEncode(feature['geometry']);
    out.writeln(
      'insert into public.courses (slug, mountain_id, name, start_name, end_name, path, '
      'distance_m, official_time_min, official_difficulty, source, license, updated_at)\n'
      'values (${_s(c['id'])}, '
      '(select id from public.mountains where slug = ${_s(c['mountain'])}), '
      '${_s(p['course_name'])}, ${_s(p['start_name'])}, ${_s(p['end_name'])}, '
      'extensions.st_setsrid(extensions.st_geomfromgeojson(${_s(geometry)}), 4326), '
      '${p['distance_m']}, ${p['official_time_min']}, ${_s(p['official_difficulty'])}, '
      '${_s(p['source'])}, null, now())\n'
      'on conflict (slug) do update set mountain_id = excluded.mountain_id, '
      'name = excluded.name, start_name = excluded.start_name, end_name = excluded.end_name, '
      'path = excluded.path, distance_m = excluded.distance_m, '
      'official_time_min = excluded.official_time_min, '
      'official_difficulty = excluded.official_difficulty, source = excluded.source, '
      'updated_at = now();',
    );
    out.writeln();
  }
  out.writeln('commit;');

  final file = File('supabase/seed/courses.sql')
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(out.toString());
  stdout.writeln('${file.path} 를 만들었어요.');
}

/// SQL 문자열 값. 작은따옴표를 두 번 써서 감싼다.
String _s(Object? value) =>
    value == null ? 'null' : "'${value.toString().replaceAll("'", "''")}'";
