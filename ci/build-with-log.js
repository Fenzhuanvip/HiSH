#!/usr/bin/env node
const { execSync } = require('child_process');
const https = require('https');
const crypto = require('crypto');

const AK = "HPUAAPSYPIAXPCYUX8TF";
const SK = "3Mg8PEHwcddzdk5xtdr7uSBCvDXSqkerW6CNAtqg";
const REPO_ID = 3088746;
const HOST = "codehub-ext.cn-north-4.myhuaweicloud.com";

function pushLog(log) {
  try {
    const date = new Date().toISOString().replace(/[-:]/g,'').replace(/\.\d+/,'');
    const body = JSON.stringify({
      branch: "master",
      commit_message: "Build log " + new Date().toISOString(),
      actions: [{action: "update", file_path: "ci/build-log.txt", content: log.substring(0,50000), encoding: "text"}],
      author_email: "ff-518@atomgit.com", author_name: "ff-518", force: true
    });
    const path = `/v2/projects/${REPO_ID}/repository/commits`;
    const payloadHash = crypto.createHash('sha256').update(body).digest('hex');
    const canonicalUri = path + '/';
    const canonicalHeaders = `content-type:application/json\nhost:${HOST}\nx-sdk-date:${date}\n`;
    const signedHeaders = "content-type;host;x-sdk-date";
    const cr = `POST\n${canonicalUri}\n\n${canonicalHeaders}\n${signedHeaders}\n${payloadHash}`;
    const sts = `SDK-HMAC-SHA256\n${date}\n${crypto.createHash('sha256').update(cr).digest('hex')}`;
    const sig = crypto.createHmac('sha256', SK).update(sts).digest('hex');
    const options = {
      hostname: HOST, port: 443, path: path, method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Sdk-Date': date,
        'Authorization': `SDK-HMAC-SHA256 Access=${AK}, SignedHeaders=${signedHeaders}, Signature=${sig}`
      }
    };
    const req = https.request(options, (res) => { let d=''; res.on('data',c=>d+=c); res.on('end',()=>console.log(`Log push: ${res.statusCode}`)); });
    req.write(body); req.end();
  } catch(e) { console.log("Log push failed: " + e.message); }
}

const commands = [
  ["git clone", 'git clone --depth 1 "https://ff-518:fNCrAW6XzAx_P-19_RymJr7t@atomgit.com/ff-518/HiSH.git" /tmp/hish-bin 2>&1 || true'],
  ["copy binaries", 'if [ -d /tmp/hish-bin ]; then for f in feature/hish_main/libs/arm64-v8a/libqemu-system-aarch64.so feature/hish_main/src/main/resources/rawfile/vm/kernel_aarch64 feature/hish_main/src/main/resources/rawfile/vm/rootfs_aarch64.qcow2; do if [ -f "/tmp/hish-bin/$f" ]; then mkdir -p "$(dirname "$f")" && cp "/tmp/hish-bin/$f" "$f" && echo "OK: $f"; fi; done; rm -rf /tmp/hish-bin; fi'],
  ["ohpm config", 'ohpm config set strict_ssl false && ohpm config set registry https://ohpm.openharmony.cn/ohpm/ && npm config set strict-ssl false && npm config set registry=https://repo.huaweicloud.com/repository/npm/ && npm config set @ohos:registry=https://repo.harmonyos.com/npm/'],
  ["ohpm install", 'ohpm install 2>&1'],
  ["hvigorw clean", 'hvigorw clean --no-daemon 2>&1'],
  ["hvigorw assembleHap", 'hvigorw assembleHap --mode module -p product=default -p debuggable=false --no-daemon 2>&1'],
  ["find hap", 'find . -name "*.hap" -exec ls -lh {} \\; 2>&1 || echo "NO HAP FOUND"'],
];

let log = "";
let exitCode = 0;
for (const [name, cmd] of commands) {
  log += `\n${'='.repeat(60)}\n=== ${name} ===\n${'='.repeat(60)}\n`;
  try {
    const output = execSync(cmd, {timeout: 300000, encoding: 'utf8', stdio: 'pipe'});
    log += output + "\n[exit: 0]\n";
    console.log(`${name}: OK`);
  } catch(e) {
    log += (e.stdout || '') + "\n" + (e.stderr || '') + `\n[exit: ${e.status}]\n!!! ${name} FAILED !!!\n`;
    console.log(`${name}: FAILED (${e.status})`);
    if (name !== "git clone" && name !== "find hap") { exitCode = e.status || 1; break; }
  }
}
console.log("\n" + log.substring(log.length - 2000));
pushLog(log);
process.exit(exitCode);
