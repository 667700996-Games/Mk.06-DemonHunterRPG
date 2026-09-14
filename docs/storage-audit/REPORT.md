# 디스크 조사·정리 결과 — 2026-09-15

## 프로젝트 확인

- 엔진: 설치된 `4.7.2.stable.official.ed1daf0bf`와 Godot 4 프로젝트.
- 대상: `export_presets.cfg`의 macOS Universal, Windows Desktop. 모바일·웹·콘솔 프리셋 없음.
- 기존 도구: Godot CLI/GUI 직접 실행, README의 검증 명령과 GDScript 테스트.
  별도 빌드/압축/CI 스크립트, AGENTS.md, 프로젝트 내부 패키지 디렉토리는 없었음.
- 출시 여부는 확정할 수 없음. 로컬 출시 태그·배포 패키지·patch 목록은 없고,
  README는 서명/공증 바이너리를 커밋하지 않는다고 명시. 외부 배포/롤백 저장소는 조사·삭제하지 않음.
- Godot 앱 345,424KiB, 설치된 템플릿 2,023,752KiB는 프로젝트 밖 필수 도구로 보존.
  사용자 저장소, 키, 인증 정보, 공용 캐시 및 `.git` 정리는 수행하지 않음.

## 용량과 누적 원인

측정은 `du -k`의 실제 할당량 기준이며 `before.json`에 모든 기존 파일의 논리 크기,
할당량, SHA-256과 상위 디렉토리 용량을 기록했다. `.git`은 용량만 측정했다.

| 분류 | 정리 전 할당량 | 근거/처리 |
|---|---:|---|
| 전체 프로젝트 (`.git` 포함) | 13,832KiB | 최종 측정은 아래 표 |
| `.git` | 2,940KiB | 삭제/정리하지 않음 |
| 원본 에셋 (`assets/`) | 1,808KiB | PNG 원본+import 설정, 그대로 보존 |
| 기존 녹화·검증 기록 71개 | 7,020KiB | `.godot/item-*` PNG/WAV와 원문 로그, 보존 |
| 재생성 import/export 캐시 6개 | 1,540KiB | 원본 연결 확인 후 삭제 |
| 나머지 `.godot` 편집기 상태 | 44KiB | UID/클래스/편집기 상태 보존 |
| 코드/설정/문서 등 | 480KiB | 게임 원본 보존; 정책·도구만 추가 |

큰 파일: 원본 `title_graveyard.png` 1,844,069B, 생성 `.ctex` 1,538,154B,
녹화 PNG의 큰 프레임은 약 163KB. 실질적인 큰 덩어리는 반복된 UI 녹화·검증 기록
약 6.86MiB이며, 원본 에셋은 약 1.77MiB이다. 대용량 패키지/압축 해제 사본 누적은
발견되지 않았다. 이 프로젝트 자체는 작은 규모다.

`capture` 관련 로그는 Godot Movie Maker가 1280×720/60FPS로 녹화했다고 기록한다.
`.godot/item-ui*`, `item-compare*`의 프레임/음성은 이에 대응하는 검증 기록이다.
동일 SHA-256인 로그 그룹 2개와 WAV 그룹 1개도 있지만, 서로 다른 검증 맥락의 이름을
가진 기록이므로 삭제하지 않았다. 폴딩 상태 파일 3개도 동일하지만 편집기 상태로 보존했다.
기존 README의 실행 명령/GUI export에는 보관 개수나 임시 작업 수명 관리가 없었다.

## 실행한 삭제와 보존 검증

`deleted.json`에 정확한 파일 경로·삭제 사유·삭제 전 SHA-256을 기록했다.

- `.godot/imported/`의 `.ctex` 및 `.md5` 2개: 원본 PNG와 import metadata의
  source/destination 연결 확인. 격리된 작업 사본에서 실제 재import 성공.
- `.godot/exported/133200997/`의 `.res` 2개, `.scn` 1개, `file_cache` 1개:
  캐시가 원본 `content.tres`, `main.tscn`, `default_bus_layout.tres`와 연결됨을
  `file_cache` 및 기존 `export-validation.log`로 확인.
- 정확히 이 6개를 해시 대조 후 개별 삭제하고 비어 있는 해당 디렉토리만 제거.
  삭제 직전 `ps`/`lsof`에서 원본 프로젝트의 실행 중인 Godot/열린 `.godot` 파일 없음.
- 나머지 기존 파일 143개 SHA-256 일치. 기존 README와 `.gitignore`만 의도적 수정.
  원본 코드·에셋·씬·프리셋·기존 검증 기록 보존. 상세: `preservation.json`.

## 전후 측정

| 측정 | 시작 | 완료 | 변화 |
|---|---:|---:|---:|
| 프로젝트 전체 | 13,832KiB (13.508MiB) | 12,616KiB (12.320MiB) | 1,216KiB 감소 |
| 파일시스템 가용 공간 | 115,813,810,176B | 116,150,165,504B | +336,355,328B (전체 작업 기간 관측값) |

