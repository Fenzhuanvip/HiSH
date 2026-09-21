import http from '@ohos.net.http';
import { gitCodeClient, GitCodeResult } from './GitCodeClient';

/**
 * GitCode（atomgit）API 封装
 * 端点：Gitea/Forgejo 风格 /api/v5
 * 认证：token 认证（在 GitCodeClient 里统一处理）
 */

// ==================== 类型定义 ====================

/** GitCode 仓库所有者/用户基本信息 */
interface GitCodeOwner {
  login: string
  avatar_url: string
}

/** GitCode 分支引用 */
interface GitCodeRef {
  ref: string
  label: string
}

/** GitCode 提交信息 */
interface GitCodeCommit {
  id: string
  message: string
}

/** GitCode 当前用户信息 */
interface GitCodeUser {
  login: string
  name: string
  avatar_url: string
}

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
  owner: GitCodeOwner
}

/** GitCode PR */
interface GitCodePull {
  id: number
  number: number
  title: string
  body: string
  state: string
  user: GitCodeOwner
  created_at: string
  updated_at: string
  head: GitCodeRef
  base: GitCodeRef
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
  user: GitCodeOwner
  created_at: string
  updated_at: string
  labels: GitCodeLabel[]
  assignee: GitCodeOwner | null
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
  commit: GitCodeCommit
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
  async getCurrentUser(): Promise<GitCodeResult<GitCodeUser>> {
    return gitCodeClient.request<GitCodeUser>('/user')
  }
}

const gitCodeApi = new GitCodeApi()

export {
  GitCodeApi, gitCodeApi,
  GitCodeRepo, GitCodePull, GitCodeIssue, GitCodeLabel, GitCodeBranch,
  GitCodeOwner, GitCodeRef, GitCodeCommit, GitCodeUser
}
