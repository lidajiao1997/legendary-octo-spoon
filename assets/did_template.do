* ============================================================
* 路线 C：政策评估 DID 模板（Stata 16 基线）
* 用法：替换 <...> 占位符；新文件名勿覆盖已有产出；结论存本地文件
* ============================================================

version 16
clear all
set more off

cd "C:/Users/<用户名>/Desktop"
capture which reghdfe
if _rc != 0 di as error "缺少 reghdfe，请手动: ssc install reghdfe ftools, replace"
capture which coefplot
if _rc != 0 di as error "缺少 coefplot，请手动: ssc install coefplot, replace"

local date = subinstr("${S_DATE}", " ", "_", .)
log using "DID分析_<date>.log", text replace

* ---- 1. 面板数据（公司×年度），处理组名单按试点批次整理 ----
use "<面板数据>.dta", clear
xtset id year

* 多期 DID：各处理个体按自己的政策时点
gen treat = 0
replace treat = 1 if <处理组条件，如城市在试点名单>
gen post   = (year >= <该个体政策年份>) if !missing(<政策年份>)
replace post = 0 if missing(post)
gen did = treat * post

* ---- 2. 基准回归：双向固定效应 + 公司聚类 ----
reghdfe <Y> did <控制变量列表>, absorb(id year) vce(cluster id)
estimates store base

outreg2 [base] using "DID基准回归.xlsx", replace excel dec(4) ///
    addtext(公司固定效应, 是, 年度固定效应, 是) title("DID基准回归结果")

* ---- 3. 平行趋势检验：相对时间虚拟变量，以政策前一期(-1)为基准 ----
gen rel = year - <政策年份> if treat == 1
replace rel = 0 if treat == 0 & missing(rel)   // 对照组并入各期虚拟变量

forvalues k = 5(-1)2 {
    gen pre`k'  = (rel <= -`k')
}
gen current = (rel == 0)
forvalues k = 1/5 {
    gen post`k' = (rel >= `k')
}
* 对照组样本各期虚拟变量均取 0（用 rel 缺失控制）
foreach v of varlist pre5 pre4 pre3 pre2 current post1-post5 {
    replace `v' = 0 if treat == 0
}
* pre5 至 pre1 需在政策前 5 期至前 2 期分别定义时改为 (rel == -`k')，按数据跨度调整

reghdfe <Y> pre5 pre4 pre3 pre2 current post1-post5 <控制变量列表>, ///
    absorb(id year) vce(cluster id)
coefplot, keep(pre5 pre4 pre3 pre2 current post1-post5) vertical ///
    yline(0, lp(dash)) xline(4.5, lp(dash)) ///
    ciopts(recast(rcap)) ///
    title("平行趋势检验") xtitle("相对政策时点") ytitle("系数")
graph export "平行趋势检验.png", replace

* ---- 4. 稳健性 ----
* a. PSM-DID：按控制变量逐年 1:1 近邻匹配
capture which psmatch2
if _rc != 0 di as error "缺少 psmatch2，请手动: ssc install psmatch2, replace"
foreach y in <年份区间> {
    * psmatch2 treat <控制变量列表> if year == `y', outcome(<Y>) logit neighbor(1) common
}
* pstest <控制变量列表>, both      // 平衡性检验
* 用匹配样本重跑基准
* reghdfe <Y> did <控制变量列表> if _support == 1, absorb(id year) vce(cluster id)

* b. 安慰剂：随机打乱处理组（循环 500 次，记录 did 系数与 p 值）
* 伪代码：随机抽取与真实处理组同数量的公司设为伪处理组重跑，画系数分布图与真实值对比

* c. 排除同期政策 / 替换被解释变量 / 剔除特殊年份
* gen other_policy = ...；reghdfe <Y> did other_policy ..., absorb(id year)

* ---- 5. 机制与异质性（复用 A/B 路线方法）----
* 中介：三步法（见 references/route-text-patent.md 第 3 节）
* 异质性：东中西 / 产权 / 规模分组回归

save "DID最终数据集.dta", replace
log close
