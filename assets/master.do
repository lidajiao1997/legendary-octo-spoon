* ============================================================
* master.do —— mgmt-thesis 主运行脚本（Stata 16 基线）
* ------------------------------------------------------------
* 用途：一个入口跑通全流程。先做环境自检（版本、外部包、路径、
*       log），再按所选路线调用对应分析模板。学生换论文只改本文件
*       的全局参数区，不动各模板内部。
* 所需数据格式：
*   路线 A/B：CSMAR 导出的若干 xlsx 原始表（表头格式见 data-schema.md）
*   路线 C  ：公司×年度面板 dta（含 id、year、政策年份、Y、控制变量）
*   路线 E  ：长格式日收益率 dta（stkcd t ret rm）+ 事件列表 dta
*   路线 D/F：Python 管线，不由本脚本调用（用法见各模板头部注释）
* 运行依赖：thesis_utils.ado（同目录）、各路线模板、reghdfe 等
* 预期输出：全程 log + 各路线的结果 xlsx / png（由模板产出）
* 用法：修改下方"全局参数区"后，在 Stata 里 do 本文件即可
* ============================================================

version 16
clear all
set more off

* ============================================================
* 全局参数区 —— 学生唯一需要修改的地方
* ============================================================

* 选路线：A 财务指标 / B 文本+专利 / C 政策评估DID / E 事件研究
* （D 问卷与 F 评价走 Python：见 survey_pipeline.py / entropy_topsis.py 头部说明）
global route = "A"

* 项目工作目录（数据、脚本、输出都放这里）
global projdir = "C:/Users/<用户名>/Desktop/<论文项目名>"

* 主数据文件名（各路线含义不同，见上方"所需数据格式"）
global datafile = "<主数据>.dta"

* 论文简称：用作 log 与输出文件前缀
global tag = "<论文简称>"

* ============================================================
* 以下为调度逻辑，通常无需修改
* ============================================================

* 载入通用工具程序（thesis_env / thesis_winsor / thesis_table / thesis_event）
do "C:/Users/<用户名>/skills/mgmt-thesis/assets/thesis_utils.ado"
* 若已把 thesis_utils.ado 装入 PERSONAL 目录，上面一行可改为注释

* 进入项目目录并自检
cd "$projdir"
if "$projdir" == "" | "$projdir" == "<论文项目名>" {
    di as error "请先在全局参数区设置 projdir（真实项目目录）"
    exit 198
}
global projdir = c(pwd)                              // thesis_table 依此锚定输出路径
thesis_env, logname("${tag}_分析") pkgs(outreg2)

* 按路线分发（模板文件与本脚本同目录时直接用文件名）
if "$route" == "A" | "$route" == "B" {
    di as result ">>> 运行路线 $route：财务指标/文本词频 → 绩效/创新 全流程"
    do "pipeline_template.do"
}
else if "$route" == "C" {
    di as result ">>> 运行路线 C：政策评估 DID 全流程"
    do "did_template.do"
}
else if "$route" == "E" {
    di as result ">>> 运行路线 E：事件研究 CAR 全流程"
    do "event_study_template.do"
}
else {
    di as error "未识别的路线：$route（可选 A/B/C/E；D/F 请用 Python 脚本）"
    exit 198
}

di as result ">>> 路线 $route 运行结束。请检查输出文件与 log，对照 references/ 中该路线的合格线清单。"
log close
