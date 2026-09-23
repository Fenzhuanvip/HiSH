import { atomGitClient } from './AtomGitClient';
import { ApiResult, AtomGitUser, AtomGitRepo, AtomGitPR, AtomGitIssue, AtomGitRun, AtomGitJob, AtomGitBranch } from './types';

/**
 * AtomGit API v5 接口封装
 * 端点风格与 GitHub API v5 兼容
 */
class AtomGitApi {

  // ==================== 用户 ====================

  /** 获取当前认证用户 */
  async getCurrentUser(): Promise<ApiResult<AtomGitUser>> {
    return atomGitClient.get<AtomGitUser>('/user');
  }

  // ==================== 仓库 ====================

  /** 列出当前用户的仓库 */
  async listRepos(page: number = 1, perPage: number = 30): Promise<ApiResult<AtomGitRepo[]>> {
    return atomGitClient.get<AtomGitRepo[]>('/user/repos', { page: String(page), per_page: String(perPage) });
  }

  /** 获取仓库详情 */
  async getRepo(owner: string, repo: string): Promise<ApiResult<AtomGitRepo>> {
    return atomGitClient.get<AtomGitRepo>(`/repos/${owner}/${repo}`);
  }

  /** 列出仓库分支 */
  async listBranches(owner: string, repo: string): Promise<ApiResult<AtomGitBranch[]>> {
    return atomGitClient.get<AtomGitBranch[]>(`/repos/${owner}/${repo}/branches`);
  }

  // ==================== Pull Request（代码检视） ====================

  /** 列出仓库 PR */
  async listPRs(owner: string, repo: string, state: string = 'open'): Promise<ApiResult<AtomGitPR[]>> {
    return atomGitClient.get<AtomGitPR[]>(`/repos/${owner}/${repo}/pulls`, { state });
  }

  /** 获取 PR 详情 */
  async getPR(owner: string, repo: string, number: number): Promise<ApiResult<AtomGitPR>> {
    return atomGitClient.get<AtomGitPR>(`/repos/${owner}/${repo}/pulls/${number}`);
  }

  // ==================== Issue ====================

  /** 列出仓库 Issue */
  async listIssues(owner: string, repo: string, state: string = 'open'): Promise<ApiResult<AtomGitIssue[]>> {
    return atomGitClient.get<AtomGitIssue[]>(`/repos/${owner}/${repo}/issues`, { state });
  }

  // ==================== CI/CD 流水线（Actions Runs） ====================

  /** 列出仓库 workflow runs */
  async listRuns(owner: string, repo: string, page: number = 1, perPage: number = 30): Promise<ApiResult<AtomGitRun[]>> {
    return atomGitClient.get<AtomGitRun[]>(`/repos/${owner}/${repo}/actions/runs`, { page: String(page), per_page: String(perPage) });
  }

  /** 获取 workflow run 详情（含 jobs） */
  async getRun(owner: string, repo: string, runId: number): Promise<ApiResult<AtomGitRun>> {
    return atomGitClient.get<AtomGitRun>(`/repos/${owner}/${repo}/actions/runs/${runId}`);
  }

  /** 列出 run 的 jobs */
  async listRunJobs(owner: string, repo: string, runId: number): Promise<ApiResult<AtomGitJob[]>> {
    return atomGitClient.get<AtomGitJob[]>(`/repos/${owner}/${repo}/actions/runs/${runId}/jobs`);
  }
}

/** 全局单例 */
const atomGitApi = new AtomGitApi();

export { AtomGitApi, atomGitApi };
