import http from '@ohos.net.http';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = '[GitCodeClient]';
const DOMAIN = 0x0002;
const API_BASE = 'https://atomgit.com/api/v5';

interface GitCodeResult<T> {
  data: T | null
  ok: boolean
  statusCode: number
  message?: string
}

/**
 * GitCode（atomgit）API 客户端
 * 用 Personal Access Token 认证，简单直接
 * API 文档：Gitea/Forgejo 风格 /api/v5
 */
class GitCodeClient {
  private token: string = ''

  setToken(token: string): void {
    this.token = token
  }

  isConfigured(): boolean {
    return this.token.length > 0
  }

  /**
   * 通用 API 请求
   * @param path API 路径（如 /user/repos）
   * @param method HTTP 方法
   * @param body 请求体
   */
  async request<T>(path: string, method: http.RequestMethod = http.RequestMethod.GET,
    body?: Object): Promise<GitCodeResult<T>> {
    if (!this.isConfigured()) {
      return { data: null, ok: false, statusCode: 401, message: '未配置 GitCode Token' }
    }

    const url = API_BASE + path
    const bodyStr = body ? JSON.stringify(body) : ''

    const httpRequest = http.createHttp()
    const headers: Record<string, string> = {
      'Authorization': `token ${this.token}`,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    }

    hilog.info(DOMAIN, TAG, '%{public}s %{public}s', method, path)

    try {
      const resp = await httpRequest.request(url, {
        method,
        header: headers,
        extraData: bodyStr.length > 0 ? bodyStr : undefined,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 30000,
      })

      const statusCode = resp.responseCode
      const raw = typeof resp.result === 'string' ? resp.result : String(resp.result)

      if (statusCode >= 200 && statusCode < 300) {
        const data = raw.length > 0 ? JSON.parse(raw) as T : null
        return { data, ok: true, statusCode }
      }
      hilog.error(DOMAIN, TAG, 'failed %{public}d: %{public}s', statusCode, raw.substring(0, 200))
      return { data: null, ok: false, statusCode, message: raw.substring(0, 200) }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'exception: %{public}s', JSON.stringify(e))
      return { data: null, ok: false, statusCode: -1, message: JSON.stringify(e) }
    } finally {
      httpRequest.destroy()
    }
  }
}

const gitCodeClient = new GitCodeClient()

export { GitCodeClient, gitCodeClient, GitCodeResult }
