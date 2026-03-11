# iOS Warning Gate

## 목적
- 배포 품질에 영향을 주는 경고를 조기에 차단합니다.
- 앱 소스 경고(`NailClient/NailClient/`)는 baseline 비교로 관리합니다.
- 도구성 경고 중 AppIntents 미사용 프로젝트에서 발생하는 메시지는 정보성으로 허용합니다.

## 실행
- 기본 검사:
```bash
bash scripts/ios-warning-gate.sh
```

- baseline 갱신(경고 정리 후 1회):
```bash
bash scripts/ios-warning-gate.sh --update-baseline
```

- baseline 파일은 수동 편집하지 않고 위 스크립트 실행 결과만 반영합니다.

## 정책
- `Release(clean build)` + `Debug(simulator build)`를 모두 검사합니다.
- 앱 소스 신규 경고가 baseline 대비 추가되면 실패합니다.
- 앱 소스 경고가 0개이면 `NailClient/warning-baseline.txt`가 빈 파일인 상태가 정상입니다.
- 현재 허용된 도구성 경고:
  - `Metadata extraction skipped. No AppIntents.framework dependency found.`
  - `'UIRequiresFullScreen' has been deprecated ...`

## 파일
- baseline: `NailClient/warning-baseline.txt`
- gate script: `scripts/ios-warning-gate.sh`
