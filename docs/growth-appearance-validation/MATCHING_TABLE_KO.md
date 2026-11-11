# 성장 외관 전체 매칭 표 — 승인된 부지 규칙 적용

1·2 small, 3·4 medium, 5 large. 신규8×8은5단계 전용. 8×8의 small/medium 6밀도셀(12단계행)은 **도달 불가**이며 기존 저장 데이터에서만 large 외관을 보존한다.

| 용도 | 부지 | 단계 | 도달 가능성 | 요청 → 실제 외관 밀도 | 후보 ID |
|---|---|---:|---|---|---|
| residential | 2×2 | 1 | 가능 | small → small | `small-2x2-a`, `small-2x2-b` |
| residential | 2×2 | 2 | 가능 | small → small | `small-2x2-a`, `small-2x2-b` |
| residential | 2×2 | 3 | 가능 | medium → medium | `medium-2x2-multiplex-01`, `medium-2x2-corner-villa-02` |
| residential | 2×2 | 4 | 가능 | medium → medium | `medium-2x2-multiplex-01`, `medium-2x2-corner-villa-02` |
| residential | 2×2 | 5 | 가능 | large → large | `large-2x2-slim-tower-01`, `large-2x2-pencil-tower-02` |
| residential | 4×4 | 1 | 가능 | small → small | `small-4x4-a`, `small-4x4-b` |
| residential | 4×4 | 2 | 가능 | small → small | `small-4x4-a`, `small-4x4-b` |
| residential | 4×4 | 3 | 가능 | medium → medium | `mansion-a-4x4-4f`, `mansion-b-4x4-4f` |
| residential | 4×4 | 4 | 가능 | medium → medium | `mansion-a-4x4-4f`, `mansion-b-4x4-4f` |
| residential | 4×4 | 5 | 가능 | large → large | `large-4x4-a`, `large-4x4-b` |
| residential | 8×8 | 1 | **도달 불가** · 기존 저장 large 유지 | small → large | `large-8x8-a`, `large-8x8-b` |
| residential | 8×8 | 2 | **도달 불가** · 기존 저장 large 유지 | small → large | `large-8x8-a`, `large-8x8-b` |
| residential | 8×8 | 3 | **도달 불가** · 기존 저장 large 유지 | medium → large | `large-8x8-a`, `large-8x8-b` |
| residential | 8×8 | 4 | **도달 불가** · 기존 저장 large 유지 | medium → large | `large-8x8-a`, `large-8x8-b` |
| residential | 8×8 | 5 | 가능 | large → large | `large-8x8-a`, `large-8x8-b` |
| commercial | 2×2 | 1 | 가능 | small → small | `small-2x2-auto-02`, `small-2x2-mart-01` |
| commercial | 2×2 | 2 | 가능 | small → small | `small-2x2-auto-02`, `small-2x2-mart-01` |
| commercial | 2×2 | 3 | 가능 | medium → medium | `medium-2x2-neighborhood-01`, `medium-2x2-cafe-building-02` |
| commercial | 2×2 | 4 | 가능 | medium → medium | `medium-2x2-neighborhood-01`, `medium-2x2-cafe-building-02` |
| commercial | 2×2 | 5 | 가능 | large → large | `large-2x2-slim-office-01`, `large-2x2-boutique-hotel-02` |
| commercial | 4×4 | 1 | 가능 | small → small | `small-4x4-cafe-diner-04`, `small-4x4-market-03` |
| commercial | 4×4 | 2 | 가능 | small → small | `small-4x4-cafe-diner-04`, `small-4x4-market-03` |
| commercial | 4×4 | 3 | 가능 | medium → medium | `medium-4x4-brick-services-06`, `medium-4x4-office-retail-05` |
| commercial | 4×4 | 4 | 가능 | medium → medium | `medium-4x4-brick-services-06`, `medium-4x4-office-retail-05` |
| commercial | 4×4 | 5 | 가능 | large → large | `large-4x4-department-07`, `large-4x4-office-nova-08` |
| commercial | 8×8 | 1 | **도달 불가** · 기존 저장 large 유지 | small → large | `large-8x8-grand-department-09`, `large-8x8-twin-central-10` |
| commercial | 8×8 | 2 | **도달 불가** · 기존 저장 large 유지 | small → large | `large-8x8-grand-department-09`, `large-8x8-twin-central-10` |
| commercial | 8×8 | 3 | **도달 불가** · 기존 저장 large 유지 | medium → large | `large-8x8-grand-department-09`, `large-8x8-twin-central-10` |
| commercial | 8×8 | 4 | **도달 불가** · 기존 저장 large 유지 | medium → large | `large-8x8-grand-department-09`, `large-8x8-twin-central-10` |
| commercial | 8×8 | 5 | 가능 | large → large | `large-8x8-grand-department-09`, `large-8x8-twin-central-10` |
| industrial | 2×2 | 1 | 가능 | small → small | `small-2x2-foodworks-02`, `small-2x2-metalworks-01` |
| industrial | 2×2 | 2 | 가능 | small → small | `small-2x2-foodworks-02`, `small-2x2-metalworks-01` |
| industrial | 2×2 | 3 | 가능 | medium → medium | `medium-2x2-bakery-01`, `medium-2x2-electronics-02` |
| industrial | 2×2 | 4 | 가능 | medium → medium | `medium-2x2-bakery-01`, `medium-2x2-electronics-02` |
| industrial | 2×2 | 5 | 가능 | large → large | `large-2x2-grain-silo-01`, `large-2x2-distillation-02` |
| industrial | 4×4 | 1 | 가능 | small → small | `small-4x4-logistics-01`, `small-4x4-metalshop-02` |
| industrial | 4×4 | 2 | 가능 | small → small | `small-4x4-logistics-01`, `small-4x4-metalshop-02` |
| industrial | 4×4 | 3 | 가능 | medium → medium | `medium-4x4-circuitworks-04`, `medium-4x4-precision-03` |
| industrial | 4×4 | 4 | 가능 | medium → medium | `medium-4x4-circuitworks-04`, `medium-4x4-precision-03` |
| industrial | 4×4 | 5 | 가능 | large → large | `large-4x4-chemical-06`, `large-4x4-pharma-05` |
| industrial | 8×8 | 1 | **도달 불가** · 기존 저장 large 유지 | small → large | `large-8x8-auto-assembly-07`, `large-8x8-chemical-complex-08` |
| industrial | 8×8 | 2 | **도달 불가** · 기존 저장 large 유지 | small → large | `large-8x8-auto-assembly-07`, `large-8x8-chemical-complex-08` |
| industrial | 8×8 | 3 | **도달 불가** · 기존 저장 large 유지 | medium → large | `large-8x8-auto-assembly-07`, `large-8x8-chemical-complex-08` |
| industrial | 8×8 | 4 | **도달 불가** · 기존 저장 large 유지 | medium → large | `large-8x8-auto-assembly-07`, `large-8x8-chemical-complex-08` |
| industrial | 8×8 | 5 | 가능 | large → large | `large-8x8-auto-assembly-07`, `large-8x8-chemical-complex-08` |
