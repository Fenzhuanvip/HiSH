const puppeteer = require('puppeteer');
const fs = require('fs');

(async () => {
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage', '--disable-gpu']
  });
  const page = await browser.newPage();
  await page.setUserAgent('Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
  await page.setViewport({ width: 1920, height: 1080 });

  // 拦截所有网络请求
  let apiCount = 0;
  page.on('request', req => {
    const url = req.url();
    if (url.includes('downloadCenter') || url.includes('getTool') || url.includes('getLatest') || url.includes('svc-drcn')) {
      apiCount++;
      console.log(`API CALL: ${req.method()} ${url}`);
    }
  });
  page.on('response', async resp => {
    const url = resp.url();
    if (url.includes('downloadCenter') || url.includes('getTool') || url.includes('getLatest')) {
      console.log(`API RESP: ${resp.status()} ${url}`);
      try {
        const text = await resp.text();
        if (text.length < 2000) console.log(`  BODY: ${text}`);
        else console.log(`  BODY (truncated): ${text.substring(0, 1000)}`);
      } catch {}
    }
  });

  console.log('正在加载华为开发者下载页面...');
  try {
    await page.goto('https://developer.huawei.com/consumer/cn/download/', {
      waitUntil: 'networkidle2',
      timeout: 30000
    });
  } catch (e) {
    console.log('页面加载超时或错误: ' + e.message);
  }

  // 等待更长时间
  console.log('等待页面渲染...');
  await new Promise(r => setTimeout(r, 15000));

  // 打印页面信息
  console.log('\n=== 页面信息 ===');
  console.log('URL:', page.url());
  console.log('Title:', await page.title());

  // 打印 HTML 前缀
  const html = await page.content();
  console.log('HTML 长度:', html.length);
  console.log('HTML 前500字符:', html.substring(0, 500));

  // 打印页面文本
  const pageText = await page.evaluate(() => document.body?.innerText || 'NO BODY');
  console.log('\n=== 页面文本 ===');
  console.log('文本长度:', pageText.length);
  console.log(pageText.substring(0, 2000));

  // 查找所有链接
  console.log('\n=== 所有链接 ===');
  const links = await page.evaluate(() => {
    return Array.from(document.querySelectorAll('a')).map(a => ({
      text: a.textContent.trim().substring(0, 80),
      href: a.href
    })).filter(l => l.text || l.href);
  });
  console.log(`找到 ${links.length} 个链接`);
  links.slice(0, 30).forEach(l => console.log(`  ${l.text} -> ${l.href}`));

  // 查找所有按钮
  console.log('\n=== 所有按钮 ===');
  const buttons = await page.evaluate(() => {
    return Array.from(document.querySelectorAll('button, [role="button"], .download-btn, [class*="download"]')).map(b => ({
      tag: b.tagName,
      text: b.textContent.trim().substring(0, 80),
      class: b.className?.toString().substring(0, 80)
    })).filter(b => b.text);
  });
  console.log(`找到 ${buttons.length} 个按钮`);
  buttons.slice(0, 20).forEach(b => console.log(`  [${b.tag}] ${b.text} (${b.class})`));

  // 截图
  await page.screenshot({ path: '/tmp/download-page.png', fullPage: true });
  console.log('\n截图已保存到 /tmp/download-page.png');
  console.log(`API 调用数: ${apiCount}`);

  await browser.close();
})().catch(e => { console.error('错误:', e.message); process.exit(1); });
