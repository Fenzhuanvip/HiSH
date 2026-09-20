import http from '@ohos.net.http';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { iamClient, ServiceEndpoint } from './IamClient';

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
 * 用 IAM token（X-Auth-Token）调 CodeArts 各子服务
 * 端点优先从 IAM catalog 查找，回退到命名惯例推断
 */
class CodeArtsClient {
  private region: string = 'cn-north-4'
  private projectId: string = ''

  setRegion(region: string): void {
    this.region = region
  }

  setProjectId(projectId: string): void {
    this.projectId = projectId
  }

  getProjectId(): string {
    return this.projectId
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
    const auth = await iamClient.getToken()
    if (!auth) {
      return { data: null, ok: false, statusCode: 401, message: 'IAM 认证失败，请检查 AK/SK' }
    }

    const baseUrl = this.resolveServiceUrl(serviceType)
    if (!baseUrl) {
      return { data: null, ok: false, statusCode: -1, message: `无法解析服务 ${serviceType} 的端点` }
    }

    // 替换路径里的 {project_id}
    const realPath = path.replace('{project_id}', this.projectId)
    const url = baseUrl.replace(/\/$/, '') + realPath
    hilog.info(DOMAIN, TAG, '%{public}s %{public}s', method, url)

    const httpRequest = http.createHttp()
    const headers: Record<string, string> = {
      'X-Auth-Token': auth.token,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    }

    try {
      const resp = await httpRequest.request(url, {
        method,
        header: headers,
        extraData: body ? JSON.stringify(body) : undefined,
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

  /** 解析服务端点 URL：优先 IAM catalog，回退命名惯例 */
  private resolveServiceUrl(serviceType: string): string {
    // 先从 catalog 查
    const fromCatalog = iamClient.findServiceUrl(serviceType)
    if (fromCatalog) return fromCatalog

    // 回退：华为云命名惯例推断
    const fallback: Record<string, string> = {
      'codehub': `https://codehub-ext.${this.region}.myhuaweicloud.com`,
      'pipeline': `https://pipeline.${this.region}.myhuaweicloud.com`,
      'codecheck': `https://codecheck.${this.region}.myhuaweicloud.com`,
      'cloudbuild': `https://cloudbuild.${this.region}.myhuaweicloud.com`,
      'devcloud': `https://devcloud.${this.region}.myhuaweicloud.com`,
    }
    return fallback[serviceType] || `https://${serviceType}.${this.region}.myhuaweicloud.com`
  }
}

const codeArtsClient = new CodeArtsClient()

export { CodeArtsClient, codeArtsClient, CodeArtsResult }
