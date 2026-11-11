"""Assemble actual Blender renders into labelled review sheets; no generated imagery."""
from pathlib import Path
import json,ast,csv,hashlib,shutil
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'docs/growth-14'
node=ast.parse((ROOT/'tools/build_growth_14.py').read_text());fleet=next(ast.literal_eval(n.value) for n in node.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='FLEET' for t in n.targets))
font_path='/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc'
def font(n):return ImageFont.truetype(font_path,n)
entries=[];images=[]
for index,(zone,ident,label,density,n,floors,style) in enumerate(fleet,1):
 folder=ROOT/f'assets/{zone}-growth'/ident;d=json.loads((folder/'metadata.json').read_text());assert not d['game_registered']
 with Image.open(folder/'building.png') as im:
  im.load();assert im.size==(900,1100) and im.mode=='RGBA';a=im.getchannel('A');box=a.getbbox();assert box and box[0]>0 and box[1]>0 and box[2]<900 and box[3]<1100
  images.append({'id':ident,'alpha_bbox_px':list(box),'png_sha256':hashlib.sha256((folder/'building.png').read_bytes()).hexdigest()})
 d['review_number']=index;d['source_folder']=str(folder.relative_to(ROOT));entries.append(d)
for zone in ['residential','commercial','industrial']:
 group=[e for e in entries if e['zone']==zone];cols=2 if len(group)==4 else 3;cw=700;ch=920;sheet=Image.new('RGB',(cols*cw,120+2*ch),(24,43,48));draw=ImageDraw.Draw(sheet)
 title={'residential':'주거 4종','commercial':'상업 4종','industrial':'공업 6종'}[zone]
 draw.text((24,14),'CITIES_DO · '+title+' · 승인 대기',font=font(34),fill='#eef1df');draw.text((24,65),'카드별 자동 확대 / 실측은 아래 m 표기 / 기존 Blender 원본과 같은 구도',font=font(21),fill='#bacac4')
 for i,e in enumerate(group):
  x=(i%cols)*cw+14;y=120+(i//cols)*ch;draw.rounded_rectangle((x,y,x+cw-28,y+ch-16),radius=10,fill='#263f46')
  draw.text((x+16,y+13),f"{e['review_number']:02d}  {e['name']}",font=font(26),fill='#f1e8cd')
  im=Image.open(ROOT/e['source_folder']/'building.png');im.thumbnail((cw-60,740),Image.Resampling.LANCZOS);bg=Image.new('RGBA',(cw-52,746),'#b9c5b3');bg.alpha_composite(im,((bg.width-im.width)//2,(bg.height-im.height)//2));sheet.paste(bg.convert('RGB'),(x+12,y+61))
  w,d,h=e['measured_dimensions_m'];floors=e['floors'];floor_text=f'{floors}층' if floors else '설비형 · 거주층 없음'
  draw.text((x+16,y+822),f"{e['footprint_cells'][0]}×{e['footprint_cells'][1]}칸 · {w:.2f}×{d:.2f}×{h:.2f}m · {floor_text}",font=font(22),fill='#e5eadd')
  draw.text((x+16,y+864),e['id'],font=font(17),fill='#b5cbc9')
 sheet.save(OUT/(zone+'-review.png'))
(OUT/'catalog.json').write_text(json.dumps({'count':14,'game_registered':False,'assets':entries},ensure_ascii=False,indent=2)+'\n')
(OUT/'image-validation.json').write_text(json.dumps(images,indent=2)+'\n')
lines=['# 성장 건물 애셋 14종 · 검토 대기','', '**애셋 전용 브랜치 `assets/growth-14-20261111`. 게임 적용·성장 카탈로그 등록·main 병합 없음.**','사용자 수정: 소형·중형8×8 12종을 제외. 8×8은 성장5단계 최종 테크 전용이며 기존 대형8×8은 유지한다.','남은 주거4·상업4·공업6만 제작했다. 밀도와 필지 크기는 별개로 유지한다.','', '## 제작 방식','', '직접 작성 Blender 지오메트리, 시스템 DejaVu 폰트만 사용했다. 외부 모델/텍스처/생성형 이미지 없음.','Blender -Y 정면/+Z 위, Godot/glTF +Z 정면. metadata의 front는 Godot 기준, front_blender를 별도 표기한다.','기존 층고3.05m·바닥판 -0.12~+0.12m·상면0.12m·기존 저채도 팔레트·30도 정투영/방위각-45도 구도를 유지한다.','산업 설비의 층수0은 사일로·증류탑에 거주층이 없다는 뜻이다. 높이와 층수를 혼동하지 않는다.','원본 id.blend, building.png(900×1100 RGBA), metadata.json. 카드별 확대를 달리했으므로 아래 실측으로 비교한다.','', '## 시안','', '![주거](residential-review.png)','![상업](commercial-review.png)','![공업](industrial-review.png)','', '| 번호 | 이름 | 밀도 | 부지 | 실측 W×D×H(m) | 층수 | 원본·개별 이미지 |','|---|---|---|---|---|---|---|']
for e in entries:
 w,d,h=e['measured_dimensions_m'];lines.append(f"| {e['review_number']:02d} | {e['name']} | {e['density']} | {e['footprint_cells'][0]}×{e['footprint_cells'][1]} | {w:.2f}×{d:.2f}×{h:.2f} | {e['floors']} | [파일](../../{e['source_folder']}) · [PNG](../../{e['source_folder']}/building.png) |")
lines+=['','## 재현·검증','', '`blender -b --factory-startup -t 6 -P tools/build_growth_14.py` (선택 `-- --only ID`).','`blender -b --factory-startup -t 2 -P tools/verify_growth_14.py` 후 `python tools/build_growth_14_review.py`.','geometry-validation.json: 14개 원본을 다시 열어 평가된 메시/폰트 전체 부지 경계·실측·정면·층수·카메라를 확인한다.','image-validation.json: PNG 크기/알파/프레임 잘림과 SHA-256. 실제 렌더링과 기하 검사는 별도다.','새 게임 기능·경제 적용·실내·LOD·충돌·구조공학 검증은 하지 않았다. 승인 전 game_registered=false를 유지한다.','[가격·용량 제안](BALANCE_PROPOSALS_KO.md)은 미적용이다. 모델을 만들었다고 이 값을 승인된 경제로 쓰지 않는다.','']
(OUT/'README_KO.md').write_text('\n'.join(lines))
for zone in ['residential','commercial','industrial']:
 dest=ROOT/f'assets/{zone}-growth';shutil.copyfile(ROOT/'assets/commercial-study/FONT_LICENSE.txt',dest/'FONT_LICENSE.txt')
print('Review sheets, 14-image checks and source index written.')
