import fs from '@ohos.file.fs';
import util from '@ohos.util';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0001;
const TAG = '[codeartsBridge]';

/** 语言 → 扩展名 */
function extOf(lang: string): string {
  const map: Record<string, string> = {
    'typescript': 'ts', 'ts': 'ts', 'javascript': 'js', 'js': 'js',
    'python': 'py', 'py': 'py', 'java': 'java', 'go': 'go', 'shell': 'sh',
    'bash': 'sh', 'sh': 'sh', 'json': 'json', 'yaml': 'yaml', 'yml': 'yaml',
    'html': 'html', 'css': 'css', 'c': 'c', 'cpp': 'cpp', 'tsx': 'tsx',
    'jsx': 'jsx', 'sql': 'sql', 'xml': 'xml', 'markdown': 'md', 'md': 'md'
  };
  const key = (lang || '').toLowerCase().trim();
  return map[key] || 'txt';
}

/**
 * 把云码道网页里的代码块写入共享目录（guest 端 /mnt/share）
 * @param sharedHost Host 侧共享目录绝对路径（AppStorage(appOption.sharedHost)）
 */
export function saveCodeBlock(sharedHost: string, content: string, lang: string): boolean {
  if (!sharedHost || sharedHost.length === 0) {
    hilog.warn(DOMAIN, TAG, 'sharedHost empty, skip');
    return false;
  }
  if (!content || content.length === 0) {
    return false;
  }
  try {
    const dir = sharedHost.endsWith('/') ? sharedHost : (sharedHost + '/');
    const ext = extOf(lang);
    const name = `code_${Date.now()}.${ext}`;
    const path = dir + name;
    const file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
    const encoder = new util.TextEncoder();
    const bytes = encoder.encodeInto(content);
    fs.writeSync(file.fd, bytes.buffer);
    fs.closeSync(file);
    hilog.info(DOMAIN, TAG, 'saved code block: %{public}s', path);
    return true;
  } catch (e) {
    hilog.error(DOMAIN, TAG, 'saveCodeBlock failed: %{public}s', JSON.stringify(e));
    return false;
  }
}