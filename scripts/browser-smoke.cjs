// Run against scripts/build-web.sh output served on localhost.
const assert = require('node:assert/strict');
const {chromium} = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const base = process.env.TEST_URL || 'http://127.0.0.1:8765';
(async () => {
  const browser = await chromium.launch({
    headless: true,
    ...(process.env.CHROME_EXECUTABLE ? {executablePath: process.env.CHROME_EXECUTABLE} : {}),
    args: ['--no-sandbox', '--enable-unsafe-swiftshader'],
  });
  try {
    const context = await browser.newContext({locale:'en-US', viewport:{width:390,height:844}});
    await context.addInitScript(() => {
      window.screenLocks = [];
      window.failWakeLock = false;
      Object.defineProperty(navigator, 'wakeLock', {value: {
        request: async type => {
          if (type !== 'screen') throw Error('Wrong lock type');
          if (window.failWakeLock) throw new DOMException('Denied', 'NotAllowedError');
          const lock = new EventTarget();
          lock.released = false;
          lock.release = async () => {
            lock.released = true;
            lock.dispatchEvent(new Event('release'));
          };
          window.screenLocks.push(lock);
          return lock;
        },
      }});
      window.audioStarts = 0;
      const start = AudioBufferSourceNode.prototype.start;
      AudioBufferSourceNode.prototype.start = function(...args) {
        window.audioStarts++;
        return start.apply(this, args);
      };
      window.setAppHidden = hidden => {
        Object.defineProperty(document, 'hidden', {configurable:true, get:()=>hidden});
        Object.defineProperty(document, 'visibilityState', {configurable:true, get:()=>hidden?'hidden':'visible'});
        document.dispatchEvent(new Event('visibilitychange'));
        if (!hidden) window.dispatchEvent(new Event('focus'));
      };
    });
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', e=>errors.push(e.message));
    page.on('console', m=>{if(m.type()==='error') errors.push(m.text());});
    let now = Date.UTC(2026, 9, 10, 18);
    await page.clock.setFixedTime(now);
    const enableSemantics = async () => {
      await page.locator('flt-semantics-placeholder').waitFor();
      await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
      await page.getByText('Poker Blinds Timer', {exact:true}).waitFor();
    };
    await page.goto(base);
    await enableSemantics();
    await page.getByText('Screen stays awake while this app is visible.', {exact:true}).waitFor();
    await page.getByRole('button', {name:'Start', exact:true}).click();
    await page.waitForFunction(()=>window.audioStarts===1);
    // Jump to five seconds past the first 45-minute level without running ticks.
    now += (45*60+5)*1000;
    await page.clock.setFixedTime(now);
    await page.getByText('44:55', {exact:true}).waitFor();
    await page.waitForFunction(()=>window.audioStarts===2);
    await page.waitForTimeout(500);
    assert.equal(await page.evaluate(()=>window.audioStarts),2);
    await page.getByRole('button', {name:'Pause', exact:true}).click();
    now += 600000;
    await page.clock.setFixedTime(now);
    await page.waitForTimeout(350);
    assert.equal(await page.getByText('44:55', {exact:true}).count(),1);
    await page.getByRole('button', {name:'Resume', exact:true}).click();
    await page.evaluate(()=>window.setAppHidden(true));
    await page.waitForFunction(()=>window.screenLocks.every(lock=>lock.released));
    now += 50*60000;
    await page.clock.setFixedTime(now);
    await page.evaluate(()=>window.setAppHidden(false));
    await page.getByText('24:55', {exact:true}).waitFor();
    await page.waitForFunction(()=>window.screenLocks.length===2 && !window.screenLocks[1].released);
    await page.waitForFunction(()=>window.audioStarts===3);
    await page.evaluate(()=>window.screenLocks.at(-1).release());
    await page.getByRole('button', {name:'Retry keeping screen awake'}).waitFor();
    await page.evaluate(()=>window.failWakeLock=true);
    await page.getByRole('button', {name:'Retry keeping screen awake'}).click();
    await page.getByRole('button', {name:'Retry keeping screen awake'}).waitFor();
    await page.evaluate(()=>window.failWakeLock=false);
    await page.getByRole('button', {name:'Retry keeping screen awake'}).click();
    await page.getByText('Screen stays awake while this app is visible.', {exact:true}).waitFor();
    await page.screenshot({path:'/tmp/poker-timer-mobile.png'});
    // Wait for the complete build to be cached, then reload without any network.
    await page.evaluate(async () => { await navigator.serviceWorker.ready; });
    await page.waitForFunction(()=>navigator.serviceWorker.controller !== null);
    await context.setOffline(true);
    await page.reload();
    await enableSemantics();
    await page.getByText('24:55', {exact:true}).waitFor();
    await page.getByRole('button', {name:'Enable sound'}).waitFor();
    await page.getByRole('button', {name:'Enable sound'}).click();
    await page.waitForFunction(()=>window.audioStarts===1);
    assert.deepEqual(errors, []);
    console.log('PASS: foreground alerts once, pause/resume, hidden catch-up, wake-lock release/retry/reacquire, offline reload and restored audio.');
    await context.close();
  } finally {
    await browser.close();
  }
})().catch(error=>{console.error(error);process.exitCode=1;});
