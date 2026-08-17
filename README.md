# marketwithYJB-workflow

炒饭先生的每日市场复盘工作流（Market Review with YJB 养基宝），拆分为三个可复用的 Hana skills。

## 工作流

```
market-data-collector → market-review-reporter → market-report-deployer
       数据采集               报告生成                部署上线
```

## Skills

| Skill | 职责 | 触发 |
|-------|------|------|
| `market-data-collector` | A股+全球行情硬数据采集（脚本+消息面） | "拉数据""取数""今天大盘数据" |
| `market-review-reporter` | 六板块 HTML 复盘报告生成（含养基宝持仓规范） | "出报告""生成报告" |
| `market-report-deployer` | GitHub API 推送 + Cloudflare Pages 自动构建 | "部署""上线""发布" |

## 安装

每个 skill 是独立目录，含 SKILL.md + scripts/ + references/。将对应目录放入 Hana 的 skills 目录即可使用。

## 部署产物

- 报告站点：https://reports.239952.xyz
- 报告仓库：chaofanxiansen/reports（私有）
