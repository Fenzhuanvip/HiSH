#!/usr/bin/env python3
"""Build wrapper: runs build, captures output, pushes log to CodeHub."""
import subprocess, sys, os, json, hashlib, hmac, datetime, urllib.parse, requests, base64, time

AK = "HPUAAPSYPIAXPCYUX8TF"
SK = "3Mg8PEHwcddzdk5xtdr7uSBCvDXSqkerW6CNAtqg"
REPO_ID = 3088746
ENDPOINT = "https://codehub-ext.cn-north-4.myhuaweicloud.com"

def push_log(log_text):
    try:
        sdk_date = datetime.datetime.now(datetime.UTC).strftime('%Y%m%dT%H%M%SZ')
        url = f'{ENDPOINT}/v2/projects/{REPO_ID}/repository/commits'
        parsed = urllib.parse.urlparse(url)
        body = json.dumps({
            "branch": "master",
            "commit_message": f"Build log {datetime.datetime.now().strftime('%H:%M:%S')}",
            "actions": [{"action": "update", "file_path": "ci/build-log.txt",
                "content": log_text[:50000], "encoding": "text"}],
            "author_email": "ff-518@atomgit.com", "author_name": "ff-518", "force": True
        })
        headers = {'host': parsed.netloc, 'content-type': 'application/json', 'x-sdk-date': sdk_date}
        body_bytes = body.encode('utf-8')
        payload_hash = hashlib.sha256(body_bytes).hexdigest()
        canonical_uri = parsed.path + '/'
        header_keys = sorted(headers.keys())
        canonical_headers = ''.join(f'{k}:{headers[k].strip()}\n' for k in header_keys)
        signed_headers = ';'.join(header_keys)
        cr = f'POST\n{canonical_uri}\n\n{canonical_headers}\n{signed_headers}\n{payload_hash}'
        sts = f'SDK-HMAC-SHA256\n{sdk_date}\n{hashlib.sha256(cr.encode()).hexdigest()}'
        sig = hmac.new(SK.encode(), sts.encode(), hashlib.sha256).hexdigest()
        headers['authorization'] = f'SDK-HMAC-SHA256 Access={AK}, SignedHeaders={signed_headers}, Signature={sig}'
        requests.post(url, headers=headers, data=body_bytes, timeout=30)
    except Exception as e:
        print(f"Failed to push log: {e}")

# Build commands
commands = [
    ("git clone", 'git clone --depth 1 "https://ff-518:fNCrAW6XzAx_P-19_RymJr7t@atomgit.com/ff-518/HiSH.git" /tmp/hish-bin 2>&1 || true'),
    ("copy binaries", '''if [ -d /tmp/hish-bin ]; then
  for f in feature/hish_main/libs/arm64-v8a/libqemu-system-aarch64.so feature/hish_main/src/main/resources/rawfile/vm/kernel_aarch64 feature/hish_main/src/main/resources/rawfile/vm/rootfs_aarch64.qcow2; do
    if [ -f "/tmp/hish-bin/$f" ]; then mkdir -p "$(dirname "$f")" && cp "/tmp/hish-bin/$f" "$f" && echo "OK: $f"; fi
  done
  rm -rf /tmp/hish-bin
fi'''),
    ("ohpm config", 'ohpm config set strict_ssl false && ohpm config set registry https://ohpm.openharmony.cn/ohpm/ && npm config set strict-ssl false && npm config set registry=https://repo.huaweicloud.com/repository/npm/ && npm config set @ohos:registry=https://repo.harmonyos.com/npm/'),
    ("ohpm install", 'ohpm install 2>&1'),
    ("hvigorw clean", 'hvigorw clean --no-daemon 2>&1'),
    ("hvigorw assembleHap", 'hvigorw assembleHap --mode module -p product=default -p debuggable=false --no-daemon 2>&1'),
    ("find hap", 'find . -name "*.hap" -exec ls -lh {} \\; 2>&1 || echo "NO HAP FOUND"'),
]

log = []
exit_code = 0
for name, cmd in commands:
    log.append(f"\n{'='*60}")
    log.append(f"=== {name} ===")
    log.append(f"{'='*60}")
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=300)
    log.append(result.stdout)
    if result.stderr:
        log.append(f"STDERR: {result.stderr}")
    log.append(f"[exit: {result.returncode}]")
    if result.returncode != 0 and name != "git clone" and name != "find hap":
        exit_code = result.returncode
        log.append(f"!!! {name} FAILED !!!")
        break

log_text = '\n'.join(log)
print(log_text[-3000:])
push_log(log_text)
sys.exit(exit_code)
