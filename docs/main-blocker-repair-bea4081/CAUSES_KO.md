# main 병합 차단 3건 원인·조치

모두 (a): 승인된 정책에 맞지 않는 과거 테스트/검토용 fixture였다. 게임 규칙·원본 애셋·경제값은 변경하지 않았다.

- `test_bottom_ui`: J에서 8×8 검토 부지를 위한 맞은편 도로 2개가 추가돼 실제 8개였다. 이전 6개 기대값을 8개로 갱신했다.
- `test_recovered_assets`: fixture 잔액 50,000에 비해 대학 60,000·대형병원 65,000으로 정상적인 구매 거절이었다. 성공 경로 fixture의 잔액을 실제 선택 대상 가격 최댓값으로 확보하고, 일시정지 및 선택 전후 자금 불변 검사로 고정했다. 자금 부족 거절 규칙은 유지했다.
- `test_showcase`: 기존 단일 도로는 대형 부지의 4+4 조건을 만족하지 못했다. 원본 건물 좌표·배치를 유지하며 두 8×8 부지 뒤에 실제 접도 도로를 추가했고, 테스트도 맞은편 구획 성립을 검사한다.

수정 전 RED 근거: `../main-money-ui-integration-bea4081/results-aggregate.json`.
원인 분리 실측: `root-cause-probe.log`.
수정 후 해당 3개 검사: `focused/results-selected.json` (3/3; bottom UI 43/43, recovered assets 59/59, showcase 28/28).
전체 회귀 및 원본 보존 확인은 수정 커밋 이후 별도 실행한다.
