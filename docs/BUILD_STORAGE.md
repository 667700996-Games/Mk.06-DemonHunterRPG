# 빌드 저장 공간 정책

## 확인한 환경과 실행

Godot 4.7.2 stable, macOS Universal / Windows Desktop. 기존 배포 프리셋과
서명·버전 설정은 변경하지 않는다. 빌드 호스트는 Python 3.9+가 있는 macOS 또는
Linux/POSIX이다. Windows 결과물을 macOS에서 교차 빌드할 수 있다. Windows 네이티브
호스트, 웹·모바일·콘솔은 구현/검증 범위가 아니다.

```sh
python3 tools/build.py build --target macos
python3 tools/build.py build --target windows
python3 tools/build.py build --target pack
python3 tools/build.py build --target macos --verify-only
python3 tools/build.py build --target macos --release 1.0.0-candidate1
python3 tools/build.py clean
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p 'test_build_cleanup.py' -v
```

`GODOT` 또는 `--godot`으로 실행 파일 지정. 앱/EXE에는 엔진과 일치하는 설치된
export templates가 필요하다. `pack`은 게임 데이터 검증용이며 독립 실행 파일이 아니다.
기본은 개발/debug export이고 `--release LABEL`만 release 모드로 영구 보관한다.
`--verify-only`는 검증 목적으로 만든 개발 결과물을 남기지 않는다.
출시 라벨 재사용은 거부한다. 이 명령은 스토어 업로드·서명·공증을 수행하지 않는다.

## 소유권과 수명

`builds/.managed/owner.json`은 도구·프로젝트 소유권을 식별한다. 임시 파일은
`work/<UUID>/`의 원본 작업 사본·Godot import/export 캐시·로그·TMPDIR에만 둔다.
입력은 `tools/build.py:INPUTS`에 명시되어 있으며 새 리소스 루트/플러그인은 여기에
추가해야 한다. 원본 symlink는 자동 추적하지 않고 오류로 보고한다. 원본을 편집
중인 상태에서 빌드할 수 있으나 일관된 출시 입력은 저장된 깨끗한 checkout에서 확보한다.

등록 잠금은 생성/회수/게시를 직렬화하고, 작업 잠금은 Godot가 실행되는 별도 보호
프로세스에도 상속한다. CLI만 강제 종료되어도 살아 있는 Godot 작업은 회수하지 않는다.
정상 종료·오류·SIGINT/SIGTERM/SIGHUP은 자식을 종료/회수한 뒤 자기 작업을 정리한다.
SIGKILL/전원 차단 뒤에는 다음 build/clean이 소유 표식과 비차단 파일 잠금으로 회수한다.
알 수 없는 경로·symlink·삭제 실패는 경고와 남은 경로를 출력한다. 로컬 파일시스템을
전제로 한다. 잠금/rename 의미가 다른 네트워크 공유에서는 사용하지 않는다.

완성된 결과물을 검사하고 SHA-256 manifest를 기록·flush한 다음 같은 파일시스템에서
디렉토리를 rename하고 `latest-<target>.json`을 원자적으로 교체한다. 실패하면 기존
포인터가 유지된다. 소비자는 이 포인터의 `path`에서 결과물을 읽는다. 기존 프리셋의
`builds/macos`, `builds/windows` 수동 출력은 도구가 소유하거나 삭제하지 않는다.
GUI Export는 wrapper를 거치지 않으므로 자동 정리가 적용되지 않는다. 반복 빌드와
배포 준비는 위 명령을 사용하고 GUI 수동 예외는 아래 표에 기록한다.

## 보관 정책

| 대상 | 위치 / 정책 |
|---|---|
| 개발 성공 패키지 | `.managed/dev/<target>/`, 대상별 최근 2회. PC 앱·EXE·PCK 검증 결과를 서로 밀어내지 않도록 분리 |
| 빌드 원문 로그 | `.managed/logs/`, 모든 대상 합계 최근 10회, 파일당 마지막 1MiB. 초과 시 앞부분을 버림 |
| 출시·롤백·패치 기준 | `.managed/releases/` 또는 기존 외부 보관소. 자동 개수·기간 삭제 없음 |
| 크래시 심볼·매핑 | 출시 패키지 안에서는 그대로 유지. 개발/실패 작업의 `.pdb`, `.dSYM`, `.sym`, `.map`, `.debug`, `mapping.txt`는 `.managed/symbols/`로 보존, 자동 삭제 없음 |
| 기존 검증 기록 | `.godot`의 녹화 PNG/WAV/원문 로그. 기존 보존 목적 확인 전 유지, 새 빌드 로그 제한을 소급 적용하지 않음 |
| 의존성 | 설치된 Godot/export templates, 공용 엔진 캐시 보존. 현재 프로젝트 규모에서는 별도 TTL/용량 제한 불필요 |
| 원본·설정·키·저장 데이터 | 자동 정리 대상 아님. 게임 실행을 통한 저장 변경 없이 packed resource load로 빌드 검증 |

새 도구가 다른 형식의 심볼/패치 자료를 생성하면 해당 형식의 보존 처리를 먼저
추가해야 한다. 출시 보관본은 별도 백업·배포/롤백 절차로 관리한다.

## CI

`.github/workflows/build.yml`: push/PR에서 작은 수명주기 테스트를 실행한다.
수동 workflow_dispatch는 `self-hosted, macOS, godot-4.7.2` 라벨의 호스트에서 실제
패키징하고 `always()` 단계에서 정리한다. 해당 러너와 일치하는 템플릿 설치는 CI
관리자가 준비해야 한다. checkout은 `clean: false`로 기존 ignored 배포본을 보호한다.
영속 checkout에서 로컬과 같은 최근 2회/로그 10회 규칙을 적용하며, 원격 artifact를
중복 업로드하지 않는다. CI 콘솔 메타로그 보존 기간은 GitHub 저장소 설정을 따른다.
이 작업에서는 원격 CI를 실행하거나 러너·저장소 설정을 변경하지 않았다.

## 보존 예외 / 확인 대기

| 목적 | 위치 | 책임 / 삭제·검토 시점 |
|---|---|---|
| 기존 UI/비교/녹화 검증 근거 | `.godot/item-*` PNG/WAV 및 기존 `.godot/*.log` | 프로젝트 담당자, 다음 시각 회귀검증 때 검토 후 결정 |
| 이번 정리 감사·검증 근거 | `docs/storage-audit/` | 프로젝트 담당자, 정리 변경 검토 기록과 함께 보존 |

날짜/번호별 패키지·압축 해제 사본의 무기한 복제는 금지한다. 디버깅 예외를 추가할
때 목적·정확한 경로·담당자·삭제/검토 기한을 위 표에 기록한다.

참고: [Godot CLI](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html),
[Godot 캐시 설명](https://docs.godotengine.org/en/stable/tutorials/best_practices/version_control_systems.html),
[GitHub workflow 문법](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax).
실제 설치된 엔진의 `godot --help`와 export/import 동작도 확인했다.
