# mgmt-thesis：管理类本科生毕业论文实证技能

面向**管理类/经管类本科毕业论文**的模块化实证技能（Skill）包：内置**六条实证路线**、学生选型引导、环境与数据权限定义、**六份计量原理教学文档**，以及经合成数据实测的代码模板（含主运行脚本 master.do 与通用 ado 工具集）。既是 AI 助手技能，也是可自学的方法论教材。

## 六条实证路线

| 路线 | 一句话模式 | 核心方法 | 代码模板 | 原理文档 |
|------|-----------|---------|---------|---------|
| A 财务指标型 | 现成指标 X → 绩效 Y + 调节 | 双向固定效应面板 | `pipeline_template.do` | `principles-financial.md` |
| B 文本+专利型 | 年报词频 X → 专利 Y + 中介 | 面板 + 中介 + PSM | `pipeline_template.do` + `text_freq.py` | `principles-text-patent.md` |
| C 政策评估型 | 政策试点 → 企业结果 | DID / PSM-DID | `did_template.do` | `principles-did.md` |
| D 问卷调研型 | 心理机制 X→M→Y | 信效度 + CFA + Bootstrap 中介 | `survey_pipeline.py` | `principles-survey.md` |
| E 事件研究型 | 事件的市场反应 | CAR + t 检验 | `event_study_template.do` | `principles-event-study.md` |
| F 案例/评价型 | 深描个案 / 指数构造 | 案例范式 / 熵值法+TOPSIS | `entropy_topsis.py` | `principles-case-index.md` |

## 目录结构

```
mgmt-thesis/
├── SKILL.md                    # 技能入口：触发描述、工作流路由、硬性约束
├── README.md                   # 本文件：安装/配置/数据准备分步指南
├── references/                 # 方法文档（选型、环境权限、路线方法、原理教学、写作答辩）
└── assets/                     # 代码资产（master.do、thesis_utils.ado、6 个路线模板）
```

## 第一步：安装

### 方式一：作为 AI 技能（WorkBuddy 等）

1. 将整个 `mgmt-thesis/` 目录复制到用户级技能目录（如 `~/.workbuddy/skills/`）
2. 重启会话后对助手说「毕业论文怎么选题」「帮我做 DID」「问卷数据怎么分析」等即可触发
3. 助手会先走选型流程（`route-selection.md`），再按路线加载方法文档与代码模板

### 方式二：作为人工讲义 / Stata 工具（不依赖 AI）

1. 新建论文项目文件夹，如 `D:/论文项目/`
2. 将 `assets/` 下所有文件复制进项目文件夹
3. 打开 Stata，把通用程序装进个人目录（一次即可）：
   ```stata
   di c(sysdir_personal)          // 查看 PERSONAL 目录位置
   * 把 thesis_utils.ado 复制到该目录；此后任何 do 文件可直接调用
   ```
4. 从 `master.do` 开始（见下一步配置）

## 第二步：配置

`master.do` 是唯一入口，学生只需要改开头的**全局参数区**：

1. `global route`：选路线（A/B/C/E；D 问卷与 F 评价走 Python 脚本）
2. `global projdir`：项目目录绝对路径
3. `global datafile`：主数据文件名
4. `global tag`：论文简称（用作输出前缀）

然后在 Stata 中 `do master.do`。脚本会自动：载入 `thesis_utils.ado` → 版本检查（<16 直接报错）→ 检查外部包并给出安装命令 → 开带时间戳的 log → 调用所选路线模板。

> 每个 do 模板也可独立运行：模板头部注释块写明了用途、数据格式、依赖与预期输出；模板内部已含同样的环境自检。

## 第三步：数据准备

按路线准备（详细列名映射与清洗规范见 `references/data-schema.md`）：

- **路线 A/B**：CSMAR 导出的 xlsx 原始表若干（每表一个指标，中文表头：证券代码/统计截止日期/指标列）。放入项目目录的 `data/` 子文件夹
- **路线 C**：公司×年度面板 dta（必需字段：id、year、被解释变量、控制变量、处理组指示、各自政策年份）。试点名单从政府文件整理
- **路线 E**：①长格式日收益率 dta（stkcd、t 交易日序号、ret、rm）②事件列表 dta（stkcd、ev_id、event_t）
- **路线 D**：问卷星导出 csv（列名为题项编码 X1..、M1..、Y1..与控制变量），运行：
  `python survey_pipeline.py 数据.csv 输出.md`
- **路线 F 评价支线**：城市/公司 × 指标的 csv，运行：
  `python entropy_topsis.py 数据.csv ID列名 "指标1,+;指标2,+;指标3,-"`
- **路线 B 文本部分**：巨潮资讯网（免费）按代码+年份下载年报 txt/pdf，放入 `reports/`，运行：
  `python text_freq.py reports ai_freq.csv`

## 环境要求

- **Stata 12+**（模板按 Stata 16 语法书写，开头有 `version 16` 检查）：路线 A/B/C/E。外部包 reghdfe、ftools、estout、outreg2、coefplot、psmatch2（可选）——脚本会自检并提示安装命令
- **Python 3.9+**：路线 B/D/F。依赖 pandas、numpy、jieba（B）、semopy（D）；问卷管线的 KMO/Harman 已内置纯 numpy 实现，无需 factor_analyzer
- 数据库权限要求与**免费替代方案**（巨潮年报、政府试点名单、统计年鉴均免费）见 `references/env-and-data.md`

## 学习路径建议（给学生）

1. 读 `references/route-selection.md` 定路线 → 2. 读对应 `references/principles-*.md` 明白方法原理 → 3. 按 `references/route-*.md` 与 `references/pipeline.md` 跑通代码 → 4. 用 `references/chapter-map.md` 写章节 → 5. 交稿前过 `references/defense-checklist.md`

## 代码实测状态

- `thesis_utils.ado` 四程序（env/winsor/table/event）已实测：版本检查、1%/99% 缩尾、outreg2 输出路径锚定、相对时间虚拟变量全部通过
- `survey_pipeline.py`：400 人合成问卷全管线通过（α≈0.79、KMO 0.84、CFI 0.99、Bootstrap 中介显著）
- `did_template.do` / `event_study_template.do` / `pipeline_template.do` 核心逻辑：合成数据实测，系数方向与注入真值一致
- `text_freq.py` / `entropy_topsis.py`：词频构造与综合评价排序均通过效度验证

## 合规声明（数据使用）

- 本仓库**只包含方法文档、代码模板与占位符**，不含任何 CSMAR/Wind/CNRDS 等商业数据库的原始数据或导出数据
- 使用者自行获取数据，须遵守所在机构数据库许可协议；商业数据**严禁**二次分发
- 年报文本（巨潮资讯网）、政策试点名单（政府文件）、统计年鉴（统计局官网）为公开免费来源；问卷数据须自行收集并遵守研究伦理
- 本技能仅用于教学与研究方法学习，不构成任何投资建议

## License

MIT，详见 [LICENSE](LICENSE)。
