/* Copyright 2026 MoonCrowd contributors. SPDX-License-Identifier: Apache-2.0 */
/* Real Chromium integration; Playwright is a development-only dependency. */
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const http = require('node:http');
const path = require('node:path');
const {pathToFileURL} = require('node:url');
const {chromium} = require('playwright');
const root = path.resolve(__dirname, '..');
const web = path.join(root, 'web');
const output = path.resolve(process.env.MOONCROWD_BROWSER_OUTPUT || path.join(root, '_build/browser-report'));
fs.mkdirSync(output, {recursive: true});
for (const file of ['index.html', 'style.css', 'app.js', 'mooncrowd.js']) {
  assert.ok(fs.existsSync(path.join(web, file)), `Run python3 tools/build_web.py first: ${file}`);
}
const mime = {'.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8'};
const server = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://localhost');
  if (url.pathname === '/favicon.ico') { res.writeHead(204); res.end(); return; }
  const file = path.resolve(web, '.' + (url.pathname === '/' ? '/index.html' : decodeURIComponent(url.pathname)));
  if (!file.startsWith(web + path.sep) || !fs.existsSync(file) || !fs.statSync(file).isFile()) {
    res.writeHead(404); res.end(); return;
  }
  res.writeHead(200, {'Content-Type': mime[path.extname(file)] || 'application/octet-stream'});
  fs.createReadStream(file).pipe(res);
});
const scenarios = ['环形交换', '交叉人流', '狭窄通道'];

async function text(page, id) { return (await page.locator('#' + id).textContent()).trim(); }
async function tick(page, minimum) {
  await page.waitForFunction(n => Number(document.getElementById('ticks').textContent) >= n, minimum, {timeout: 15000});
}
async function expectPaused(page, at) {
  assert.equal(await text(page, 'status'), '已暂停');
  assert.equal(await text(page, 'ticks'), String(at));
  await page.waitForTimeout(160); // Verify a paused world does not continue advancing.
  assert.equal(await text(page, 'ticks'), String(at));
}
async function layout(page) {
  const measured = await page.evaluate(() => {
    const canvas = document.getElementById('canvas'), box = canvas.getBoundingClientRect();
    const data = canvas.getContext('2d').getImageData(0, 0, canvas.width, canvas.height).data;
    let agentPixels = 0;
    for (let i = 0; i < data.length; i += 16) {
      const [r, g, b, a] = data.slice(i, i + 4);
      if (a && ((r > 90 && r < 180 && g > 180 && b > 150) || (r > 210 && g > 130 && g < 200 && b > 100 && b < 180))) agentPixels++;
    }
    const docs = document.querySelector('header .docs');
    const headerLinkLines = docs.getBoundingClientRect().height / parseFloat(getComputedStyle(docs).lineHeight);
    return {overflow: document.documentElement.scrollWidth > innerWidth + 1, headerLinkLines,
      cssWidth: box.width, cssHeight: box.height, pixelWidth: canvas.width, pixelHeight: canvas.height,
      ratio: devicePixelRatio, agentPixels};
  });
  assert.equal(measured.overflow, false, 'page must not overflow horizontally');
  assert.ok(measured.headerLinkLines <= 1.1, 'header source link must remain on one line');
  assert.ok(measured.cssWidth > 100 && measured.cssHeight > 100);
  assert.ok(Math.abs(measured.pixelWidth - measured.cssWidth * measured.ratio) <= 1);
  assert.ok(Math.abs(measured.pixelHeight - measured.cssHeight * measured.ratio) <= 1);
  assert.ok(measured.agentPixels > 3, 'real canvas should contain visible agent pixels');
  return measured;
}

