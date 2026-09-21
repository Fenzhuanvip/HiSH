const puppeteer = require('puppeteer');
const fs = require('fs');

(async () => {
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage']
  });
  const page = await browser.newPage();
  await page.setUserAgent('Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');

  // 拦截所有网络请求
  const apiCalls = [];
  const downloadUrls = [];
  page.on('request', req => {
    const url = req.url();
    if (url.includes('downloadCenter') || url.includes('getTool') || url.includes('getLatest')) {
      apiCalls.push({ method: req.method(), url, headers: req.headers() });
      console.log(`API CALL: ${req.method()} ${url}`);
    }
  });
  page.on('response', async resp => {
    const url = resp.url();
    if (url.includes('downloadCenter') || url.includes('getTool') || url.includes('getLatest')) {
      console.log(`API RESP: ${resp.status()} ${url}`);
      try {
        const text = await resp.text();
        console.log(`  BODY: ${text.substring(0, 500)}`);
      } catch {}
    }
  });

  // 拦截下载请求
  page.on('request', req => {
    const url = req.url();
    if (url.includes('.zip') || url.includes('.tar') || url.includes('.gz') || url.includes('contentcenter') || url.includes('dbankcdn')) {
      downloadUrls.push(url);
      console.log(`DOWNLOAD URL: ${url}`);
    }
  });

  console.log('正在加载华为开发者下载页面...');
  await page.goto('https://developer.huawei.com/consumer/cn/download/', {
    waitUntil: 'networkidle2',
    timeout: 60000
  });

  await new Promise(r => setTimeout(r, 8000));

  // 截图
  await page.screenshot({ path: '/tmp/download-page.png', fullPage: false });
  console.log('截图已保存');

  // 查找所有文本内容
  const pageText = await page.evaluate(() => document.body.innerText);
  const lines = pageText.split('\n').filter(l => l.trim());
  console.log('\n=== 页面文本内容（前100行）===');
  lines.slice(0, 100).forEach(l => console.log(l));

  // 查找 Command Line Tools 相关元素
  console.log('\n=== 查找 Command Line Tools ===');
  const cltElements = await page.evaluate(() => {
    const results = [];
    document.querySelectorAll('*').forEach(el => {
      const text = el.textContent.trim();
      if (text.length < 200 && (text.includes('Command Line') || text.includes('命令行工具'))) {
        results.push({ tag: el.tagName, text: text.substring(0, 100), id: el.id, className: el.className?.toString().substring(0, 50) });
      }
    });
    return results;
  });
  cltElements.forEach(el => console.log(JSON.stringify(el)));

  // 查找所有按钮和链接
  console.log('\n=== 所有按钮和链接 ===');
  const buttons = await page.evaluate(() => {
    const results = [];
    document.querySelectorAll('button, a, [role="button"]').forEach(el => {
      const text = el.textContent.trim();
      if (text && text.length < 100) {
        results.push({ tag: el.tagName, text, href: el.href || '', onclick: el.onclick ? 'yes' : 'no' });
      }
    });
    return results;
  });
  buttons.forEach(b => console.log(JSON.stringify(b)));

  // 保存 API 调用记录
  fs.writeFileSync('/tmp/api-calls.json', JSON.stringify(apiCalls, null, 2));
  fs.writeFileSync('/tmp/download-urls.json', JSON.stringify(downloadUrls, null, 2));
  console.log(`\n找到 ${apiCalls.length} 个 API 调用, ${downloadUrls.length} 个下载 URL`);

  await browser.close();
})().catch(e => { console.error('错误:', e.message); process.exit(1); });
