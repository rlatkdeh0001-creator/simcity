"""Standalone visual concept checks and reproducible GIF capture; no game integration.
Run via webapp-testing with_server.py at http://127.0.0.1:8768/preview.html.
"""
from pathlib import Path
import json,io
from PIL import Image,ImageChops
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'docs/concepts/underground-power-v2'
results=[]
def check(value,label):
 results.append({'check':label,'passed':bool(value)})
 if not value:raise AssertionError(label)
with sync_playwright() as p:
 browser=p.chromium.launch(headless=True,executable_path='/usr/bin/chromium',args=['--no-sandbox'])
 page=browser.new_page(viewport={'width':1440,'height':980},device_scale_factor=1)
 errors=[];page.on('pageerror',lambda error:errors.append(str(error)))
 page.goto('http://127.0.0.1:8768/preview.html');page.wait_for_load_state('networkidle')
 check(page.locator('h1').inner_text()=='CITIES_DO · 지중 전력 흐름','concept loads with expected title')
 data=page.evaluate('''()=>{const a=preview;const early=a.pulseStates(3.99,'domestic'),late=a.pulseStates(4.01,'domestic');const e1=a.pulseStates(4,'export').find(x=>x.emission===2),e2=a.pulseStates(5,'export').find(x=>x.emission===2);const i1=a.pulseStates(.1,'import')[0],i2=a.pulseStates(.5,'import')[0];return {radius:a.radius,spacing:a.spacing,intervals:a.routes.export[2].points,domesticOnly:early.every(x=>x.route.startsWith('home-')),arrives:early.some(x=>x.emission===0)&&!late.some(x=>x.emission===0),exportForward:e2.point[0]>e1.point[0],importReverse:i2.point[0]<i1.point[0],within:early.every(x=>x.age>=0&&x.age<x.life),nodeSpacing:a.nodes.every(([x,y])=>x%32===0&&y%32===0)}}''')
 check(data['radius']==64 and data['spacing']==32,'64m radius and 32m node spacing')
 check(data['nodeSpacing'],'all permanent nodes lie on 32m metre coordinates')
 check(page.evaluate('preview.nodes.length')==27,'all expected 32m supply points are present')
 check(page.evaluate("preview.pulseStates(10.19,'export').some(p=>p.emission===2)&&!preview.pulseStates(10.21,'export').some(p=>p.emission===2)"),'export marker disappears at neighbor boundary')
 for key,label in [('domesticOnly','domestic mode has only internal destinations'),('arrives','white circle fades and is removed at terminal'),('exportForward','surplus marker travels toward neighbor'),('importReverse','import marker travels from neighbor inward'),('within','markers exist only during their travel lifetime')]:check(data[key],label)
 page.get_by_role('button',name='잉여 전력 수출',exact=True).click();check(page.evaluate('preview.getMode()')=='export','export button selects export mode')
 page.get_by_role('button',name='부족 전력 수입',exact=True).click();check(page.evaluate('preview.getMode()')=='import','import button selects import mode')
 page.get_by_role('button',name='내부 공급',exact=True).click()
 page.locator('#pause').click();check(page.evaluate('preview.isPaused()'),'pause control works');page.locator('#pause').click()
 page.locator('#coverage').uncheck();check(page.locator('#ranges').evaluate("n=>getComputedStyle(n).display")=='none','range overlay toggle works');page.locator('#coverage').check()
 for mode,t in [('domestic',3.8),('export',8.0),('import',3.0)]:
  page.evaluate('([t,m])=>preview.renderAt(t,m)',[t,mode]);page.screenshot(path=str(OUT/(mode+'.png')),full_page=True)
 frames=[]
 for mode in ['domestic','export']:
  for i in range(32):
   page.evaluate('([t,m])=>preview.renderAt(t,m)',[(4 if mode=='export' else 2)+i*.25,mode])
   raw=page.screenshot(full_page=True);im=Image.open(io.BytesIO(raw)).convert('RGB');im.thumbnail((960,700));frames.append(im.quantize(colors=128))
 gif=OUT/'flow-demo.gif';frames[0].save(gif,save_all=True,append_images=frames[1:],duration=250,loop=0,disposal=2,optimize=False)
 with Image.open(gif) as im:check(im.n_frames==64,'64-frame animated GIF decodes')
 check(ImageChops.difference(frames[0].convert('RGB'),frames[8].convert('RGB')).getbbox() is not None,'captured flow frames change')
 page.set_viewport_size({'width':390,'height':844});page.evaluate("preview.renderAt(4,'domestic')")
 check(page.evaluate('document.documentElement.scrollWidth<=innerWidth'),'390px mobile layout has no horizontal overflow')
 page.screenshot(path=str(OUT/'mobile.png'),full_page=True)
 reduced=browser.new_context(reduced_motion='reduce');rp=reduced.new_page();rp.goto('http://127.0.0.1:8768/preview.html');rp.wait_for_load_state('networkidle');check(rp.evaluate('preview.isPaused()'),'reduced-motion starts paused');reduced.close()
 check(not errors,'no JavaScript page errors')
 browser.close()
(OUT/'validation.json').write_text(json.dumps({'scope':'standalone animated design only; no gameplay/power simulation','checks':results,'passed':all(r['passed'] for r in results),'gif_frames':64,'runtime_changed':False},ensure_ascii=False,indent=2)+'\n')
print('PASS',len(results),'concept checks; GIF 64 frames')
