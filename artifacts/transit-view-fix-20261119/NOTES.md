# test_transit_view 지하철 미리보기·확정 불일치 (2026-11-19, cities-claude)

## 원인
- 제품 버그가 아니다. 테스트가 누른 두 번째 지하철 클릭이 지도에 닿지 않았다.
- (60,75)를 깊이 −12.7m로 투영하면 화면 (685, 821.6)이다. 이 점이 넓어진 교통 트레이(BottomDrawer, y 750–870) 카드 위에 있다.
- GUI가 클릭을 먼저 받아 도구가 바뀌고 지하철 획이 취소된다. 그래서 아무것도 지어지지 않는다.
  - d5bdad5에서는 Tool_rail, HEAD에서는 Tool_transit_line이 클릭을 받는다.
- 검사는 transit_routes[-1]을 보는데, 이것은 앞서 만든 지하철 fixture (10,75)–(30,75)다. 그래서 미리보기 (40,75)–(60,75)와 다르게 나왔다.
- 클릭이 지도에 닿으면 확정 points는 미리보기 points와 정확히 같다. HUD 위에서는 미리보기를 그리지 않으므로 사용자가 보는 미리보기와 확정 결과는 어긋나지 않는다.

## 원인 커밋
- d5bdad5(P2 역·정류장 배치)가 교통 트레이에 시설 카드 4개를 더했다. 트레이 폭이 1110px(x 405–1515)로 넓어지면서 클릭 위치를 덮게 됐다.
- 임시 worktree에서 확인한 결과: 7a68f0a는 35/35, d5bdad5는 34/35(같은 검사 1건 실패)다.
- 94cac6b가 노선 도구 카드 3개를 더해 트레이가 1545px이 됐다. 같은 점을 덮는 카드만 Tool_transit_line으로 바뀌었다.
- P5(87bc12e)·E1(bb6ca4c)·E2(f72368e)와는 관계없다.

## 고친 내용
- 테스트만 고쳤다(`cities_do/tests/test_transit_view.gd`, TEST DRIFT 주석 포함).
- 지하철 두 클릭 전에 카메라를 화면 위쪽으로 200px 옮기고, 검사 후 원래 위치로 되돌린다.
- 기대값(확정 points == 미리보기 points)은 그대로 두었다. 제품 코드는 바꾸지 않았다.

## 테스트 (이 폴더의 로그)
- 대상: test_transit_view 35/35, test_transit_routes 23/23, test_transit_geometry 227/227
- 대상: test_transit_render 28/28, test_terminal_turnback 65/65, test_underground_roads 90/90

## 남은 것
- 임시 worktree `D:/project/simcity-tvfix-bisect`(detached d5bdad5, .godot 복사본과 미추적 .import 87개 포함)를 남겨 두었다. 지우려면 승인이 필요하다.
