"""Render the existing Blender PNGs in a local gallery; no image pixel editing."""
from pathlib import Path
from functools import partial
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
import threading
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parent
class Handler(SimpleHTTPRequestHandler):
 def log_message(self,*args):pass
server=ThreadingHTTPServer(('127.0.0.1',0),partial(Handler,directory=str(ROOT)))
threading.Thread(target=server.serve_forever,daemon=True).start()
try:
 with sync_playwright() as p:
  browser=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox'])
  page=browser.new_page(viewport={'width':1920,'height':1450},device_scale_factor=1)
  for html,output in [('comparison.html','comparison.png'),('reverse-review.html','reverse-review-sheet.png')]:
   if html=='reverse-review.html':(ROOT/html).write_text((ROOT/'comparison.html').read_text().replace('/building.png','/reverse-review.png'))
   page.goto(f'http://127.0.0.1:{server.server_port}/{html}');page.wait_for_load_state('networkidle');page.evaluate('document.fonts.ready')
   assert page.locator('img').count()==8
   assert page.locator('img').evaluate_all('(images)=>images.every(i=>i.complete && i.naturalWidth===900 && i.naturalHeight===1100)')
   assert page.locator('article').count()==8
   page.screenshot(path=str(ROOT/output),full_page=True)
   print('PASS',output,'8 original Blender renders loaded')
  browser.close()
finally:server.shutdown();server.server_close()
