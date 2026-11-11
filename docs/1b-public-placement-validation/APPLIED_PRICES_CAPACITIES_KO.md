# 1B 임시 승인 적용 가격·용량

단일 편집 원본: docs/economy-balance/ECONOMY_BALANCE.csv. 월=게임 하루. 가격은 기존 제안값 그대로, 용량은 CAPACITY_PROPOSALS_KO에서 임시 승인 2026-11-11로 전사했다.

| ID / 시설 | 부지 | 건설 doth | 유지 doth/월 | 연결 | CSV 용량 데이터(단위) |
|---|---|---:|---:|---|---|
| `crematorium-4x4` / 화장터 | 4×4 | 12000 | 180 | none | storage=20 구; rated_throughput=12 구/게임일; average_throughput=6 구/게임일; own_power_kw=35 kW |
| `elementary-school` / 초등학교 | 4×4 | 5000 | 80 | none | students=240 명; own_power_kw=10 kW |
| `high-school` / 고등학교 | 4×4 | 9000 | 140 | none | students=480 명; own_power_kw=18 kW |
| `technical-college` / 전문대 | 8×8 | 25000 | 350 | none | students=800 명; own_power_kw=40 kW |
| `university` / 대학교 | 8×8 | 60000 | 800 | none | students=2400 명; own_power_kw=100 kW |
| `medical-clinic` / 진료소 | 4×4 | 6000 | 100 | none | outpatient_day=30 명/게임일; beds=0 병상; own_power_kw=10 kW |
| `medical-hospital` / 병원 | 6×6 | 25000 | 400 | none | outpatient_day=150 명/게임일; beds=80 병상; own_power_kw=50 kW |
| `medical-large-hospital` / 대형병원 | 8×8 | 65000 | 900 | none | outpatient_day=400 명/게임일; beds=240 병상; own_power_kw=130 kW |
| `small-fire-station` / 소형소방서 | 4×4 | 8000 | 120 | none | vehicle_bays=2 대; simultaneous_incidents=1 건; own_power_kw=8 kW |
| `fire-station` / 소방서 | 6×6 | 20000 | 300 | none | vehicle_bays=6 대; simultaneous_incidents=3 건; own_power_kw=20 kW |
| `regional-fire-station` / 광역소방서 | 8×8 | 50000 | 700 | none | vehicle_bays=16 대; simultaneous_incidents=8 건; own_power_kw=45 kW |
| `small-police-station` / 파출소 | 4×4 | 6000 | 100 | none | vehicle_bays=2 대; population_capacity=1000 명; own_power_kw=5 kW |
| `police-station` / 경찰서 | 6×6 | 18000 | 250 | none | vehicle_bays=6 대; population_capacity=5000 명; own_power_kw=15 kW |
| `regional-police-station` / 경찰본부 | 8×8 | 45000 | 600 | none | vehicle_bays=16 대; population_capacity=15000 명; own_power_kw=40 kW |
| `prison-8x8` / 교도소 | 8×8 | 45000 | 500 | none | inmates=300 명; own_power_kw=50 kW |
| `power-coal` / 석탄발전소 | 8×8 | 35000 | 600 | power | rated_output_kw=8000 kW; average_output_kw=8000 kW |
| `power-nuclear` / 원자력발전소 | 8×8 | 200000 | 2500 | power | rated_output_kw=80000 kW; average_output_kw=80000 kW |
| `power-oil` / 석유발전소 | 8×8 | 60000 | 1000 | power | rated_output_kw=16000 kW; average_output_kw=16000 kW |
| `power-solar` / 태양광발전소 | 4×4 | 12000 | 50 | power | rated_output_kw=1800 kW; average_output_kw=450 kW |
| `power-wind` / 풍력발전소 | 4×4 | 15000 | 200 | power | rated_output_kw=2000 kW; average_output_kw=1000 kW |
| `water-intake` / 취수장 | 4×4 | 8000 | 120 | water | supply_m3_day=1000 m³/게임일; own_power_kw=20 kW |
| `water-sewage-outfall` / 하수장 | 4×4 | 6000 | 100 | sewage | sewage_m3_day=800 m³/게임일; own_power_kw=8 kW |
| `water-sewage-treatment` / 하수처리장 | 8×8 | 18000 | 250 | sewage | sewage_m3_day=2400 m³/게임일; pollutant_removal_percent=95 %; own_power_kw=60 kW |
| `water-water-tower` / 급수탑 | 2×2 | 4000 | 40 | none | storage_m3=1000 m³; inflow_m3_day=500 m³/게임일; outflow_m3_day=500 m³/게임일; own_power_kw=2 kW |
| `waste-incinerator` / 쓰레기 소각장 | 8×8 | 25000 | 350 | none | throughput_t_day=20 톤/게임일; rated_generation_kw=200 kW; residue_percent=15 % |
| `waste-recycling-center` / 재활용센터 | 8×8 | 12000 | 150 | none | throughput_t_day=8 톤/게임일; recovery_percent=60 %; residue_percent=40 %; own_power_kw=25 kW |
| `park-pocket-2x2` / 쉼터 공원 | 2×2 | 300 | 5 | none | visitors=12 명; own_power_kw=0.2 kW |
| `park-garden-2x2` / 꽃정원 공원 | 2×2 | 450 | 8 | none | visitors=20 명; own_power_kw=0.3 kW |
| `park-plaza-4x4` / 분수 광장 공원 | 4×4 | 1500 | 25 | none | visitors=80 명; own_power_kw=2 kW |
| `park-play-4x4` / 놀이터 공원 | 4×4 | 1200 | 20 | none | visitors=60 명; own_power_kw=0.5 kW |
| `parking-small-2x4` / 소형 주차장 | 2×4 | 800 | 8 | none | vehicles=4 대; own_power_kw=0.2 kW |
| `parking-medium-4x4` / 중형 주차장 | 4×4 | 1600 | 16 | none | vehicles=8 대; own_power_kw=0.4 kW |
| `parking-large-4x8` / 대형 주차장 | 4×8 | 3200 | 32 | none | vehicles=16 대; own_power_kw=0.8 kW |
| `parking-tower-4x4-4f` / 4층 주차타워 | 4×4 | 16000 | 160 | none | vehicles=16 대; own_power_kw=4 kW |

power는 average_output_kw만 실제 순출력으로 사용한다(rated는 등록값). water는 supply_m3_day, sewage는 sewage_m3_day를 기존 엔진에 연결한다.
그 외 용량·자체 부하·오염 제거율은 데이터 등록만이며 서비스 효과/저장/쓰레기 처리 엔진을 만들지 않았다. 소각 발전은0, 급수탑 생산은0이다.
기존 service.* 용량 제안은 역사 기록이며 1B의 현재 용량 키는 public.<ID>.capacity.* 이다. 공공차량 구입/연료·민간 정원·도로/관로 가격은 이번에 적용하지 않는다.
