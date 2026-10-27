* ============================================================
* 路线 E：事件研究 CAR 模板（Stata 16 基线）
* 数据：长格式个股日收益率（stkcd date ret）+ 市场日收益率（rm）
* 事件列表：stkcd event_date（公告日对齐到首个交易日）
* 用法：替换 <...>；勿覆盖已有产出；结论存本地文件
* ============================================================

version 16
clear all
set more off

cd "C:/Users/<用户名>/Desktop"
local date = subinstr("${S_DATE}", " ", "_", .)
log using "事件研究_<date>.log", text replace

* ---- 0. 参数设定 ----
local est_start = -120     // 估计窗口起点（相对事件日）
local est_end   = -21      // 估计窗口终点
local ev_start  = -10      // 事件窗口起点（做多窗口敏感性：另跑 -1/+1、-3/+3）
local ev_end    = 10

* ---- 1. 合并收益率数据与事件列表，生成相对天数 ----
use "<个股与市场日收益率>.dta", clear
merge m:1 stkcd using "<事件列表>.dta", nogen
gen rel = <交易日序号差>     // date - event_date 在交易日历上的序号差（先转序号再相减）
keep if rel >= `est_start' & rel <= `ev_end'

* ---- 2. 估计窗口回归市场模型，得 alpha beta ----
gen byte in_est = (rel >= `est_start' & rel <= `est_end')
statsby alpha=_b[_cons] beta=_b[rm], by(stkcd ev_id) clear: ///
    regress ret rm if in_est == 1
* 注：若同一公司有多个事件，by 改为 stkcd+事件编号 ev_id
save "参数表.dta", replace

* ---- 3. 回并原数据，计算 AR 与 CAR ----
merge 1:m stkcd using "<主数据>.dta", nogen
gen ar = ret - (alpha + beta * rm) if rel >= `ev_start' & rel <= `ev_end'
sort ev_id rel
by ev_id: gen car = sum(ar)
keep if rel >= `ev_start' & rel <= `ev_end'
by ev_id: keep if _n == _N          // 每个事件保留窗口末端累计值 CAR(ev_start, ev_end)
save "car_每事件.dta", replace

* ---- 4. 全样本检验 ----
ttest car == 0
signrank car == 0                   // Wilcoxon 佐证（小样本/非正态）
sum car, detail

* ---- 5. 分组比较（如产权）----
bysort soe: ttest car == 0
ttest car, by(soe)                  // 组间差异

* ---- 6. 横截面回归（小样本，变量克制）----
* merge 事件特征与公司特征后：
* regress car <事件金额规模> soe <杠杆> <规模> <行业虚拟变量>, robust

* ---- 7. CAR 走势图（逐日均值，画折线）----
* 保留逐日 car 后：
* preserve; collapse (mean) car_daily = car, by(rel)
* twoway line car_daily rel, yline(0) xline(0, lp(dash)) title("事件窗口 CAR 走势")
* graph export "CAR走势.png", replace; restore

log close
