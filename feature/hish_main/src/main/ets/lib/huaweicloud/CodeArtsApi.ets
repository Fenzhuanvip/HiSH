import http from '@ohos.net.http';
import { codeArtsClient, CodeArtsResult } from './CodeArtsClient';

/**
 * CodeArts 各子服务 API 封装
 * 端点基于华为云 OpenAPI 文档惯例，{project_id} 由 CodeArtsClient 自动替换
 * 纯 CodeArts 架构：仓库/流水线/检查/构建全部走 CodeArts API（IAM token 认证）
 */

// ==================== 类型定义 ====================

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

/** 仓库分支 */
interface CodeArtsBranch {
  name: string
  commitId: string
  lastCommitMessage: string
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

/** 流水线步骤 */
interface CodeArtsPipelineStep {
  id: string
  name: string
  status: string
  startTime: string
  endTime: string
  type: string
  logUrl: string
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

/** 代码检查问题 */
interface CodeArtsCheckIssue {
  id: string
  taskId: string
  filePath: string
  line: number
  column: number
  rule: string
  severity: string
  message: string
  suggestion: string
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

/** 构建记录 */
interface CodeArtsBuildRecord {
  id: string
  jobId: string
  buildNumber: number
  status: string
  startTime: string
  endTime: string
  trigger: string
  branch: string
}

// ==================== API 实现 ====================

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

  /** 列出仓库分支 */
  async listBranches(repoId: string): Promise<CodeArtsResult<CodeArtsBranch[]>> {
    return codeArtsClient.request<CodeArtsBranch[]>('codehub', `/v1/{project_id}/repositories/${repoId}/branches`)
  }

  // ==================== 流水线（Pipeline） ====================

  /** 列出流水线 */
  async listPipelines(): Promise<CodeArtsResult<CodeArtsPipeline[]>> {
    return codeArtsClient.request<CodeArtsPipeline[]>('pipeline', '/v3/{project_id}/pipelines')
  }

  /** 获取流水线详情 */
  async getPipeline(pipelineId: string): Promise<CodeArtsResult<CodeArtsPipeline>> {
    return codeArtsClient.request<CodeArtsPipeline>('pipeline', `/v3/{project_id}/pipelines/${pipelineId}`)
  }

  /** 列出流水线运行记录 */
  async listPipelineRuns(pipelineId: string): Promise<CodeArtsResult<CodeArtsPipelineRun[]>> {
    return codeArtsClient.request<CodeArtsPipelineRun[]>('pipeline', `/v3/{project_id}/pipelines/${pipelineId}/runs`)
  }

  /** 获取流水线运行详情 */
  async getPipelineRun(pipelineId: string, runId: string): Promise<CodeArtsResult<CodeArtsPipelineRun>> {
    return codeArtsClient.request<CodeArtsPipelineRun>('pipeline', `/v3/{project_id}/pipelines/${pipelineId}/runs/${runId}`)
  }

  /** 触发流水线运行 */
  async startPipelineRun(pipelineId: string, branch?: string): Promise<CodeArtsResult<CodeArtsPipelineRun>> {
    const body: Record<string, string> = {}
    if (branch && branch.length > 0) {
      body['branch'] = branch
    }
    return codeArtsClient.request<CodeArtsPipelineRun>(
      'pipeline', `/v3/{project_id}/pipelines/${pipelineId}/runs`, http.RequestMethod.POST, body
    )
  }

  /** 获取流水线运行的步骤列表 */
  async listPipelineSteps(pipelineId: string, runId: string): Promise<CodeArtsResult<CodeArtsPipelineStep[]>> {
    return codeArtsClient.request<CodeArtsPipelineStep[]>(
      'pipeline', `/v3/{project_id}/pipelines/${pipelineId}/runs/${runId}/steps`
    )
  }

  /** 获取流水线步骤日志 */
  async getPipelineStepLog(pipelineId: string, runId: string, stepId: string): Promise<CodeArtsResult<string>> {
    return codeArtsClient.request<string>(
      'pipeline', `/v3/{project_id}/pipelines/${pipelineId}/runs/${runId}/steps/${stepId}/log`
    )
  }

