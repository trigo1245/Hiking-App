# CLAUDE.md

이 파일은 Claude Code가 매 세션 시작 시 읽는 프로젝트 안내문이다. 팀원 모두가 같은 파일을 공유한다.
프로젝트 내내 변하지 않는 사실과 규칙만 적는다. 일회성 작업 지시는 넣지 않는다.

---

## 1. 프로젝트 개요

등산인 커뮤니티 Android 앱 (대학 개발 프로젝트, 팀 프로젝트).
최종 목표: 등산 기록 → 등산로 평가 → 코스별 경쟁(정복자) → 개인 구독 → 동호회.

**현재 단계: 프로토타입 1단계**
- 범위: 메인 화면, 등산 기록 측정(GPS), 기록 저장, 서버 업로드
- 범위 밖: 지도 표시, 등산로(코스) 데이터, 코스 매칭, 평가, 경쟁, 구독, 동호회
- 지도가 들어갈 자리는 회색 플레이스홀더 박스로 둔다. 지도 라이브러리는 아직 추가하지 않는다.

기획 문서는 `docs/` 폴더에 있다. 기능의 의도나 BM 관련 판단이 필요할 때만 읽는다.
- `docs/planning.md` — 개발기획보고서 (전체 기획, BM)

---

## 2. 팀과 개발자 정보

- 팀원 모두 Flutter·Android 개발 경험이 거의 없다. 코드를 작성한 뒤에는 **핵심 개념과 실행 흐름을 짧게 설명**한다.
- 주 개발자는 아이폰 사용자라 Android 실기기 테스트는 가끔만 가능하다.
  - 에뮬레이터나 테스트 코드로 검증 가능한 방법을 우선한다.
  - 실기기에서만 확인 가능한 사항은 작업 끝에 "실기기 확인 필요: ..." 형식으로 명시한다.
- 여러 명이 동시에 작업하므로, 요청받은 기능과 무관한 파일은 수정하지 않는다.

---

## 3. 기술 스택

| 영역 | 선택 |
|---|---|
| 앱 | Flutter (Dart), Android 우선 |
| 상태 관리 | flutter_riverpod |
| 화면 이동 | go_router |
| 위치 | geolocator (Android 포그라운드 서비스 알림 설정 사용) |
| 기기 내부 DB | drift (SQLite) |
| 백엔드 | Supabase (Auth, PostgreSQL, Storage) — supabase_flutter |
| 로그인 | google_sign_in (구글 네이티브 로그인), 카카오는 Supabase OAuth(브라우저) |
| 기타 | uuid, path_provider, permission_handler |
| 폰트 | Pretendard (OFL 라이선스, assets에 포함) |

- 새 패키지를 추가할 때는 **이유와 대안을 먼저 설명**하고 진행한다.
- 위 목록과 다른 패키지로 바꾸려면 이유를 설명하고 확인을 받는다.

---

## 4. 폴더 구조 (기능 단위)

```
lib/
  main.dart
  app/            # 앱 진입, 라우터, 테마
  core/           # 공통: 디자인 토큰, 공용 위젯, 유틸(거리 계산 등), Supabase 클라이언트
  features/
    auth/
    home/
    recording/    # 기록 측정 (위치 수집, 포그라운드 서비스)
    activities/   # 기록 목록, 상세, 업로드
      data/         # DB·서버 접근 (repository)
      domain/       # 모델, 계산 로직 (Flutter 의존 없음)
      presentation/ # 화면, 위젯, provider
test/             # lib 구조를 그대로 따른다
test_data/        # 테스트용 GPX 파일
tool/             # 개발 보조 스크립트 (GPX 재생 등)
docs/             # 기획·설계 문서
supabase/         # SQL 마이그레이션
```

- 계산 로직(거리, 고도, 속도 검증)은 `domain/`에 순수 Dart로 작성해 단위 테스트가 가능하게 한다.
- 화면 위젯 안에 DB 접근이나 계산 로직을 직접 쓰지 않는다.

---

## 5. 1단계 화면

하단 탭: **홈 / 기록 / 내 정보**

