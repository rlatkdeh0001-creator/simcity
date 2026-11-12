# 이웃 연결 노면 표시 — F

`core/boundary_links.gd`는 기존 RegionalExchange의 유효한 맵 끝점 판정을 재사용한다. 실제 경계 종단의 도로 진행 방향으로 흰색(알파0.76) 양방향 화살표 두 개를 노면 안쪽에 그린다. 새 글자/설명/버튼은 없다. 단순 경계 평행 접촉·모호한 모서리·내부 도로는 표시하지 않는다.

전력은 PowerGrid, 상하수관은 실제 paired geometry의 이웃 포트에 연결된 그래프 간선이 있을 때만 같은 아이콘을 그린다. 각각 기존 power/water overlay의 tab_open 뒤에서 그리므로 탭 변경·닫기·ESC·불도저의 숨김 정책을 그대로 따른다. 상하수는 한 쌍의 접속을 한 아이콘으로 표시한다. 기존 포트 이름/연결 도구는 유지했으며 거래/공급/요금/계량 규칙은 바꾸지 않았다.

끝 cap 원인은 기존 END_ROUND ribbon이 맵 경계로 잘리지 않았던 것이다. main.gd의 노면·보도 ribbon과 차선 offset dash를 world bounds로 잘라 가장자리에서 평평하게 끝낸다. 내부 막다른 길의 기존 둥근 끝과 도로 원본·교통 그래프는 유지한다.

검증: `test_boundary_links` **49/49**, 관련 **8/8** (도로 이음/구획/지역 교류/전력/상하수/탭 가시성/철거). 실제1920 캡처 `boundary-links-validation/neighbor-arrows-1920.png`는 전력 탭에서 도로+전력 연결을 함께 보여준다. native script는 실제 power/water 카테고리 클릭, 각 화살표 흰 픽셀8개, 닫은 뒤0개, 도로 화살표 상시 표시, 경계 바깥 노면 없음과 양수 공급 상태 불변을 검사한다. native state/log 보존. 전체 회귀/내보내기는 미실행.
