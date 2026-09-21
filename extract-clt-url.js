const puppeteer = require('puppeteer-core');
const chromium = require('@sparticuz/chromium');
const fs = require('fs');

(async () => {
  const chromePath = await chromium.executablePath();
  console.log('Chrome 路径:', chromePath);
  if (!chromePath) { console.error('未找到 chromium，退出'); process.exit(1); }

  const browser = await puppeteer.launch({
    executablePath: chromePath,
    headless: chromium.headless,
    args: chromium.args,
  });
  const page = await browser.newPage();
  await page.setUserAgent('Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
  await page.setViewport({ width: 1920, height: 1080 });

  // 拦截所有网络请求
  const allRequests = [];
  page.on('request', req => {
    const url = req.url();
    if (!url.includes('.js') && !url.includes('.css') && !url.includes('.png') && !url.includes('.svg') && !url.includes('.woff') && !url.includes('.ico')) {
      allRequests.push({ method: req.method(), url: url.substring(0, 200) });
      if (url.includes('svc-drcn') || url.includes('downloadCenter') || url.includes('getTool') || url.includes('api')) {
        console.log(`API: ${req.method()} ${url.substring(0, 200)}`);
      }
    }
  });
  page.on('response', async resp => {
    const url = resp.url();
    if (url.includes('svc-drcn') || url.includes('downloadCenter') || url.includes('getTool') || url.includes('getLatest')) {
      console.log(`RESP: ${resp.status()} ${url.substring(0, 150)}`);
      try {
        const text = await resp.text();
        console.log(`  BODY: ${text.substring(0, 1000)}`);
      } catch {}
    }
  });

  console.log('正在加载页面...');
  try {
    await page.goto('https://developer.huawei.com/consumer/cn/download/', { waitUntil: 'domcontentloaded', timeout: 30000 });
  } catch (e) { console.log('加载错误:', e.message); }

  console.log('等待 20 秒...');
  await new Promise(r => setTimeout(r, 20000));

  console.log('\n=== 页面信息 ===');
  console.log('URL:', page.url());
  console.log('Title:', await page.title());
  const html = await page.content();
  console.log('HTML 长度:', html.length);

  const pageText = await page.evaluate(() => document.body?.innerText || 'EMPTY');
  console.log('文本长度:', pageText.length);
  console.log('文本内容:', pageText.substring(0, 3000));

  // 查找所有链接
  const links = await page.evaluate(() => Array.from(document.querySelectorAll('a')).map(a => ({t: a.textContent.trim().substring(0, 60), h: a.href})).filter(l => l.t));
  console.log(`\n链接数: ${links.length}`);
  links.slice(0, 40).forEach(l => console.log(`  ${l.t} -> ${l.h.substring(0, 100)}`));

  // 查找下载相关元素
  const downloads = await page.evaluate(() => {
    const results = [];
    document.querySelectorAll('*').forEach(el => {
      const t = el.textContent.trim();
      if (t.length < 100 && (t.includes('Command Line') || t.includes('命令行') || t.includes('下载') || t.includes('Download'))) {
        results.push({ tag: el.tagName, text: t.substring(0, 80) });
      }
    });
    return results.slice(0, 20);
  });
  console.log('\n下载相关元素:');
  downloads.forEach(d => console.log(`  [${d.tag}] ${d.text}`));

  console.log(`\n总请求数: ${allRequests.length}`);
  console.log('所有非静态请求:');
  allRequests.forEach(r => console.log(`  ${r.method} ${r.url}`));

  await page.screenshot({ path: '/tmp/page.png', fullPage: true });
  console.log('截图已保存');

  await browser.close();
})().catch(e => { console.error('错误:', e.message); process.exit(1); });
