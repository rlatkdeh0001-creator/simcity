"""Capture the side-by-side HTML with existing Blender renders; no pixel editing."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import threading
from playwright.sync_api import sync_playwright

folder = Path(__file__).resolve().parent
class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass

server = ThreadingHTTPServer(('127.0.0.1', 0), partial(QuietHandler, directory=str(folder)))
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
try:
    with sync_playwright() as p:
        browser = p.chromium.launch(executable_path='/usr/bin/chromium', headless=True, args=['--no-sandbox'])
        page = browser.new_page(viewport={'width':1600, 'height':1150}, device_scale_factor=1)
        errors = []
        page.on('pageerror', lambda error: errors.append(str(error)))
        page.goto(f'http://127.0.0.1:{server.server_port}/comparison.html')
        page.wait_for_load_state('networkidle')
        page.evaluate('document.fonts.ready')
        assert page.locator('img').count() == 3
        assert page.locator('img').evaluate_all('(images)=>images.every(i=>i.complete && i.naturalWidth>0)')
        assert not errors, errors
        page.screenshot(path=str(folder/'comparison.png'), full_page=True)
        print('PASS: three Blender images loaded, comparison screenshot captured, no JS errors')
        browser.close()
finally:
    server.shutdown()
    server.server_close()
