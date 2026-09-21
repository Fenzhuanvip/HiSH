import http from '@ohos.net.http';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { sign } from './HwSigner';
import appOption from '../../model/appOption';

const TAG = '[CodeArtsClient]';
const DOMAIN = 0x0002;

interface CodeArtsResult<T> {
  data: T | null
  ok: boolean
  statusCode: number
  message?: string
}

/**
 * 华为云 CodeArts API 客户端
 * 用 AK/SK 签名（SDK-HMAC-SHA256）直接调 CodeArts 各子服务
 */
class CodeArtsClient {
  private region: string = 'cn-north-4'
  private projectId: string = ''
  private ak: string = ''
  private sk: string = ''

  setRegion(region: string): void {
    this.region = region
  }

  setProjectId(projectId: string): void {
    this.projectId = projectId
  }

  getProjectId(): string {
    return this.projectId
  }

  setCredentials(ak: string, sk: string): void {
    this.ak = ak
    this.sk = sk
  }

  isConfigured(): boolean {
    return this.ak.length > 0 && this.sk.length > 0
  }

  /**
   * 通用 CodeArts API 请求
   * @param serviceType 服务类型（codehub/pipeline/codecheck/cloudbuild）
   * @param path API 路径（如 /v1/{project_id}/repositories）
   * @param method HTTP 方法
   * @param body 请求体
   */
  async request<T>(serviceType: string, path: string, method: http.RequestMethod = http.RequestMethod.GET,
    body?: Object): Promise<CodeArtsResult<T>> {
    if (!this.isConfigured()) {
      return { data: null, ok: false, statusCode: 401, message: 'AK/SK 未配置' }
    }

    const baseUrl = this.resolveServiceUrl(serviceType)
    if (!baseUrl) {
      return { data: null, ok: false, statusCode: -1, message: `无法解析服务 ${serviceType} 的端点` }
    }

    // 替换路径里的 {project_id}
    const realPath = path.replace('{project_id}', this.projectId)
    const fullUrl = baseUrl.replace(/\/$/, '') + realPath

    // 从 URL 解析 host 和 path (ArkTS 不支持 URL 构造函数)
    // URL 格式: https://host/path?query
    const urlWithoutScheme = fullUrl.substring(fullUrl.indexOf('://') + 3)
    const slashIdx = urlWithoutScheme.indexOf('/')
    const host = slashIdx >= 0 ? urlWithoutScheme.substring(0, slashIdx) : urlWithoutScheme
    const urlPath = slashIdx >= 0 ? urlWithoutScheme.substring(slashIdx) : '/'

    const bodyStr = body ? JSON.stringify(body) : ''

    // AK/SK 签名
    const httpMethod = method === http.RequestMethod.GET ? 'GET' :
      method === http.RequestMethod.POST ? 'POST' : method === http.RequestMethod.PUT ? 'PUT' : 'DELETE'
    const signResult = await sign(this.ak, this.sk, httpMethod, host, urlPath, bodyStr)

    const httpRequest = http.createHttp()
    const headers: Record<string, string> = {
      'Authorization': signResult.authorization,
      'x-sdk-date': signResult.xSdkDate,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    }

    hilog.info(DOMAIN, TAG, '%{public}s %{public}s%{public}s', method, host, urlPath)

    try {
      const resp = await httpRequest.request(fullUrl, {
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
      hilog.error(DOMAIN, TAG, '%{public}s failed %{public}d: %{public}s', serviceType, statusCode, raw)
      return { data: null, ok: false, statusCode, message: raw }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'request exception: %{public}s', JSON.stringify(e))
      return { data: null, ok: false, statusCode: -1, message: JSON.stringify(e) }
    } finally {
      httpRequest.destroy()
    }
  }

  /** 解析服务端点 URL */
  private resolveServiceUrl(serviceType: string): string {
    const fallback: Record<string, string> = {
      'codehub': `https://codehub-ext.${this.region}.myhuaweicloud.com`,
      'pipeline': `https://pipeline.${this.region}.myhuaweicloud.com`,
      'codecheck': `https://codecheck.${this.region}.myhuaweicloud.com`,
      'cloudbuild': `https://cloudbuild-ext.${this.region}.myhuaweicloud.com`,
      'devcloud': `https://devcloud.${this.region}.myhuaweicloud.com`,
    }
    return fallback[serviceType] || `https://${serviceType}.${this.region}.myhuaweicloud.com`
  }
}

const codeArtsClient = new CodeArtsClient()

export { CodeArtsClient, codeArtsClient, CodeArtsResult }
