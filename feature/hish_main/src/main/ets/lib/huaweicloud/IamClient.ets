import http from '@ohos.net.http';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = '[IamClient]';
const DOMAIN = 0x0002;

/** IAM token body */
interface IamTokenBody {
  expires_at: string
  catalog: ServiceEndpoint[]
  user: { id: string; name: string; domain: { id: string; name: string } }
  domain?: { id: string; name: string }
  project?: { id: string; name: string }
}

/** IAM token 响应体 */
interface IamTokenResponse {
  token: IamTokenBody
}

/** 服务端点目录项 */
interface ServiceEndpoint {
  type: string
  id: string
  name: string
  endpoints: { id: string; interface: string; region: string; region_id: string; url: string }[]
}

/** IAM 认证结果 */
interface IamAuthResult {
  token: string
  expiresAt: string
  domainId: string
  domainName: string
  catalog: ServiceEndpoint[]
}

/**
 * 华为云 IAM 认证客户端
 * 用 AK/SK 获取 IAM token（X-Subject-Token）
 * 流程：先获取 unscoped token 拿 domain 信息，再获取 domain-scoped token
 */
class IamClient {
  private region: string = 'cn-north-4'
  private ak: string = ''
  private sk: string = ''
  private cachedToken: IamAuthResult | null = null

  setCredentials(ak: string, sk: string, region: string = 'cn-north-4'): void {
    this.ak = ak
    this.sk = sk
    this.region = region
    this.cachedToken = null
  }

  isConfigured(): boolean {
    return this.ak.length > 0 && this.sk.length > 0
  }

  /** 获取 IAM token（带缓存，过期前不重复请求） */
  async getToken(): Promise<IamAuthResult | null> {
    if (!this.isConfigured()) return null
    if (this.cachedToken && !this.isExpired(this.cachedToken.expiresAt)) {
      return this.cachedToken
    }
    const result = await this.authWithAkSk()
    if (result) {
      this.cachedToken = result
    }
    return result
  }

  /** 用 AK/SK 获取 IAM token */
  private async authWithAkSk(): Promise<IamAuthResult | null> {
    // 第一步：获取 unscoped token 拿 domain 信息
    const unscoped = await this.requestToken({
      auth: {
        identity: {
          methods: ['hw_ak_sk'],
          hw_ak_sk: { access: this.ak, secret: this.sk }
        }
      }
    })
    if (!unscoped) return null

    const domainId = unscoped.token.user.domain.id
    const domainName = unscoped.token.user.domain.name
    hilog.info(DOMAIN, TAG, 'domain: %{public}s / %{public}s', domainName, domainId)

    // 第二步：获取 domain-scoped token（用于调全局服务 API）
    const scoped = await this.requestToken({
      auth: {
        identity: {
          methods: ['hw_ak_sk'],
          hw_ak_sk: { access: this.ak, secret: this.sk }
        },
        scope: {
          domain: { id: domainId }
        }
      }
    })
    if (!scoped) return null

    return {
      token: scoped.tokenStr,
      expiresAt: scoped.token.expires_at,
      domainId,
      domainName,
      catalog: scoped.token.catalog || []
    }
  }

  /** 发起 IAM token 请求，返回 token 字符串和响应体 */
  private async requestToken(body: Object): Promise<{ tokenStr: string; token: IamTokenBody } | null> {
    const url = `https://iam.${this.region}.myhuaweicloud.com/v3/auth/tokens`
    hilog.info(DOMAIN, TAG, 'IAM request to %{public}s', url)

    const httpRequest = http.createHttp()
    try {
      const resp = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/json' },
        extraData: JSON.stringify(body),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 30000,
      })

      if (resp.responseCode >= 200 && resp.responseCode < 300) {
        // X-Subject-Token 在响应 header 里
        const headers = resp.header as Record<string, string>
        const tokenStr = headers['X-Subject-Token'] || headers['x-subject-token'] || ''
        const raw = typeof resp.result === 'string' ? resp.result : String(resp.result)
        const tokenBody = JSON.parse(raw) as IamTokenResponse
        hilog.info(DOMAIN, TAG, 'IAM token acquired, expires: %{public}s', tokenBody.token.expires_at)
        return { tokenStr, token: tokenBody.token }
      }
      const errRaw = typeof resp.result === 'string' ? resp.result : String(resp.result)
      hilog.error(DOMAIN, TAG, 'IAM failed %{public}d: %{public}s', resp.responseCode, errRaw)
      return null
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'IAM exception: %{public}s', JSON.stringify(e))
      return null
    } finally {
      httpRequest.destroy()
    }
  }

  private isExpired(expiresAt: string): boolean {
    try {
      return new Date(expiresAt).getTime() <= Date.now()
    } catch (e) {
      return true
    }
  }

  /** 从 catalog 里查找服务端点 URL */
  findServiceUrl(serviceType: string): string | null {
    if (!this.cachedToken) return null
    for (const svc of this.cachedToken.catalog) {
      if (svc.type === serviceType) {
        for (const ep of svc.endpoints) {
          if (ep.interface === 'public' && (ep.region_id === this.region || ep.region === this.region)) {
            return ep.url
          }
        }
        // 退而求其次，取第一个 public 端点
        for (const ep of svc.endpoints) {
          if (ep.interface === 'public') return ep.url
        }
      }
    }
    return null
  }
}

const iamClient = new IamClient()

export { IamClient, iamClient, IamAuthResult, ServiceEndpoint }
