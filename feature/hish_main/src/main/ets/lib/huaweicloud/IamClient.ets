import http from '@ohos.net.http';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = '[IamClient]';
const DOMAIN = 0x0002;

/** IAM domain info */
interface IamDomain {
  id: string
  name: string
}

/** IAM user info */
interface IamUser {
  id: string
  name: string
  domain: IamDomain
}

/** IAM service endpoint */
interface IamEndpoint {
  id: string
  interface: string
  region: string
  region_id: string
  url: string
}

/** IAM token body */
interface IamTokenBody {
  expires_at: string
  catalog: ServiceEndpoint[]
  user: IamUser
  domain?: IamDomain
  project?: IamDomain
}

/** IAM token response body */
interface IamTokenResponse {
  token: IamTokenBody
}

/** Service endpoint catalog entry */
interface ServiceEndpoint {
  type: string
  id: string
  name: string
  endpoints: IamEndpoint[]
}

/** IAM auth result */
interface IamAuthResult {
  token: string
  expiresAt: string
  domainId: string
  domainName: string
  catalog: ServiceEndpoint[]
}

/** IAM token request result */
interface IamTokenRequestResult {
  tokenStr: string
  token: IamTokenBody
}

/** AK/SK auth credentials */
interface HwAkSk {
  access: string
  secret: string
}

/** Auth identity */
interface AuthIdentity {
  methods: string[]
  hw_ak_sk: HwAkSk
}

/** Auth body */
interface AuthBody {
  identity: AuthIdentity
}

/** Scoped auth body */
interface ScopedAuthBody {
  identity: AuthIdentity
  scope: AuthScope
}

/** Auth scope */
interface AuthScope {
  domain: IamDomain
}

/** Token request wrapper */
interface TokenRequest {
  auth: AuthBody | ScopedAuthBody
}

/** HTTP request header */
interface HttpHeader {
  'Content-Type': string
}

/**
 * 华为云 IAM 认证客户端
 * 用 AK/SK 获取 IAM token（X-Subject-Token）
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

  private async authWithAkSk(): Promise<IamAuthResult | null> {
    const credentials: HwAkSk = { access: this.ak, secret: this.sk }
    const identity: AuthIdentity = { methods: ['hw_ak_sk'], hw_ak_sk: credentials }
    const authBody: AuthBody = { identity: identity }

    const unscopedReq: TokenRequest = { auth: authBody }
    const unscoped = await this.requestToken(unscopedReq)
    if (!unscoped) return null

    const domainId = unscoped.token.user.domain.id
    const domainName = unscoped.token.user.domain.name
    hilog.info(DOMAIN, TAG, 'domain: %{public}s / %{public}s', domainName, domainId)

    const scopeDomain: IamDomain = { id: domainId, name: domainName }
    const scope: AuthScope = { domain: scopeDomain }
    const scopedAuthBody: ScopedAuthBody = { identity: identity, scope: scope }
    const scopedReq: TokenRequest = { auth: scopedAuthBody }
    const scoped = await this.requestToken(scopedReq)
    if (!scoped) return null

    const result: IamAuthResult = {
      token: scoped.tokenStr,
      expiresAt: scoped.token.expires_at,
      domainId: domainId,
      domainName: domainName,
      catalog: scoped.token.catalog || []
    }
    return result
  }

  private async requestToken(body: TokenRequest): Promise<IamTokenRequestResult | null> {
    const url = `https://iam.${this.region}.myhuaweicloud.com/v3/auth/tokens`
    hilog.info(DOMAIN, TAG, 'IAM request to %{public}s', url)

    const httpRequest = http.createHttp()
    try {
      const header: HttpHeader = { 'Content-Type': 'application/json' }
      const resp = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: header,
        extraData: JSON.stringify(body),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 30000,
      })

      if (resp.responseCode >= 200 && resp.responseCode < 300) {
        const headers = resp.header as Record<string, string>
        const tokenStr = headers['X-Subject-Token'] || headers['x-subject-token'] || ''
        const raw = typeof resp.result === 'string' ? resp.result : String(resp.result)
        const tokenBody = JSON.parse(raw) as IamTokenResponse
        hilog.info(DOMAIN, TAG, 'IAM token acquired, expires: %{public}s', tokenBody.token.expires_at)
        const result: IamTokenRequestResult = { tokenStr: tokenStr, token: tokenBody.token }
        return result
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

  findServiceUrl(serviceType: string): string | null {
    if (!this.cachedToken) return null
    for (const svc of this.cachedToken.catalog) {
      if (svc.type === serviceType) {
        for (const ep of svc.endpoints) {
          if (ep.interface === 'public' && (ep.region_id === this.region || ep.region === this.region)) {
            return ep.url
          }
        }
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
