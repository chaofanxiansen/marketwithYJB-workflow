---
name: market-report-deployer
description: "复盘报告部署上线工具。当用户要求\"部署\"\"上线\"\"发布报告\"\"推送报告\"\"更新网页\"，或需要把生成的 HTML 复盘报告发布到 reports.239952.xyz 时使用。本 skill 负责：通过 GitHub MCP API 推送 index.html + 日期归档到 chaofanxiansen/reports 仓库，触发 Cloudflare Pages 自动构建，并同步历史下拉列表。触发词：部署、上线、发布、推送、更新网页、发链接。"
compatibility: "需 GitHub MCP API（github_create_or_update_file / github_push_files）；Cloudflare Pages 已绑定 reports 仓库自动构建"
---

# Market Report Deployer

复盘工作流的第三步：把报告送上云端。本地生成完 HTML 后，本 skill 负责推送、触发构建、验证上线，全程不需要本地 git。

## 部署架构

```
本地 deploy_reports/  →  GitHub API 推送（chaofanxiansen/reports main）  →  Cloudflare Pages 自动构建（1-2分钟）  →  https://reports.239952.xyz
```

## 部署流程

### 1. 准备文件

报告已由 market-review-reporter 生成在 `D:\HanakoDate\deploy_reports\`：

- `index.html` — 最新报告（Cloudflare Pages 入口）
- `2026-08-XX.html` — 同日日期归档（历史记录用）

### 2. 推送文件（GitHub MCP API）

**单文件更新**（index.html 已存在）：

1. 先 `github_get_file_contents` 获取当前 SHA（owner=chaofanxiansen, repo=reports, path=index.html, ref=main）
2. `github_create_or_update_file` 推送，必须带 `sha` 参数，否则报 "File already exists"

```json
{
  "owner": "chaofanxiansen", "repo": "reports", "branch": "main",
  "path": "index.html", "message": "复盘报告 2026-08-XX",
  "content": "<完整HTML>", "sha": "<上一步拿到的SHA>"
}
```

**多文件同时推送**（index + 归档一起）：

用 `github_push_files` 一次提交（files 数组含 path+content，无需 SHA）：

```json
{
  "owner": "chaofanxiansen", "repo": "reports", "branch": "main",
  "message": "复盘报告 2026-08-XX + 归档",
  "files": [{"path": "index.html", "content": "..."}, {"path": "2026-08-XX.html", "content": "..."}]
}
```

> 注意：github_push_files 可能触发人工审批（写操作），审批通过后才会真正推送。

### 3. 历史下拉列表同步（重要）

每个 HTML 页面右上角「历史」按钮列出所有已发布报告。**新报告发布时：**

- 新报告自身：当前页标记 `class="current"`，列表含全部历史日期
- 历史文件：如需保留，同步更新它们的下拉列表加入新日期；如用户只要最新一份，列表只留当前页即可（避免死链）
- 线上已删除的历史文件不要在列表里引用，否则点击 404

### 4. 验证上线

- 推送成功后用 `web_fetch` 访问 `https://reports.239952.xyz` 验证新数据已生效
- Cloudflare Pages 构建有延迟（约 1-2 分钟），刚推送后可能仍显示旧版，稍等重试
- 用 `github_get_file_contents` 确认仓库文件已更新

## 本地备份

- 报告文件固定写入 `D:\HanakoDate\deploy_reports\`（index.html + 日期归档）
- 该目录是本地 git 仓库，但部署不依赖它（走 MCP API）

## 常见问题

| 问题 | 处理 |
|------|------|
| "File already exists at index.html" | 缺 SHA，先 github_get_file_contents 拿当前 SHA 再传 |
| push_files 需要审批 | 写操作会触发审批，通过后执行；审批失败则改用 create_or_update_file 单文件 |
| 网页仍显示旧版 | Cloudflare 构建延迟，等 1-2 分钟重新验证 |
| 历史链接 404 | 引用了不存在的文件，列表只保留实际存在的文件 |
| 另一个会话同时在推 | 先查提交历史（github_list_commits），避免覆盖对方；推送后确认最终状态 |

## 交付

部署成功后，把链接 `https://reports.239952.xyz` 发给用户。
