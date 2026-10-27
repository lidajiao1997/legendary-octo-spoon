---
name: mgmt-thesis
description: 管理类本科生实证论文全流程技能，内置六条实证路线与选型流程。当用户需要撰写管理类/经管类本科毕业论文、为学生选择论文路线或完成实证部分时使用。路线 A（财务指标型）：CSMAR 多表合并清洗、基准回归、稳健性、内生性、调节效应与异质性；路线 B（文本/专利型）：年报文本词频构造解释变量、专利数据构造被解释变量、中介效应、PSM；路线 C（政策评估型）：DID/PSM-DID、平行趋势、安慰剂检验；路线 D（问卷调研型）：信效度、CFA/SEM、Bootstrap 中介、共同方法偏差；路线 E（事件研究型）：CAR 计算与检验；路线 F（案例/评价型）：案例研究范式、熵值法+TOPSIS。另含 outreg2 表格导出、论文章节写作要点与盲审答辩清单。触发场景包括"毕业论文怎么选题""帮学生选论文路线""管理类论文怎么写""组织行为学论文""领导风格""员工行为""合并国泰安数据""调节效应""中介效应""DID""平行趋势""问卷数据分析""问卷调研""量表""信度效度""共同方法偏差""事件研究""CAR""案例研究""熵值法""TOPSIS""稳健性检验""内生性处理""论文表格导出"等。
agent_created: true
---

# 管理类本科生论文技能（mgmt-thesis）

## 概述

按管理类本科实证论文的标准范式，指导完成从数据到成稿的全流程。范式蓝本：高管薪酬 → 企业绩效，研发投入/行业竞争为调节变量，东中西部为异质性分组。该范式可平移到绝大多数「X 对 Y 的影响」型管理类论文（股权结构、ESG、数字化转型、融资约束等对绩效/创新/投资的影响）。

## 工作流总览

按论文阶段路由到对应 reference，按执行步骤使用 assets 模板：

| 阶段 | 用户需求示例 | 去处 |
|------|------------|------|
| **选型入口** | 「毕业论文怎么选题」「帮我定路线」「学生想做问卷/DID/案例」 | **先读 references/route-selection.md**，走四步引导流程定路线，再转接下表 |
| **环境与数据预检** | 「学校有什么数据库」「需要装什么软件」「数据拿不到怎么办」 | 读 references/env-and-data.md（数据库权限矩阵、六路线软硬件门槛、本机执行环境约定） |
| 路线 A：财务指标型 | 「X 对绩效的影响」现成 CSMAR 指标 | 读 references/pipeline.md + data-schema.md |
| 路线 B：文本+专利型 | 「AI/数字化转型对创新的影响」 | 读 references/route-text-patent.md |
| 路线 C：政策评估型 | 「某试点政策对企业的影响」「DID」 | 读 references/route-did.md，改 assets/did_template.do |
| 路线 D：问卷调研型 | 「问卷数据分析」「信效度」「SEM」 | 读 references/route-survey.md，跑 assets/survey_pipeline.py |
| 路线 E：事件研究型 | 「公告的市场反应」「CAR」 | 读 references/route-event-study.md，改 assets/event_study_template.do |
| 路线 F：案例/评价型 | 「案例研究怎么写」「熵值法」「TOPSIS」 | 读 references/route-case-index.md |
| 通用数据清洗 | 合并 CSMAR 表、缩尾、取年报 | 读 references/data-schema.md（A/B/C/E 共用） |
| 论文写作 | 章节 structure、假设表述、结果解读 | 读 references/chapter-map.md |
| 质量把关 | 盲审/答辩前自查 | 读 references/defense-checklist.md |

## 执行规则

1. **先确认论文三要素**再动代码：解释变量 X、被解释变量 Y、调节/分组变量。用户没给就用提问澄清，不要擅自假设。
2. **数据结构默认面板**：公司 × 年度（code year），取年报数据（month==12），合并用 `1:1 code year`，`keep if _merge == 3`。
3. **Stata 基准为 Stata 16**：do 文件开头写 `version 16`，不使用 16 之后的独有语法（collect、frame、java 等）。依赖外部包时先 `capture which`，缺则提示用户手动安装（网络安装可能被环境拦截）。
4. **分析顺序固定**：描述统计 → 相关系数 → VIF → 基准回归 → 稳健性 → 内生性 → 调节/异质性。顺序即论文章节顺序，不要乱。
5. **表格输出统一用 outreg2** 导出 xlsx，每张表 `addtext(年度固定效应, 是, 公司固定效应, 是)` 并给出中文标题，小数位 dec(4)。
6. **全程写 log**：脚本开头 `log using`，带时间戳命名，结束后 `log close`。
7. **用户偏好（硬性）**：只改指令涉及的部分，不碰无关代码；新文件不覆盖同名文件；分析结论与讲解必须保存为本地文件；结果表格用三线表规范呈现。

