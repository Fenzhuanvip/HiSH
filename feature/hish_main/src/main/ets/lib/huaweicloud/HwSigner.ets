import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { buffer } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = '[HwSigner]';
const DOMAIN = 0x0002;

/** 字符串转 Uint8Array (UTF-8) */
function strToBytes(str: string): Uint8Array {
  return new Uint8Array(buffer.from(str, 'utf-8').buffer);
}

/** Uint8Array 转十六进制字符串 */
function bytesToHex(bytes: Uint8Array): string {
  let hex = '';
  for (let i = 0; i < bytes.length; i++) {
    hex += (bytes[i] & 0xFF).toString(16).padStart(2, '0');
  }
  return hex;
}

/** SHA256 哈希 (十六进制输出) */
async function sha256Hex(data: string): Promise<string> {
  const md = cryptoFramework.createMd('SHA256');
  const mdData: cryptoFramework.DataBlob = { data: strToBytes(data) };
  await md.update(mdData);
  const result = await md.digest();
  return bytesToHex(result.data);
}

/** HMAC-SHA256 (十六进制输出) */
async function hmacSha256Hex(key: string, data: string): Promise<string> {
  // 生成 HMAC 密钥
  const keyData = strToBytes(key);
  const symKeyBlob: cryptoFramework.DataBlob = { data: keyData };
  const hmacGenerator = cryptoFramework.createSymKeyGenerator('HMAC');
  const symKey = await hmacGenerator.convertKey(symKeyBlob);

  // 计算 HMAC
  const mac = cryptoFramework.createMac('SHA256');
  await mac.init(symKey);
  await mac.update({ data: strToBytes(data) });
  const result = await mac.doFinal();
  return bytesToHex(result.data);
}

/** URL 编码 (RFC 3986) */
function urlEncode(str: string): string {
  return encodeURIComponent(str)
    .replace(/!/g, '%21')
    .replace(/\*/g, '%2A')
    .replace(/'/g, '%27')
    .replace(/\(/g, '%28')
    .replace(/\)/g, '%29');
}

/** 获取 UTC 时间戳 (格式: yyyyMMddTHHmmssZ) */
function utcNow(): string {
  const now = new Date();
  const y = now.getUTCFullYear();
  const mo = String(now.getUTCMonth() + 1).padStart(2, '0');
  const d = String(now.getUTCDate()).padStart(2, '0');
  const h = String(now.getUTCHours()).padStart(2, '0');
  const mi = String(now.getUTCMinutes()).padStart(2, '0');
  const s = String(now.getUTCSeconds()).padStart(2, '0');
  return `${y}${mo}${d}T${h}${mi}${s}Z`;
}

/** 签名结果 */
interface SignResult {
  authorization: string
  xSdkDate: string
}

/**
 * 华为云 SDK-HMAC-SHA256 签名
 */
async function sign(ak: string, sk: string, method: string, host: string, path: string,
  body: string): Promise<SignResult> {
  // 解析 path 和 query
  const qIdx = path.indexOf('?');
  let pathOnly = path;
  let queryString = '';

  if (qIdx >= 0) {
    pathOnly = path.substring(0, qIdx);
    const queryStr = path.substring(qIdx + 1);
    const params: Record<string, string> = {};
    for (const pair of queryStr.split('&')) {
      const eqIdx = pair.indexOf('=');
      if (eqIdx >= 0) {
        params[pair.substring(0, eqIdx)] = pair.substring(eqIdx + 1);
      } else {
        params[pair] = '';
      }
    }
    const sortedKeys = Object.keys(params).sort();
    queryString = sortedKeys.map(k => `${urlEncode(k)}=${urlEncode(params[k])}`).join('&');
  }

  // CanonicalURI 加尾部 /
  const signingUri = pathOnly.endsWith('/') ? pathOnly : pathOnly + '/';

  // 时间戳
  const xSdkDate = utcNow();

  // Headers
  const headers: Record<string, string> = {
    'host': host,
    'x-sdk-date': xSdkDate,
    'content-type': 'application/json',
  };
  if (body.length > 0) {
    headers['content-length'] = strToBytes(body).length.toString();
  }

  // CanonicalHeaders
  const sortedHeaderKeys = Object.keys(headers).sort();
  const canonicalHeaders = sortedHeaderKeys.map(k => `${k}:${headers[k]}\n`).join('');
  const signedHeaders = sortedHeaderKeys.join(';');

  // PayloadHash
  const payloadHash = await sha256Hex(body);

  // CanonicalRequest
  const canonicalRequest = [
    method.toUpperCase(),
    signingUri,
    queryString,
    canonicalHeaders,
    signedHeaders,
    payloadHash
  ].join('\n');

  // StringToSign
  const hashedCanonicalRequest = await sha256Hex(canonicalRequest);
  const stringToSign = ['SDK-HMAC-SHA256', xSdkDate, hashedCanonicalRequest].join('\n');

  // Signature
  const signature = await hmacSha256Hex(sk, stringToSign);

  // Authorization
  const authorization = `SDK-HMAC-SHA256 Access=${ak}, SignedHeaders=${signedHeaders}, Signature=${signature}`;

  hilog.info(DOMAIN, TAG, 'signed %{public}s %{public}s%{public}s', method, host, pathOnly);
  return { authorization, xSdkDate };
}

export { sign, SignResult };