  /** 停止流水线运行 */
  async stopPipelineRun(pipelineId: string, runId: string): Promise<CodeArtsResult<null>> {
    return codeArtsClient.request<null>(
      'pipeline', `/v3/{project_id}/pipelines/${pipelineId}/runs/${runId}/stop`, http.RequestMethod.POST
    )
  }

  // ==================== 代码检查（CodeCheck） ====================

  /** 列出代码检查任务 */
  async listCheckTasks(): Promise<CodeArtsResult<CodeArtsCheckTask[]>> {
    return codeArtsClient.request<CodeArtsCheckTask[]>('codecheck', '/v2/{project_id}/tasks')
  }

  /** 获取检查任务详情 */
  async getCheckTask(taskId: string): Promise<CodeArtsResult<CodeArtsCheckTask>> {
    return codeArtsClient.request<CodeArtsCheckTask>('codecheck', `/v2/{project_id}/tasks/${taskId}`)
  }

  /** 触发代码检查任务 */
  async startCheckTask(taskId: string): Promise<CodeArtsResult<CodeArtsCheckTask>> {
    return codeArtsClient.request<CodeArtsCheckTask>(
      'codecheck', `/v2/{project_id}/tasks/${taskId}/start`, http.RequestMethod.POST
    )
  }

  /** 获取代码检查问题列表 */
  async listCheckIssues(taskId: string): Promise<CodeArtsResult<CodeArtsCheckIssue[]>> {
    return codeArtsClient.request<CodeArtsCheckIssue[]>('codecheck', `/v2/{project_id}/tasks/${taskId}/issues`)
  }

  // ==================== 编译构建（CloudBuild） ====================

  /** 列出构建任务 */
  async listBuildJobs(): Promise<CodeArtsResult<CodeArtsBuildJob[]>> {
    return codeArtsClient.request<CodeArtsBuildJob[]>('cloudbuild', '/v3/{project_id}/jobs')
  }

  /** 获取构建任务详情 */
  async getBuildJob(jobId: string): Promise<CodeArtsResult<CodeArtsBuildJob>> {
    return codeArtsClient.request<CodeArtsBuildJob>('cloudbuild', `/v3/{project_id}/jobs/${jobId}`)
  }

  /** 获取构建历史 */
  async listBuildHistory(jobId: string): Promise<CodeArtsResult<CodeArtsBuildRecord[]>> {
    return codeArtsClient.request<CodeArtsBuildRecord[]>('cloudbuild', `/v3/{project_id}/jobs/${jobId}/history`)
  }

  /** 触发构建任务 */
  async startBuildJob(jobId: string, branch?: string): Promise<CodeArtsResult<CodeArtsBuildRecord>> {
    const body: Record<string, string> = {}
    if (branch && branch.length > 0) {
      body['branch'] = branch
    }
    return codeArtsClient.request<CodeArtsBuildRecord>(
      'cloudbuild', `/v3/{project_id}/jobs/${jobId}/build`, http.RequestMethod.POST, body
    )
  }

  /** 获取构建日志 */
  async getBuildLog(jobId: string, buildNumber: number): Promise<CodeArtsResult<string>> {
    return codeArtsClient.request<string>(
      'cloudbuild', `/v3/{project_id}/jobs/${jobId}/builds/${buildNumber}/log`
    )
  }

  /** 停止构建 */
  async stopBuildJob(jobId: string, buildNumber: number): Promise<CodeArtsResult<null>> {
    return codeArtsClient.request<null>(
      'cloudbuild', `/v3/{project_id}/jobs/${jobId}/builds/${buildNumber}/stop`, http.RequestMethod.POST
    )
  }
}

const codeArtsApi = new CodeArtsApi()

export {
  CodeArtsApi, codeArtsApi,
  CodeArtsRepository, CodeArtsBranch,
  CodeArtsPipeline, CodeArtsPipelineRun, CodeArtsPipelineStep,
  CodeArtsCheckTask, CodeArtsCheckIssue, CodeArtsSeverity,
  CodeArtsBuildJob, CodeArtsBuildRecord
}
