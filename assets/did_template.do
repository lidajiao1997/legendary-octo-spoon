* ============================================================
* 文件名：did_template.do
* 用途　：路线 C 政策评估 DID 全流程——处理组构造 → 基准双向
*         固定效应 → 平行趋势检验（coefplot）→ 稳健性（PSM-DID、
*         安慰剂）→ 机制与异质性。
* ------------------------------------------------------------
* 所需数据格式：
*   公司×年度面板 dta，必需字段：id（数值个体号）、year、
*   被解释变量 Y、控制变量；处理组信息两种给法之一：
*   ① 处理组指示 + 各自政策年份（推荐）② 处理组名单清单另表
* 运行依赖：
*   Stata 16+；reghdfe（高维固定效应）、coefplot（平行趋势图）、
*   psmatch2（PSM-DID，可选）；本目录 thesis_utils.ado
* 预期输出：
*   DID分析_时间戳.log      全程日志
*   DID基准回归.xlsx        基准结果表
*   平行趋势检验.png        事件研究图（政策前系数应围绕 0）
*   DID最终数据集.dta       分析数据
* 用法　：替换 <...> 后运行；多期 DID（不同个体不同政策年）与单期
*         DID 都适用；建议由 master.do 调度
* ============================================================

version 16
clear all
set more off

* ---- 0. 环境自检 ----
capture program which thesis_env
if _rc != 0 do "thesis_utils.ado"
cd "C:/Users/<用户名>/Desktop/<论文项目名>"
global projdir = c(pwd)                              // 记住项目目录：thesis_table 用它锚定输出路径，防 CWD 漂移
thesis_env, logname("DID分析") pkgs(reghdfe coefplot)

* ---- 1. 载入面板，构造处理组与政策时点 ----
use "<面板数据>.dta", clear
xtset id year                                    // 声明面板：个体 id + 时间 year

* 多期 DID 核心：每个处理个体按自己的政策时点开工
* treat = 是否最终进入处理组（恒定属性）；post = 该年是否已受政策影响
gen treat = 0
replace treat = 1 if <处理组条件，如城市在试点名单>
gen post   = (year >= <该个体政策年份>) if !missing(<政策年份>)
replace post = 0 if missing(post)                // 对照组（无政策年份）各期都算 0
gen did = treat * post                           // DID 交互项：系数即政策平均处理效应

* ---- 2. 基准回归：双向固定效应 + 公司聚类标准误 ----
* absorb(id year) 等价于公司+年度两组虚拟变量；cluster(id) 允许
* 同一公司逐年残差相关，是政策评估的标准误配置
reghdfe <Y> did <控制变量列表>, absorb(id year) vce(cluster id)
estimates store base

thesis_table base using "DID基准回归.xlsx", title("DID基准回归结果") replace

* ---- 3. 平行趋势检验（DID 的生命线）----
* 思路：把「政策前后」拆成相对时间虚拟变量，若政策前系数不显著
* 区别于 0，说明处理组与对照组在政策前走势一致，DID 可信
gen rel = year - <政策年份> if treat == 1
replace rel = 0 if treat == 0 & missing(rel)     // 对照组并入各期虚拟变量取 0

* 生成 pre5-pre2 / current / post1-post5（基准期 = 政策前一期 -1）
thesis_event rel, pre(5) post(5) controlgroup(treat)
* pre5 至 pre2 若要逐年区分（而非累计），把生成式改为 (rel == -`k')，
* 见 thesis_event 源码注释；窗口长度按数据跨度调整

reghdfe <Y> pre5 pre4 pre3 pre2 current post1-post5 <控制变量列表>, ///
    absorb(id year) vce(cluster id)
* 图形解读：政策前（pre*）置信区间应跨 0；current 起系数转正且增大
coefplot, keep(pre5 pre4 pre3 pre2 current post1-post5) vertical ///
    yline(0, lp(dash)) xline(4.5, lp(dash)) ///   // xline 标出政策发生位置
    ciopts(recast(rcap)) ///
    title("平行趋势检验") xtitle("相对政策时点") ytitle("系数")
graph export "平行趋势检验.png", replace

* ---- 4. 稳健性 ----
* a. PSM-DID：先用匹配压缩组间可观测差异，再在匹配样本上跑 DID
capture which psmatch2
if _rc != 0 di as error "缺少 psmatch2，请手动: ssc install psmatch2, replace"
foreach y in <年份区间> {
    * psmatch2 treat <控制变量列表> if year == `y', outcome(<Y>) logit neighbor(1) common
}
* pstest <控制变量列表>, both      // 平衡性检验：匹配后各组间差异应不显著
* 用匹配样本重跑基准
* reghdfe <Y> did <控制变量列表> if _support == 1, absorb(id year) vce(cluster id)

* b. 安慰剂：随机打乱处理组（循环 500 次，记录伪 did 系数分布）
* 伪代码：随机抽取与真实处理组同数量的公司设为伪处理组重跑基准，
* 画伪系数分布图——真实系数应落在分布尾部，否则结果可能是噪音

* c. 排除同期政策 / 替换被解释变量 / 剔除特殊年份（如 2020）
* gen other_policy = ...；reghdfe <Y> did other_policy ..., absorb(id year)

* ---- 5. 机制与异质性（复用 A/B 路线方法）----
* 中介：三步法（原理与代码见 references/route-text-patent.md 第 3 节）
* 异质性：东中西 / 产权 / 规模分组回归，写法同 pipeline_template.do 第 10 节

save "DID最终数据集.dta", replace
log close
di as result ">>> DID 运行完毕。自查：平行趋势前系数是否不显著？基准系数方向是否与理论一致？安慰剂是否通过？"
