# 원본 30종 실측표

단위 m. W=Godot X, D=Godot Z, H=Godot Y. 원본 부지 1칸=4m. 수력의 null 부지는 고정 15×8로 바꾸지 않았다.

| ID | 이름 | 분류 | 원본 부지(칸) | W × D × H (m) | 출입구 근거 노드 |
|---|---|---|---|---|---|
| large-4x4-department-07 | AUREL 백화점 | commercial | [4, 4] | 16.000 × 16.000 × 27.270 | DoorDivision |
| large-4x4-office-nova-08 | NOVA 오피스 타워 | commercial | [4, 4] | 16.000 × 16.000 × 30.850 | DoorDivision |
| large-8x8-grand-department-09 | AUREL GRAND 대형 백화점 | commercial | [8, 8] | 32.000 × 32.000 × 30.220 | DoorSplit |
| large-8x8-twin-central-10 | NOVA CENTRAL 트윈 복합타워 | commercial | [8, 8] | 32.000 × 32.000 × 45.270 | DoorSplit |
| medium-4x4-brick-services-06 | 벽돌형 식당·서비스 상가 | commercial | [4, 4] | 16.000 × 16.000 × 13.870 | ShopDoor |
| medium-4x4-office-retail-05 | 업무·상가 복합빌딩 | commercial | [4, 4] | 16.000 × 16.000 × 13.400 | DoorSplit |
| small-2x2-auto-02 | 자동차 전시장 AUTO | commercial | [2, 2] | 8.000 × 8.000 × 4.445 | Door |
| small-2x2-mart-01 | 동네 MART | commercial | [2, 2] | 8.000 × 8.000 × 5.190 | DoorCenterBar |
| small-4x4-cafe-diner-04 | 식당·카페 복합상가 | commercial | [4, 4] | 16.000 × 16.000 × 7.320 | ShopDoor |
| small-4x4-market-03 | 동네 슈퍼마켓 | commercial | [4, 4] | 16.000 × 16.000 × 5.770 | DoorSplit |
| large-4x4-chemical-06 | 화학 생산시설 | industrial | [4, 4] | 16.000 × 16.000 × 10.260 | StaffDoorGlass |
| large-4x4-pharma-05 | 제약 생산시설 | industrial | [4, 4] | 16.000 × 16.000 × 15.495 | DoorSplit |
| large-8x8-auto-assembly-07 | 자동차 조립공장 | industrial | [8, 8] | 32.000 × 32.000 × 11.420 | DoorSplit |
| large-8x8-chemical-complex-08 | 대규모 화학 플랜트 | industrial | [8, 8] | 32.000 × 32.000 × 17.710 | DoorSplit |
| medium-4x4-circuitworks-04 | 전자부품 공장 | industrial | [4, 4] | 16.000 × 16.000 × 11.930 | DoorSplit |
| medium-4x4-precision-03 | 정밀기계 공장 | industrial | [4, 4] | 16.000 × 16.000 × 7.770 | StaffDoorGlass |
| small-2x2-foodworks-02 | 식품가공 작업장 | industrial | [2, 2] | 8.000 × 8.000 × 5.170 | DoorSplit |
| small-2x2-metalworks-01 | 금속가공 작업장 | industrial | [2, 2] | 8.000 × 8.000 × 5.180 | WorkerDoor |
| power-coal | 석탄발전소 | power | [8, 8] | 32.000 × 32.000 × 31.300 | NOT VERIFIED: no named human entrance |
| power-hydro | 수력발전댐 | power | null (parametric; presentation only) | 60.000 × 32.000 × 9.770 | NOT VERIFIED: no named human entrance |
| power-nuclear | 원자력발전소 | power | [8, 8] | 32.000 × 32.000 × 20.551 | NOT VERIFIED: no named human entrance |
| power-oil | 석유발전소 | power | [8, 8] | 32.000 × 32.000 × 25.470 | NOT VERIFIED: no named human entrance |
| power-solar | 태양광발전소 | power | [4, 4] | 16.000 × 16.000 × 1.280 | NOT VERIFIED: no named human entrance |
| power-wind | 풍력발전소 | power | [4, 4] | 19.053 × 4.887 × 37.400 | NOT VERIFIED: no named human entrance |
| water-intake | 취수장 | water | [4, 4] | 16.000 × 16.000 × 6.490 | StaffDoor |
| water-sewage-outfall | 하수장 | water | [4, 4] | 16.000 × 16.000 × 5.440 | StaffDoor |
| water-sewage-treatment | 하수처리장 | water | [8, 8] | 32.000 × 32.000 × 4.360 | StaffDoor |
| water-water-tower | 급수탑 | water | [2, 2] | 8.000 × 8.000 × 13.740 | NOT VERIFIED: no named human entrance |
| waste-incinerator | 쓰레기 소각장 | waste | [8, 8] | 32.000 × 32.000 × 22.808 | StaffDoor |
| waste-recycling-center | 재활용센터 | waste | [8, 8] | 32.000 × 32.000 × 7.560 | StaffDoor |

## 예외 / 보존 사항

- `power-coal`: original_below_ground_geometry_preserved; no_named_human_entrance_in_original; +Z_is_inspection_convention_only
- `power-hydro`: parametric_asset_no_fixed_footprint; dimensions_are_original_presentation_only; no_named_human_entrance_in_original; +Z_is_inspection_convention_only
- `power-nuclear`: no_named_human_entrance_in_original; +Z_is_inspection_convention_only
- `power-oil`: no_named_human_entrance_in_original; +Z_is_inspection_convention_only
- `power-solar`: no_named_human_entrance_in_original; +Z_is_inspection_convention_only
- `power-wind`: rotor_overhang_ground_occupation_only; no_named_human_entrance_in_original; +Z_is_inspection_convention_only
- `water-intake`: original_below_ground_geometry_preserved
- `water-sewage-outfall`: original_below_ground_geometry_preserved
- `water-water-tower`: no_named_human_entrance_in_original; +Z_is_inspection_convention_only
