import { codeArtsClient, CodeArtsResult } from './CodeArtsClient';

/**
 * CodeArts 各子服务 API 封装
 * 端点基于华为云 OpenAPI 文档惯例，{project_id} 由 CodeArtsClient 自动替换
 */

/** 代码托管仓库 */
interface CodeArtsRepository {
  id: string
  name: string
  description: string
  httpUrl: string
  sshUrl: string
  webUrl: string
  defaultBranch: string
  visibility: string
  starCount: number
  forkCount: number
  createdAt: string
  updatedAt: string
}

/** 流水线 */
interface CodeArtsPipeline {
  id: string
  name: string
  description: string
  status: string
  latestRunStatus: string
  latestRunId: string
  branch: string
  creator: string
  createdAt: string
  updatedAt: string
}

/** 流水线运行记录 */
interface CodeArtsPipelineRun {
  id: string
  pipelineId: string
  status: string
  startTime: string
  endTime: string
  trigger: string
  branch: string
  commitId: string
  buildNumber: number
}

/** 代码检查严重等级分布 */
interface CodeArtsSeverity {
  fatal: number
  major: number
  minor: number
  suggestion: number
}

/** 代码检查任务 */
interface CodeArtsCheckTask {
  id: string
  name: string
  status: string
  language: string
  ruleCount: number
  issueCount: number
  severity: CodeArtsSeverity
  createdAt: string
  updatedAt: string
}

/** 编译构建任务 */
interface CodeArtsBuildJob {
  id: string
  name: string
  status: string
  branch: string
  lastBuildNumber: number
  lastBuildStatus: string
  createdAt: string
}

class CodeArtsApi {

  // ==================== 代码托管（CodeHub） ====================

  /** 列出项目下的代码仓库 */
  async listRepositories(): Promise<CodeArtsResult<CodeArtsRepository[]>> {
    return codeArtsClient.request<CodeArtsRepository[]>('codehub', '/v1/{project_id}/repositories')
  }

  /** 获取仓库详情 */
  async getRepository(repoId: string): Promise<CodeArtsResult<CodeArtsRepository>> {
    return codeArtsClient.request<CodeArtsRepository>('codehub', `/v1/{project_id}/repositories/${repoId}`)
  }

  // ==================== 流水线（Pipeline） ====================

  /** 列出流水线 */
  async listPipelines(): Promise<CodeArtsResult<CodeArtsPipeline[]>> {
    return codeArtsClient.request<CodeArtsPipeline[]>('pipeline', '/v3/{project_id}/pipelines')
  }

  /** 列出流水线运行记录 */
  async listPipelineRuns(pipelineId: string): Promise<CodeArtsResult<CodeArtsPipelineRun[]>> {
    return codeArtsClient.request<CodeArtsPipelineRun[]>('pipeline', `/v3/{project_id}/pipelines/${pipelineId}/runs`)
  }

  /** 获取流水线运行详情 */
  async getPipelineRun(pipelineId: string, runId: string): Promise<CodeArtsResult<CodeArtsPipelineRun>> {
    return codeArtsClient.request<CodeArtsPipelineRun>('pipeline', `/v3/{project_id}/pipelines/${pipelineId}/runs/${runId}`)
  }

  // ==================== 代码检查（CodeCheck） ====================

  /** 列出代码检查任务 */
  async listCheckTasks(): Promise<CodeArtsResult<CodeArtsCheckTask[]>> {
    return codeArtsClient.request<CodeArtsCheckTask[]>('codecheck', '/v2/{project_id}/tasks')
  }

  /** 获取检查任务详情（含问题列表） */
  async getCheckTask(taskId: string): Promise<CodeArtsResult<CodeArtsCheckTask>> {
    return codeArtsClient.request<CodeArtsCheckTask>('codecheck', `/v2/{project_id}/tasks/${taskId}`)
  }

  // ==================== 编译构建（CloudBuild） ====================

  /** 列出构建任务 */
  async listBuildJobs(): Promise<CodeArtsResult<CodeArtsBuildJob[]>> {
    return codeArtsClient.request<CodeArtsBuildJob[]>('cloudbuild', '/v3/{project_id}/jobs')
  }

  /** 获取构建历史 */
  async listBuildHistory(jobId: string): Promise<CodeArtsResult<CodeArtsPipelineRun[]>> {
    return codeArtsClient.request<CodeArtsPipelineRun[]>('cloudbuild', `/v3/{project_id}/jobs/${jobId}/history`)
  }
}

const codeArtsApi = new CodeArtsApi()

export {
  CodeArtsApi, codeArtsApi,
  CodeArtsRepository, CodeArtsPipeline, CodeArtsPipelineRun,
  CodeArtsCheckTask, CodeArtsBuildJob, CodeArtsSeverity
}