## 典型任务路由

- 「毕业论文怎么选题/定路线」→ route-selection.md 四步引导 + 决策树，落定后转对应路线 reference
- 「学校数据库/数据权限/免费数据」→ env-and-data.md 第二节权限矩阵（含无权限时的降级替代）
- 「要装什么软件/环境报错/Stata 批处理怎么跑」→ env-and-data.md 第一、三节
- 「帮我合并这些 CSMAR 的 excel」→ data-schema.md 的清洗管线 + pipeline_template.do 第 1-2 节
- 「做什么检验才够」→ 对应路线 reference 的合格线小节（A/B 通用底线见 pipeline.md：基准 + 2 项稳健性 + 1 项内生性 + 1 项机制或异质性）
- 「调节效应不显著怎么办」→ pipeline.md 第 8 节的备选方案（分组回归、滞后交互、连续变量 vs 虚拟变量）
- 「中介效应怎么做/被质疑怎么办」→ route-text-patent.md 第 3 节（含江艇 2022 答辩口径）；问卷中介走 route-survey.md Bootstrap
- 「平行趋势不平行/安慰剂怎么做」→ route-did.md 第 4-5 节
- 「问卷数据怎么分析/共同方法偏差」→ route-survey.md 第 3、5 节
- 「事件窗口怎么定/CAR 显著性」→ route-event-study.md 第 1、3 节
- 「这章怎么写」→ chapter-map.md 对应章节
- 「论文快交了帮我查一遍」→ defense-checklist.md 全表自查

## Resources

- `references/route-selection.md`：**入口**——六路线速查表、学生引导四步流程、选型决策树、错误选型预警
- `references/env-and-data.md`：软硬件环境定义（学生侧六路线门槛 + 执行侧本机约定）与数据库权限矩阵（数据源 × 路线 × 无权限降级方案）
- `references/data-schema.md`：CSMAR 原始表头 → Stata 变量命名映射、清洗与缩尾规范（A/B/C/E 共用）
- `references/pipeline.md`：路线 A 九步实证流程详解（其余路线共用其通用步骤）
- `references/route-text-patent.md`：路线 B——文本词频 X 构造、专利 Y 口径、中介效应与 PSM
- `references/route-did.md`：路线 C——DID/PSM-DID、平行趋势、安慰剂、进阶估计量提醒
- `references/route-survey.md`：路线 D——信效度、CFA/SEM、Bootstrap 中介、共同方法偏差
- `references/route-event-study.md`：路线 E——窗口设定、CAR 计算与检验
- `references/route-case-index.md`：路线 F——案例研究范式、熵值法+TOPSIS
- `references/chapter-map.md`：论文章节 ↔ 检验对应关系、假设提出写法、结果段落模板
- `references/defense-checklist.md`：盲审与答辩常见问题自查清单
- `assets/pipeline_template.do`：路线 A/B do 文件骨架（占位符式）
- `assets/did_template.do`：路线 C DID 全流程模板（含平行趋势 coefplot）
- `assets/survey_pipeline.py`：路线 D Python 分析管线（信度→KMO→CFA 拟合→Harman→回归→Bootstrap；已实测）
- `assets/event_study_template.do`：路线 E 事件研究 CAR 模板
- `assets/text_freq.py`：路线 B 年报 MD&A 词频构造脚本（jieba，双口径；已实测）
- `assets/entropy_topsis.py`：路线 F 熵值法+TOPSIS 综合评价脚本（已实测）

## 代码模板实测状态

survey_pipeline.py、text_freq.py、entropy_topsis.py 已用合成数据端到端实测；did_template.do 与 event_study_template.do 的核心逻辑（reghdfe 基准、相对时间事件研究、市场模型 CAR）已用 Stata 16 + 合成数据实测通过。模板均为占位符式骨架，学生需按选题填空；本机批处理运行 do 文件时需先 `sysdir set PLUS` 指向外部包目录（profile.do 在批处理下可能未生效）。