1. **홈**: 이번 달 요약(횟수, 총 거리, 총 시간), 최근 기록 카드 2~3개, 하단 고정 "등산 기록 시작" 버튼
2. **기록 중**: 경과 시간(가장 크게), 거리, 현재 고도, 누적 상승고도. 일시정지 / 종료 버튼. 지도 자리는 플레이스홀더
3. **기록 완료**: 요약 수치, 제목 입력(기본값: "MM월 DD일 등산"), "저장하기" 버튼
4. **기록 목록**: 날짜 역순 카드 목록, 업로드 상태 표시(업로드 대기 / 완료 / 실패)
5. **기록 상세**: 수치 전체, GPX 내보내기(공유) 버튼, 재업로드 버튼
6. **내 정보**: 닉네임, 로그아웃, 로그 파일 내보내기(테스트용)
7. **로그인**: 카카오로 시작 / 구글로 시작. 익명 로그인과 계정 연동(linkIdentity)은 하지 않는다. 카카오 계정과 구글 계정은 각각 별개의 사용자다.
   - 딥링크 `com.hikingapp.hikingapp://login-callback`은 `lib/core/config/env.dart`, `AndroidManifest.xml`, Supabase Redirect URLs 세 곳이 같아야 한다.

---

## 6. 등산 기록 규칙

### 위치 수집
- 포그라운드 서비스 + 상단 고정 알림("등산 기록 중이에요")으로 화면이 꺼져도 기록한다.
- 권한: 위치(정밀) → 알림(Android 13+) 순으로 요청한다. 포그라운드 서비스는 앱이 화면에 떠 있을 때 시작하므로, 1단계에서는 백그라운드 위치("항상 허용") 권한을 요청하지 않는다.
- Manifest에 `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `POST_NOTIFICATIONS` 등 필요한 권한을 선언한다.
- 권한 거부 시 이유를 설명하는 화면과 설정으로 이동하는 버튼을 제공한다.
- 정확도(accuracy)가 30m보다 나쁜 점은 계산에서 제외하되 원본은 저장한다.

### 저장 (오프라인 우선)
- 수집한 위치는 **즉시 기기 내부 DB에 저장**한다. 앱이 강제 종료돼도 기록이 남아야 한다.
- 앱 재시작 시 "기록 중" 상태로 끝난 기록이 있으면 이어서 기록할지, 종료할지 묻는다.
- 기록 ID는 기기에서 UUID로 생성한다. 같은 기록을 다시 업로드해도 중복되지 않도록 upsert를 사용한다.

### 계산
- 거리: 하버사인 공식으로 인접한 점 사이 거리를 합산한다.
- 누적 상승고도: GPS 고도 흔들림을 걸러내기 위해 임계값(3m) 이상 변화만 누적한다.
- 시간: 전체 경과 시간과 이동 시간(일시정지·정지 구간 제외)을 따로 저장한다.
- 부정행위 대비: 인접 점 사이 속도가 시속 15km를 넘는 구간이 있으면 기록에 `is_flagged = true` 표시만 한다(1단계는 표시만).

### 업로드
- 기록 저장 후 자동 업로드를 시도하고, 실패하면 "업로드 대기"로 두었다가 네트워크가 돌아오면 재시도한다.
- 업로드 내용: GPX 파일은 Storage, 요약 수치는 DB.

---

## 7. Supabase 구조 (1단계)

SQL은 `supabase/migrations/`에 파일로 남긴다. 대시보드에서만 바꾸지 않는다.

```
profiles   : id(uuid, auth.users 참조), nickname, created_at
activities : id(uuid, 기기에서 생성), user_id, title, started_at, ended_at,
             elapsed_s, moving_s, distance_m, elevation_gain_m, max_altitude_m,
             point_count, gpx_path, is_flagged, created_at
             course_id(null 허용, 이후 코스 매칭 단계에서 사용)
