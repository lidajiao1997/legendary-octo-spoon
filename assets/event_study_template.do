* ============================================================
* 文件名：event_study_template.do
* 用途　：路线 E 事件研究全流程——市场模型估计 → 逐事件 AR/CAR
*         → 全样本与分组显著性检验 → 横截面回归 → CAR 走势图。
* ------------------------------------------------------------
* 所需数据格式：
*   ① 个股与市场日收益率（长格式 dta）：stkcd date t ret rm
*      （t 为交易日序号，用于计算相对天数；ret 为个股日收益率，
*      rm 为市场日收益率，均用小数）
*   ② 事件列表（dta）：stkcd ev_id event_t（事件日在交易日历上的
*      序号；公告日为非交易日时对齐到其后首个交易日）
* 运行依赖：
*   Stata 16+（无需外部包）；本目录 thesis_utils.ado
* 预期输出：
*   事件研究_时间戳.log  全程日志
*   参数表.dta           各事件市场模型 alpha/beta
*   car_每事件.dta       每事件 CAR(ev_start, ev_end)
*   屏幕输出             CAR 的 t 检验 / Wilcoxon 检验 / 分位统计
* 用法　：第 0 节窗口参数按研究设计修改；主窗口建议另跑 -1/+1、
*         -3/+3 做敏感性；勿覆盖已有产出
* ============================================================

version 16
clear all
set more off

* ---- 0. 环境自检与窗口参数 ----
capture program which thesis_env
if _rc != 0 do "thesis_utils.ado"
cd "C:/Users/<用户名>/Desktop/<论文项目名>"
global projdir = c(pwd)                              // 记住项目目录：thesis_table 用它锚定输出路径，防 CWD 漂移
thesis_env, logname("事件研究") pkgs()

* 三个窗口的定义（相对事件日的交易日数）：
local est_start = -120     // 估计窗口起点：用来估计正常收益的"干净期"
local est_end   = -21      // 估计窗口终点：离事件日留 20 天缓冲，避免事件预期污染估计
local ev_start  = -10      // 事件窗口起点：主窗口；另跑 -1/+1、-3/+3 做敏感性
local ev_end    = 10

* ---- 1. 合并收益率与事件列表，计算相对天数 ----
* rel = 0 即事件日；rel<0 政策/公告前，rel>0 之后
use "<个股与市场日收益率>.dta", clear
merge m:1 stkcd using "<事件列表>.dta", nogen   // 事件按公司并入每一天
gen rel = t - event_t                            // 相对天数：核心变量
keep if rel >= `est_start' & rel <= `ev_end'     // 只保留估计窗口+事件窗口

* ---- 2. 估计窗口回归市场模型，得每个事件的 alpha/beta ----
* 市场模型：E[ret] = alpha + beta * rm——"正常收益"的定义。
* in_est 限定只用估计窗口样本，事件窗口数据不参与估计（避免污染）
gen byte in_est = (rel >= `est_start' & rel <= `est_end')
statsby alpha=_b[_cons] beta=_b[rm], by(stkcd ev_id) clear: ///
    regress ret rm if in_est == 1
* statsby 对每个(公司,事件)分别回归并收集系数；同一公司多个事件
* 必须用 stkcd + ev_id 双键
save "参数表.dta", replace

* ---- 3. 回并原数据，计算异常收益 AR 与累计 CAR ----
merge 1:m stkcd using "<主数据>.dta", nogen      // 用 alpha/beta 逐日算 AR
gen ar = ret - (alpha + beta * rm) if rel >= `ev_start' & rel <= `ev_end'
* AR = 实际收益 - 市场模型预测的正常收益 = 事件带来的"意外"部分
sort ev_id rel
by ev_id: gen car = sum(ar)                      // 事件窗口内逐日累计
keep if rel >= `ev_start' & rel <= `ev_end'
by ev_id: keep if _n == _N          // 每个事件只留窗口末端行，即 CAR(ev_start, ev_end)
save "car_每事件.dta", replace

* ---- 4. 全样本检验（论文核心表）----
* t 检验看均值是否区别于 0；signrank 不依赖正态假设，两者都报
ttest car == 0
signrank car = 0                    // 注意语法：signrank car = 0（不是 car == 0）
sum car, detail

* ---- 5. 分组比较（如产权性质）----
bysort soe: ttest car == 0          // 各组内部是否显著
ttest car, by(soe)                  // 组间差异是否显著（异质性证据）

* ---- 6. 横截面回归（CAR 的决定因素；小样本，变量要克制）----
* merge 事件特征与公司特征后：
* regress car <事件金额规模> soe <杠杆> <规模> <行业虚拟变量>, robust
* 经验法则：事件数 < 60 时解释变量不超过 5 个，避免过拟合

* ---- 7. CAR 走势图（逐日均值，直观展示市场反应节奏）----
* 保留逐日 car 后：
* preserve; collapse (mean) car_daily = car, by(rel)
* twoway line car_daily rel, yline(0) xline(0, lp(dash)) title("事件窗口 CAR 走势")
* graph export "CAR走势.png", replace; restore

log close
di as result ">>> 事件研究运行完毕。自查：主窗口与短窗口结论是否一致？CAR 方向与理论预期是否一致？横截面样本量是否支撑回归？"