삭제한 파일 논리 크기는 1,557,105B, 할당량은 1,576,960B이다.
삭제 직전 14,028KiB → 직후 12,488KiB: 정확히 1,540KiB 감소.
같은 순간의 파일시스템 가용 공간은 115,645,792,256B → 115,647,430,656B:
**관측 증가 1,638,400B (1.5625MiB)**. 파일 할당량 감소와 동일한 수치로 취급하지 않는다.
백그라운드 I/O·APFS·캐시 때문에 파일시스템 여유 공간 차이를 전부 이번 삭제에
귀속할 수 없다. 전체 작업 기간의 여유 공간 변화도 별도로 `after.json`에 기록한다.
최종 프로젝트 감소량에는 새 도구·규칙·검증 기록과 작업 중 Git 크기 변화가 반영된다.

## 자동화와 검증

- `tools/build.py`: 원본과 격리된 전용 작업 사본, 소유 표식, 등록/작업 잠금,
  명령 보호 프로세스와 프로세스 그룹 확인, 성공/실패/일반 중단 정리, 다음 실행의
  강제 종료 잔여물 회수. 위험한 임의 경로·symlink·알 수 없는 항목은 경고 후 보존.
- 검증된 출력의 SHA-256을 기록하고 flush/rename 후 latest 포인터를 원자적으로 교체.
  새 빌드/게시 실패 시 이전 정상 출력 보존.
- 개발 성공 결과는 대상별 2회, 원문 로그는 전체 최근 10회·각 마지막 1MiB.
  출시/롤백/patch 기준 보관본과 심볼은 이 제한에서 제외. 실패한 개발 작업의 심볼도 보존.
- `.github/workflows/build.yml`: push/PR에서 수명주기 테스트, 수동 실행에서 실제
  Godot 패키징과 `always()` cleanup 연결. `checkout clean:false`로 ignored 보관본 보호.
- `AGENTS.md`와 `docs/BUILD_STORAGE.md`: 새 빌드 도구에도 같은 정책을 의무화하고
  날짜/번호 복제 금지, 디버깅 보존의 목적·위치·담당자·정리 시점 기록 규칙 추가.

**자동 테스트 14개 통과** (`cleanup-tests.txt`): 성공/실패, 0 exit+Godot 오류 탐지,
유효하지 않은 패키지 거부, SIGINT/TERM/HUP, CLI SIGKILL 후 살아 있는 자식 보호,
보호 프로세스 강제 종료 시 살아 있는 엔진 보호, 전원 차단과 같은 버려진 작업 복구,
동시 빌드/정리, 정상 산출물/포인터 보존, 개수·로그 크기·대상별 보관,
출시/심볼 보존, 외부 경로/symlink 거부, 정리 실패 경고를 검증했다.
실제 전원 차단은 수행하지 않았으며 잠금이 해제된 잔여 작업으로 복구 상황을 모사했다.
Workflow YAML 구문과 `git diff --check`도 통과했다.

**실제 Windows Desktop export 검증 성공** (`representative-build.txt`):
macOS 호스트에서 109,648,184B의 EXE+console wrapper 생성, PE 서명 확인,
내장 PCK의 데이터/이미지 로드와 메인 씬 remap 존재 확인, SHA-256 기록.
검증 전용 출력과 작업 사본은 자동 제거됐고 `work/`는 비어 있다.
게임 저장 데이터를 건드리지 않도록 게임 플레이와 Autoload가 필요한 메인 씬 실행은 하지 않았다.

### 제한과 확인 대기

- 기존 macOS Universal export는 ETC2 ASTC 가져오기 미설정으로 엔진이 거부했다.
  출시 설정을 임의 변경하지 않았다. 해당 실행의 작업 사본은 정상 정리됐고 로그는 보존됐다.
- Windows 기기에서의 실제 게임 실행, macOS 앱 실행·서명·공증, 출시 모드 실제 export는 미검증.
- CI는 파일 연결 및 YAML 검증까지 완료. 원격 실행은 하지 않았으며
  `self-hosted, macOS, godot-4.7.2` 러너와 일치하는 템플릿 설치가 필요하다.
- Linux 호스트에서는 테스트를 실행하지 않았다. Windows 네이티브 호스트·모바일·웹·콘솔은 범위 밖.
- 기존 녹화·검증 기록의 삭제 시점은 담당자 확인 대기. `docs/BUILD_STORAGE.md` 예외 표에 기록했다.

근거: 프로젝트 프리셋·README·기존 로그, 실제 설치 엔진 `--help`,
[Godot CLI](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html),
[캐시 설명](https://docs.godotengine.org/en/stable/tutorials/best_practices/version_control_systems.html),
[GitHub workflow 문법](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax).
