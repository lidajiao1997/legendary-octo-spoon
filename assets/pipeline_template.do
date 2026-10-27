* ============================================================
* 管理类本科实证论文完整管线模板
* 蓝本：高管薪酬→企业绩效（某本科毕业论文范本）。替换 <X>/<Y>/<Z> 即可平移主题
* 基准：Stata 16（version 16，勿用 16 之后独有语法）
* 依赖：outreg2（缺则 ssc install outreg2）
* 用法：所有 <...> 占位符按论文主题替换；文件名勿覆盖已有产出
* ============================================================

version 16
clear all
set more off

* ---- 0. 环境准备 ----
cd "C:/Users/<用户名>/Desktop"     // 按实际工作目录修改
capture which outreg2
if _rc != 0 di as error "缺少 outreg2，请手动执行: ssc install outreg2, replace"

local date = subinstr("${S_DATE}", " ", "_", .)
local time = subinstr("${S_TIME}", ":", "-", .)
log using "实证分析_<date>_<time>.log", text replace

* ---- 1. 导入与清洗（每张 CSMAR 原始表重复此段）----
* 模式：import -> rename 中文键 -> 生成 year -> 取年报 -> 去重 -> 存临时 dta
foreach tbl in <财务绩效> <财务指标> <研发投入> <薪酬> <股权> <营业收入> <托宾q> {
    * import excel "<tbl>.xlsx", firstrow clear
    * rename 证券代码 code
    * rename 统计截止日期 date_str
    * gen date = date(date_str, "YMD")
    * format date %tdCCYY-NN-DD
    * drop date_str
    * gen year = year(date)
    * gen month = month(date)
    * keep if month == 12
    * duplicates drop code year, force
    * save "<tbl>_temp.dta", replace
}

* ---- 2. 合并 ----
use "<主表>_temp.dta", clear
foreach t in <表1> <表2> <表3> {
    * merge 1:1 code year using "<t>_temp.dta", keepusing(<需要的变量>)
    * keep if _merge == 3
    * drop _merge
}
* merge m:1 code using "公司基本信息_temp.dta"    // 静态信息（行业/省份/IPO）
* keep if _merge == 3
* drop _merge

* ---- 3. 变量构造 ----
* gen ln_<X> = ln(<X原值>) if <X原值> > 0        // 解释变量取对数
* gen size = ln(total_assets)
* gen age = year - ipo_year + 1
* gen growth = (revenue - revenue_lag) / revenue_lag
* encode industry_code, gen(industry_num)
* bysort industry_num year: egen hhi = sum(market_share^2)
* sort code year
* by code: gen l_<X> = <X>[_n-1]                 // 滞后一期
* bysort industry_num year: egen industry_avg_<X> = mean(<X>)
* gen iv_industry = industry_avg_<X> - <X>       // leave-one-out 工具变量

* ---- 4. 样本筛选与缩尾（顺序：先删缺失→缩尾→再删缺失）----
local winsor_vars <Y1> <Y2> ln_<X> <Z> size lev growth top1 age
foreach var in `winsor_vars' {
    * drop if missing(`var')
    * _pctile `var', p(1 99)
    * replace `var' = r(r1) if `var' < r(r1) & !missing(`var')
    * replace `var' = r(r2) if `var' > r(r2) & !missing(`var')
}
egen id = group(code)
xtset id year

* ---- 5. 描述统计 + 相关性 + VIF ----
sum `winsor_vars'
correlate `winsor_vars'
reg <Y1> ln_<X> size lev growth top1 <Z> age i.year
estat vif

* ---- 6. 基准回归（双固定效应 + 公司聚类稳健标准误）----
xtreg <Y1> ln_<X> size lev growth top1 <Z> age i.year, fe robust
estimates store m_y1
xtreg <Y2> ln_<X> size lev growth top1 <Z> age i.year, fe robust
estimates store m_y2

* ---- 7. 稳健性（至少两项）----
* a. 行业调整 Y
* bysort industry_num year: egen ind_mean_y = mean(<Y1>)
* gen adj_y = <Y1> - ind_mean_y
* xtreg adj_y ln_<X> ... , fe robust
* b. 替换 X 度量
* c. 调节变量滞后一期

* ---- 8. 内生性（滞后 + 行业工具变量 2SLS）----
* xtreg <Y1> l_ln_<X> l_size l_lev l_growth l_top1 l_<Z> age i.year, fe robust
* ivregress 2sls <Y1> (ln_<X> = iv_industry) size lev growth top1 <Z> age i.year, robust
* estat firststage

* ---- 9. 调节效应（交互项 + 分组 + 简单斜率）----
* gen pay_z = ln_<X> * l_<Z>
* xtreg <Y1> ln_<X> pay_z l_<Z> ..., fe robust
* sum l_<Z>
* local z_low  = r(mean) - r(sd)
* local z_high = r(mean) + r(sd)
* lincom _b[ln_<X>] + _b[pay_z]*`z_low'
* lincom _b[ln_<X>] + _b[pay_z]*`z_high'

* ---- 10. 异质性（东中西部分组，inlist 清单见下）----
* gen region = .
* replace region = 1 if inlist(province,"北京","天津","河北","辽宁") | inlist(province,"上海","江苏","浙江","福建") | inlist(province,"山东","广东","海南")
* replace region = 2 if inlist(province,"山西","吉林","黑龙江") | inlist(province,"安徽","江西","河南") | inlist(province,"湖北","湖南")
* replace region = 3 if inlist(province,"内蒙古","广西","重庆","四川") | inlist(province,"贵州","云南","西藏") | inlist(province,"陕西","甘肃","青海","宁夏","新疆")
* foreach r of numlist 1/3 {
*     quietly xtreg <Y1> ... if region == `r', fe robust
*     estimates store region_`r'
* }

* ---- 11. 导出（每类检验一张表，三线表整理后入论文）----
outreg2 [m_y1 m_y2] using "基础回归结果.xlsx", replace excel dec(4) ///
    addtext(年度固定效应, 是, 公司固定效应, 是) title("基础回归结果")

save "最终数据集_完整版.dta", replace
log close
