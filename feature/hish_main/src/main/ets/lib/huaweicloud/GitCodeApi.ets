import http from '@ohos.net.http';
import { gitCodeClient, GitCodeResult } from './GitCodeClient';

/**
 * GitCode（atomgit）API 封装
 * 端点：Gitea/Forgejo 风格 /api/v5
 * 认证：token 认证（在 GitCodeClient 里统一处理）
 */

// ==================== 类型定义 ====================

/** GitCode 仓库 */
interface GitCodeRepo {
  id: number
  name: string
  full_name: string
  description: string
  html_url: string
  ssh_url: string
  clone_url: string
  default_branch: string
  private: boolean
  stargazers_count: number
  forks_count: number
  open_issues_count: number
  open_pr_count: number
  updated_at: string
  created_at: string
  language: string
  owner: {
    login: string
    avatar_url: string
  }
}

/** GitCode PR */
interface GitCodePull {
  id: number
  number: number
  title: string
  body: string
  state: string
  user: {
    login: string
    avatar_url: string
  }
  created_at: string
  updated_at: string
  head: {
    ref: string
    label: string
  }
  base: {
    ref: string
    label: string
  }
  mergeable: boolean
  merged: boolean
  labels: GitCodeLabel[]
}

/** GitCode Issue */
interface GitCodeIssue {
  id: number
  number: number
  title: string
  body: string
  state: string
  user: {
    login: string
    avatar_url: string
  }
  created_at: string
  updated_at: string
  labels: GitCodeLabel[]
  assignee: {
    login: string
    avatar_url: string
  } | null
  comments: number
}

/** GitCode 标签 */
interface GitCodeLabel {
  id: number
  name: string
  color: string
}

/** GitCode 分支 */
interface GitCodeBranch {
  name: string
  commit: {
    id: string
    message: string
  }
}

// ==================== API 实现 ====================

class GitCodeApi {
  private currentRepo: string = ''  // owner/repo

  /** 设置当前操作的仓库 */
  setRepo(owner: string, repo: string): void {
    this.currentRepo = `${owner}/${repo}`
  }

  // ==================== 仓库 ====================

  /** 列出当前用户的仓库 */
  async listRepos(): Promise<GitCodeResult<GitCodeRepo[]>> {
    return gitCodeClient.request<GitCodeRepo[]>('/user/repos?sort=updated&per_page=50')
  }

  /** 获取仓库详情 */
  async getRepo(owner: string, repo: string): Promise<GitCodeResult<GitCodeRepo>> {
    return gitCodeClient.request<GitCodeRepo>(`/repos/${owner}/${repo}`)
  }

  /** 列出仓库分支 */
  async listBranches(owner: string, repo: string): Promise<GitCodeResult<GitCodeBranch[]>> {
    return gitCodeClient.request<GitCodeBranch[]>(`/repos/${owner}/${repo}/branches?per_page=50`)
  }

  // ==================== Pull Request ====================

  /** 列出仓库 PR */
  async listPulls(owner: string, repo: string, state: string = 'open'): Promise<GitCodeResult<GitCodePull[]>> {
    return gitCodeClient.request<GitCodePull[]>(`/repos/${owner}/${repo}/pulls?state=${state}&per_page=50`)
  }

  /** 获取 PR 详情 */
  async getPull(owner: string, repo: string, number: number): Promise<GitCodeResult<GitCodePull>> {
    return gitCodeClient.request<GitCodePull>(`/repos/${owner}/${repo}/pulls/${number}`)
  }

  // ==================== Issue ====================

  /** 列出仓库 Issues */
  async listIssues(owner: string, repo: string, state: string = 'open'): Promise<GitCodeResult<GitCodeIssue[]>> {
    return gitCodeClient.request<GitCodeIssue[]>(`/repos/${owner}/${repo}/issues?state=${state}&per_page=50`)
  }

  /** 获取 Issue 详情 */
  async getIssue(owner: string, repo: string, number: number): Promise<GitCodeResult<GitCodeIssue>> {
    return gitCodeClient.request<GitCodeIssue>(`/repos/${owner}/${repo}/issues/${number}`)
  }

  // ==================== 用户 ====================

  /** 获取当前用户信息 */
  async getCurrentUser(): Promise<GitCodeResult<{ login: string; name: string; avatar_url: string }>> {
    return gitCodeClient.request<{ login: string; name: string; avatar_url: string }>('/user')
  }
}

const gitCodeApi = new GitCodeApi()

export {
  GitCodeApi, gitCodeApi,
  GitCodeRepo, GitCodePull, GitCodeIssue, GitCodeLabel, GitCodeBranch
}
