# mgmt-thesis：管理类本科生毕业论文实证技能

面向**管理类/经管类本科毕业论文**的模块化实证技能（Skill）包，内置**六条实证路线**、学生选型引导流程、环境与数据权限定义，以及 7 个经合成数据端到端实测的代码模板。适用于 WorkBuddy 等 AI 助手环境，也可直接作为方法论讲义人工使用。

> 设计原则：所有 `references/` 是写给 AI（和学生）看的方法文档，所有 `assets/` 是占位符式代码模板——换一个「X 对 Y」的选题，只需替换变量名即可整条管线复用。

## 六条实证路线

| 路线 | 一句话模式 | 核心方法 | 代码模板 |
|------|-----------|---------|---------|
| A 财务指标型 | 现成指标 X → 绩效 Y + 调节 | 双向固定效应面板 | `pipeline_template.do` |
| B 文本+专利型 | 年报词频 X → 专利 Y + 中介 | 面板 + 中介 + PSM | `pipeline_template.do` + `text_freq.py` |
| C 政策评估型 | 政策试点 → 企业结果 | DID / PSM-DID | `did_template.do` |
| D 问卷调研型 | 心理机制 X→M→Y | 信效度 + CFA + Bootstrap 中介 | `survey_pipeline.py` |
| E 事件研究型 | 事件的市场反应 | CAR + t 检验 | `event_study_template.do` |
| F 案例/评价型 | 深描个案 / 指数构造 | 案例范式 / 熵值法+TOPSIS | `entropy_topsis.py` |

六条路线共享同一套写作模板（章节对应表、假设句式、结果段落模板）与答辩自查清单。

## 目录结构

```
mgmt-thesis/
├── SKILL.md                    # 技能入口：触发描述、工作流路由、硬性约束
├── references/
│   ├── route-selection.md      # 选型入口：四步引导流程 + 决策树 + 错误选型预警
│   ├── env-and-data.md         # 软硬件环境定义 + 数据库权限矩阵（含免费降级替代）
│   ├── data-schema.md          # CSMAR 原始表头 → 变量映射、清洗缩尾规范
│   ├── pipeline.md             # 路线 A 九步实证流程详解
│   ├── route-text-patent.md    # 路线 B：文本词频、专利口径、中介、PSM
│   ├── route-did.md            # 路线 C：DID、平行趋势、安慰剂
│   ├── route-survey.md         # 路线 D：信效度、CFA/SEM、共同方法偏差
│   ├── route-event-study.md    # 路线 E：窗口设定、CAR 检验
│   ├── route-case-index.md     # 路线 F：案例范式、熵值法+TOPSIS
│   ├── chapter-map.md          # 章节 ↔ 检验对应、假设句式、结果段落模板
│   └── defense-checklist.md    # 盲审/答辩自查清单（通用 + 路线 D 专查）
└── assets/
    ├── pipeline_template.do    # 路线 A/B do 骨架（占位符式）
    ├── did_template.do         # 路线 C DID 全流程（含平行趋势 coefplot）
    ├── survey_pipeline.py      # 路线 D 全管线：信度→KMO→CFA→Harman→回归→Bootstrap
    ├── event_study_template.do # 路线 E 事件研究 CAR
    ├── text_freq.py            # 路线 B 年报 MD&A 词频（jieba，双口径）
    └── entropy_topsis.py       # 路线 F 熵值法+TOPSIS（支持正/负向指标）
```

## 快速开始

**作为 AI 技能（WorkBuddy 等）**：将整个 `mgmt-thesis/` 目录放入用户级技能目录（如 `~/.workbuddy/skills/`），对助手说「毕业论文怎么选题」「帮我做 DID」「问卷数据怎么分析」等即可触发；助手会先走选型流程，再按路线加载对应方法文档与代码模板。

**作为人工讲义**：按 `route-selection.md` 的四步流程带学生选题 → 按 `env-and-data.md` 做数据可行性检查与环境预检 → 按路线 reference 中的「合格线」清单反查选题 → 复制 assets 模板替换 `<占位符>` 开跑。

**环境要求**：Stata 12+（模板按 Stata 16 语法书写，依赖 reghdfe/ftools/estout/outreg2）；Python 3.9+（pandas/numpy/jieba/semopy，详单见 `references/env-and-data.md`）。数据库权限要求与免费替代方案同见该文件。

## 代码模板实测状态

以下模板均已用合成数据端到端实测通过（Stata 16 / Python 3.13）：

- `survey_pipeline.py`：400 人合成问卷，α≈0.79、KMO 0.84、CFI 0.99、Bootstrap 中介显著
- `did_template.do` 核心逻辑：200 公司×10 年多期 DID，基准系数与平行趋势均符合预期
- `event_study_template.do` 核心逻辑：60 事件 CAR(-1,+1) 检验显著，与注入信号一致
- `text_freq.py` / `entropy_topsis.py`：词频构造与综合评价排序均通过效度验证

## 合规声明（数据使用）

- 本仓库**只包含方法文档、代码模板与占位符**，不含任何 CSMAR/Wind/CNRDS 等商业数据库的原始数据或导出数据
- 使用者自行获取数据，须遵守所在机构数据库许可协议；商业数据**严禁**二次分发
- 年报文本（巨潮资讯网）、政策试点名单（政府文件）、统计年鉴（统计局官网）为公开免费来源；问卷数据须由使用者自行收集并遵守研究伦理
- 本技能仅用于教学与研究方法学习，不构成任何投资建议

## License

MIT，详见 [LICENSE](LICENSE)。