async function exercise(browser, url, profile) {
  const context = await browser.newContext(profile.options);
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
  page.on('requestfailed', request => errors.push(request.url() + ': ' + request.failure().errorText));
  await page.goto(url);
  await page.waitForFunction(() => globalThis.MoonCrowd && document.getElementById('ticks').textContent === '0');
  await page.locator('#canvas').scrollIntoViewIfNeeded();
  await page.waitForFunction(() => document.getElementById('canvas').width > 0);
  await expectPaused(page, 0);
  assert.equal(await page.locator('#error').isVisible(), false);
  assert.equal(await text(page, 'arrived'), '0 / 72');
  const initialLayout = await layout(page);

  // Select the first actual ring agent through mouse/touch at device-scaled coordinates.
  const point = await page.locator('#canvas').evaluate(canvas => {
    const box = canvas.getBoundingClientRect();
    return {x: box.left + box.width / 2 + 8 * Math.min(box.width / 23, box.height / 20), y: box.top + box.height / 2};
  });
  if (profile.options.hasTouch) await page.touchscreen.tap(point.x, point.y);
  else await page.mouse.click(point.x, point.y);
  assert.equal(await text(page, 'selected-id'), '#0');
  await page.locator('#step').focus();
  await page.keyboard.press('Enter');
  await expectPaused(page, 1);
  assert.match(await text(page, 'inspector'), /邻居/);
  await page.locator('#vectors').check();
  await page.locator('#trails').uncheck();
  assert.equal(await page.locator('#vectors').isChecked(), true);
  assert.equal(await page.locator('#trails').isChecked(), false);

  await page.locator('#play').click();
  await tick(page, 5);
  await page.locator('#play').click();
  const pausedAt = Number(await text(page, 'ticks'));
  await expectPaused(page, pausedAt);
  await page.locator('#play').click();
  await tick(page, pausedAt + 2);
  await page.locator('#reset').click();
  await expectPaused(page, 0);

  const range = page.locator('#count');
  await range.focus();
  await page.keyboard.press('Home');
  await page.keyboard.press('ArrowRight');
  assert.equal(await range.inputValue(), '24');
  assert.equal(await text(page, 'count-value'), '24');
  assert.equal(await text(page, 'arrived'), '0 / 24');
  for (let kind = 0; kind < 3; kind++) {
    const button = page.locator(`[data-scene="${kind}"]`);
    if (profile.options.hasTouch) await button.tap(); else await button.click();
    assert.equal(await button.getAttribute('aria-pressed'), 'true');
    assert.equal(await text(page, 'scene-name'), scenarios[kind]);
    await expectPaused(page, 0);
    await page.locator('#step').click();
    await expectPaused(page, 1);
    assert.ok(Number.isFinite(Number(await text(page, 'clearance'))));
  }

  // A failed count change must retain the previous scene and its committed controls.
  await page.evaluate(() => {
    globalThis.testOriginalReset = MoonCrowd.reset;
    MoonCrowd.reset = () => JSON.stringify({error: 'browser-injected reset failure'});
  });
  await range.focus(); await page.keyboard.press('ArrowRight');
  assert.equal(await text(page, 'status'), '已停止');
  assert.equal(await range.inputValue(), '24');
  assert.equal(await text(page, 'count-value'), '24');
  assert.equal(await text(page, 'arrived'), '0 / 24');
  assert.equal(await text(page, 'scene-name'), scenarios[2]);
  assert.equal(await page.locator('[data-scene="2"]').getAttribute('aria-pressed'), 'true');
  assert.equal(await page.locator('#step').isDisabled(), true);
  await page.evaluate(() => { MoonCrowd.reset = testOriginalReset; delete globalThis.testOriginalReset; });
  await page.locator('#reset').click();
  assert.equal(await page.locator('#error').isVisible(), false);
  await expectPaused(page, 0);

  await page.evaluate(() => {
    globalThis.testOriginalStep = MoonCrowd.step;
    MoonCrowd.step = () => JSON.stringify({error: 'browser-injected solver failure'});
  });
  await page.locator('#step').click();
  assert.equal(await page.locator('#error').isVisible(), true);
  assert.equal(await page.locator('#play').isDisabled(), true);
  assert.equal(await page.locator('#step').isDisabled(), true);
  assert.equal(await text(page, 'ticks'), '0');
  await page.evaluate(() => { MoonCrowd.step = testOriginalStep; delete globalThis.testOriginalStep; });
  await page.locator('#reset').click();
  await page.locator('#step').click();
  await expectPaused(page, 1);
  await layout(page);
  await page.screenshot({path: path.join(output, profile.name + '.png'), fullPage: true});
  assert.deepEqual(errors, [], 'no browser exceptions, console errors or failed asset requests');
  await context.close();
  console.log('PASS real Chromium: ' + profile.name);
  return {name: profile.name, initialLayout, passed: true};
}

(async () => {
  let browser;
  const results = [];
  try {
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
    const url = `http://127.0.0.1:${server.address().port}/`;
    browser = await chromium.launch({headless: true, ...(process.env.MOONCROWD_CHROMIUM ? {executablePath: process.env.MOONCROWD_CHROMIUM} : {})});
    const desktop = {viewport: {width: 1440, height: 1000}, deviceScaleFactor: 1};
    const mobile = {viewport: {width: 390, height: 844}, deviceScaleFactor: 3, isMobile: true, hasTouch: true};
    results.push(await exercise(browser, url, {name: 'desktop', options: desktop}));
    results.push(await exercise(browser, url, {name: 'mobile-touch', options: mobile}));
    results.push(await exercise(browser, pathToFileURL(path.join(web, 'index.html')).href, {name: 'offline-file', options: desktop}));
    fs.writeFileSync(path.join(output, 'report.json'), JSON.stringify({browser: browser.version(), results}, null, 2) + '\n');
    console.log('Real browser interaction, canvas, layout, offline load and recovery checks passed.');
  } catch (error) {
    fs.writeFileSync(path.join(output, 'failure.txt'), error.stack + '\n');
    throw error;
  } finally {
    if (browser) await browser.close();
    await new Promise(resolve => server.close(resolve));
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
