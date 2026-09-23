import http from '@ohos.net.http';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ApiResult } from './types';

const TAG = '[AtomGitClient]';
const DOMAIN = 0x0001;
const BASE_URL = 'https://api.atomgit.com/api/v5';

/**
 * AtomGit API v5 HTTP 客户端
 * 认证方式：Authorization: token {personalAccessToken}
 */
class AtomGitClient {
  private token: string = '';

  setToken(token: string): void {
    this.token = token;
  }

  getToken(): string {
    return this.token;
  }

  isAuthenticated(): boolean {
    return this.token.length > 0;
  }

  /**
   * 发起认证 API 请求
   * @param endpoint 相对端点，如 /user、/user/repos
   * @param method HTTP 方法
   * @param body 请求体（POST/PATCH/PUT）
   * @param query 查询参数
   */
  async request<T>(endpoint: string, method: http.RequestMethod = http.RequestMethod.GET,
    body?: Object, query?: Record<string, string>): Promise<ApiResult<T>> {
    if (!this.isAuthenticated()) {
      return { data: null, ok: false, statusCode: 401, message: '未配置 AtomGit Token' };
    }

    const url = this.buildUrl(endpoint, query);
    hilog.info(DOMAIN, TAG, '%{public}s %{public}s', method, url);

    const httpRequest = http.createHttp();
    const headers: Record<string, string> = {
      'Authorization': `token ${this.token}`,
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'User-Agent': 'HiSH-AiWorkbench/1.0'
    };

    try {
    const resp = await httpRequest.request(url, {
      method,
      header: headers,
      extraData: body ? JSON.stringify(body) : undefined,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 15000,
      readTimeout: 30000,
    });

    const statusCode = resp.responseCode;
    const raw = typeof resp.result === 'string' ? resp.result : String(resp.result);
    hilog.info(DOMAIN, TAG, 'resp %{public}d len=%{public}d', statusCode, raw.length);

      if (statusCode >= 200 && statusCode < 300) {
        const data = raw.length > 0 ? JSON.parse(raw) as T : null;
        return { data, ok: true, statusCode };
      }
      return { data: null, ok: false, statusCode, message: raw };
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'request failed: %{public}s', JSON.stringify(e));
      return { data: null, ok: false, statusCode: -1, message: JSON.stringify(e) };
    } finally {
      httpRequest.destroy();
    }
  }

  /** GET 请求 */
  async get<T>(endpoint: string, query?: Record<string, string>): Promise<ApiResult<T>> {
    return this.request<T>(endpoint, http.RequestMethod.GET, undefined, query);
  }

  /** POST 请求 */
  async post<T>(endpoint: string, body?: Object): Promise<ApiResult<T>> {
    return this.request<T>(endpoint, http.RequestMethod.POST, body);
  }

  /** PATCH 请求 */
  async patch<T>(endpoint: string, body?: Object): Promise<ApiResult<T>> {
    return this.request<T>(endpoint, http.RequestMethod.PATCH, body);
  }

  private buildUrl(endpoint: string, query?: Record<string, string>): string {
    let url = BASE_URL + (endpoint.startsWith('/') ? endpoint : '/' + endpoint);
    if (query && Object.keys(query).length > 0) {
      const parts: string[] = [];
      const keys = Object.keys(query);
      for (const k of keys) {
        parts.push(`${encodeURIComponent(k)}=${encodeURIComponent(query[k])}`);
      }
      const qs = parts.join('&');
      url += (url.includes('?') ? '&' : '?') + qs;
    }
    return url;
  }
}

/** 全局单例 */
const atomGitClient = new AtomGitClient();

export { AtomGitClient, atomGitClient, BASE_URL };
