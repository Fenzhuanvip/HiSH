/**
 * AtomGit API v5 类型定义
 * 对应 https://api.atomgit.com/api/v5
 */

/** 用户信息 */
interface AtomGitUser {
  id: string
  login: string
  name: string
  avatar_url: string
  html_url: string
  email: string
  bio: string
  company: string
  followers: number
  following: number
  created_at: string
  updated_at: string
  top_languages?: string[]
}

/** 仓库命名空间 */
interface RepoNamespace {
  id: number
  type: string
  name: string
  path: string
  html_url: string
}

/** 仓库权限 */
interface RepoPermission {
  pull: boolean
  push: boolean
  admin: boolean
}

/** 仓库信息 */
interface AtomGitRepo {
  id: number
  full_name: string
  name: string
  path: string
  description: string
  http_url_to_repo: string
  ssh_url_to_repo: string
  web_url: string
  html_url?: string
  default_branch: string
  language: string
  fork: boolean
  private: boolean
  public: boolean
  forks_count: number
  stargazers_count: number
  watchers_count: number
  open_issues_count: number
  created_at: string
  updated_at: string
  pushed_at: string
  namespace: RepoNamespace
  permission: RepoPermission
  parent?: AtomGitRepo
  owner?: AtomGitUser
}

/** PR 信息 */
interface AtomGitPR {
  id: number
  number: number
  title: string
  body: string
  state: string
  draft: boolean
  merged: boolean
  mergeable: boolean
  user: AtomGitUser
  created_at: string
  updated_at: string
  closed_at: string | null
  merged_at: string | null
  head: { ref: string; label: string; sha: string }
  base: { ref: string; label: string; sha: string }
  html_url: string
  commits_count?: number
  additions?: number
  deletions?: number
  changed_files?: number
}

/** Issue 信息 */
interface AtomGitIssue {
  id: number
  number: number
  title: string
  body: string
  state: string
  user: AtomGitUser
  created_at: string
  updated_at: string
  closed_at: string | null
  html_url: string
  labels: { id: number; name: string; color: string }[]
  assignees?: AtomGitUser[]
  comments_count?: number
}

/** 流水线运行状态 */
type RunStatus = 'success' | 'failure' | 'running' | 'queued' | 'canceled' | 'in_progress' | 'waiting' | 'pending'

/** Workflow Run（CI/CD 流水线运行） */
interface AtomGitRun {
  id: number
  name: string
  head_branch: string
  head_sha: string
  status: string
  conclusion: string | null
  event: string
  display_title: string
  html_url: string
  created_at: string
  updated_at: string
  run_started_at: string
  workflow_id: number
  run_number: number
  actor: AtomGitUser
}

/** 流水线 Job */
interface AtomGitJob {
  id: number
  name: string
  status: string
  conclusion: string | null
  started_at: string | null
  completed_at: string | null
  steps: { name: string; status: string; conclusion: string | null; number: number }[]
}

/** 分支信息 */
interface AtomGitBranch {
  name: string
  commit: { id: string; message: string; author: { name: string; email: string } }
  protected: boolean
}

/** API 分页响应包装 */
interface ApiResult<T> {
  data: T | null
  ok: boolean
  statusCode: number
  message?: string
}

export {
  AtomGitUser, AtomGitRepo, AtomGitPR, AtomGitIssue, AtomGitRun, AtomGitJob,
  AtomGitBranch, RepoNamespace, RepoPermission, RunStatus, ApiResult
}
