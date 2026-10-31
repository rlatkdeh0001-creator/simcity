from playwright.sync_api import sync_playwright, expect
with sync_playwright() as p:
    browser = p.chromium.launch(headless=True, executable_path='/usr/bin/chromium', args=['--no-sandbox'])
    page = browser.new_page(viewport={'width':1280,'height':850})
    errors=[]
    page.on('pageerror',lambda error:errors.append(str(error)))
    page.goto('http://127.0.0.1:4173')
    page.wait_for_load_state('networkidle')
    print('DOM buttons:',page.get_by_role('button').all_text_contents())
    expect(page.get_by_role('status')).to_have_text('공원 0개')
    for _ in range(3): page.get_by_role('button',name='공원 추가').click()
    expect(page.get_by_role('status')).to_have_text('공원 3개')
    expect(page.locator('.park')).to_have_count(3)
    page.get_by_role('button',name='초기화').click()
    expect(page.get_by_role('status')).to_have_text('공원 0개')
    page.screenshot(path='/workspace/skill-validation/desktop.png',full_page=True)
    page.set_viewport_size({'width':390,'height':844})
    assert page.evaluate('document.documentElement.scrollWidth <= innerWidth')
    page.get_by_role('button',name='공원 추가').click()
    expect(page.get_by_role('status')).to_have_text('공원 1개')
    page.screenshot(path='/workspace/skill-validation/mobile.png',full_page=True)
    assert not errors,errors
    print('PASS: initial render, 3 increments, reset, mobile layout, mobile interaction, no JS errors')
    browser.close()