Storage    : 버킷 tracks (비공개), 경로 {user_id}/{activity_id}.gpx
```

- 모든 테이블에 RLS를 켠다. 1단계 정책: 본인 행만 읽기·쓰기 가능.
- 이후 단계의 설계 제약 (지금 구현하지 않지만 충돌하는 구조를 만들지 않는다):
  - 동호회 소속은 기간(joined_at, left_at)으로 저장한다. 동호회 랭킹은 기록 시점의 소속 기준이다.
  - 권한(구독 플랜)은 화면이 아니라 DB(RLS)에서 검사한다.
  - 사진은 Storage에 저장하고 DB에는 경로만 둔다. 업로드 전 기기에서 압축하고 EXIF 위치 정보는 제거한다.

---

## 8. 디자인 원칙 (토스 스타일의 깔끔함)

특정 서비스의 로고, 이름, 전용 폰트는 사용하지 않는다. 아래는 지향하는 **스타일 원칙**이다.

### 원칙
- **한 화면에 하나의 핵심 행동.** 주요 버튼은 화면 하단에 꽉 찬 너비로 고정한다.
- **숫자가 주인공.** 기록 화면의 시간·거리는 크고 굵게, 단위는 작고 연하게.
- **넉넉한 여백, 적은 장식.** 테두리선과 그림자는 최소화하고, 배경색 차이로 영역을 나눈다.
- **문구는 짧은 해요체.** 예: "기록을 시작할게요", "업로드에 실패했어요. 다시 시도할까요?"
- 오류·빈 화면에도 다음 행동을 안내하는 문구와 버튼을 둔다.
- 로딩은 스피너보다 스켈레톤(회색 박스)을 우선한다.

### 디자인 토큰 (`lib/core/design/`에 정의, 위젯에 값을 직접 쓰지 않는다)

| 토큰 | 값 |
|---|---|
| primary | #3182F6 (브랜드 색 확정 시 이 값만 교체) |
| background | #FFFFFF |
| backgroundGrouped | #F2F4F6 (카드 뒤 배경) |
| textPrimary | #191F28 |
| textSecondary | #4E5968 |
| textTertiary | #8B95A1 |
| divider | #E5E8EB |
| danger | #F04452 |
| success | #03B26C |

- 간격: 4의 배수 (4, 8, 12, 16, 20, 24, 32). 화면 좌우 여백 20.
- 모서리: 카드 20, 버튼 16, 입력창 12.
- 글자 크기: 대형 수치 40 Bold / 제목 24 Bold / 소제목 18 SemiBold / 본문 16 Regular / 보조 13 Regular.
- 하단 고정 버튼: 높이 56, 좌우 여백 20, primary 배경, 흰 글씨 17 SemiBold.
- 터치 시 살짝 눌리는 효과(scale 0.97)와 가벼운 햅틱을 준다.
- 다크 모드는 이후 단계. 단, 색은 반드시 토큰으로만 써서 나중에 추가하기 쉽게 한다.

---

## 9. 검증 방법

- 기능 하나를 마칠 때마다 `flutter analyze`를 실행하고 경고·오류를 해결한다.
- `domain/`의 계산 로직은 `flutter test`로 단위 테스트를 작성한다. `test_data/`의 GPX를 활용한다.
- 위치 기능은 에뮬레이터에서 확인한다.
  - 단일 좌표: `adb emu geo fix <경도> <위도>` (경도가 먼저)
  - 경로 재생: `tool/`의 GPX 재생 스크립트로 점을 순서대로 전송
- 화면 확인이 필요하면 `adb exec-out screencap -p > screen.png`로 캡처해서 확인한다.

---

## 10. 협업 규칙

- `main` 브랜치에 직접 커밋하지 않는다. 기능마다 브랜치를 만든다: `feat/recording-screen`, `fix/upload-retry`.
- 커밋 메시지: `feat: 기록 화면 추가`, `fix: 업로드 재시도 오류 수정`, `docs: ...`, `refactor: ...`, `test: ...`
- 작업이 끝나면 Pull Request를 만들고 다른 팀원이 확인한 뒤 합친다.
- **절대 커밋하지 않는 것**: `env.json`(Supabase URL·키), 서명 키(`*.jks`, `key.properties`). `.gitignore`에 등록되어 있는지 확인한다.
- 비밀 값은 `env.json`에 두고 `flutter run --dart-define-from-file=env.json`으로 주입한다. 팀원용 예시 파일 `env.example.json`만 커밋한다.

---

## 11. 자주 쓰는 명령

```
flutter pub get
flutter run --dart-define-from-file=env.json
flutter analyze
flutter test
dart run build_runner build --delete-conflicting-outputs   # drift 코드 생성
flutter build apk --release --dart-define-from-file=env.json
```
