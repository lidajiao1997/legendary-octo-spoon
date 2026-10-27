* ============================================================
* 文件名：pipeline_template.do
* 用途　：路线 A/B 完整实证管线——CSMAR 多表合并清洗 → 变量构造
*         → 描述统计 → 基准回归 → 稳健性 → 内生性 → 调节/异质性
*         → outreg2 出表。替换 <X>/<Y>/<Z> 即可平移任何
*         「X 对 Y 的影响」主题。
* 蓝本　：高管薪酬→企业绩效（某本科毕业论文范本）
* ------------------------------------------------------------
* 所需数据格式：
*   CSMAR 导出的 xlsx 原始表若干（每表一个指标，表头为中文列名：
*   证券代码 / 统计截止日期 / 指标列），命名规范与列名映射见
*   references/data-schema.md
* 运行依赖：
*   Stata 16+；outreg2（出表）；本目录 thesis_utils.ado（环境自检
*   与缩尾等通用程序）
* 预期输出：
*   <实证分析_时间戳>.log   全程日志
*   基础回归结果.xlsx       基准回归表（多被解释变量并列）
*   最终数据集_完整版.dta   合并清洗后的分析数据
* 用法　：占位符 <...> 全部替换后再跑；建议由 master.do 调度运行；
*         新文件勿覆盖已有产出
* ============================================================

version 16
clear all
set more off

* ---- 0. 环境自检：版本 <16 直接退出；缺包给出安装命令；开 log ----
* 若已把 thesis_utils.ado 装入 PERSONAL 目录，前两行可跳过
capture program which thesis_env
if _rc != 0 do "thesis_utils.ado"                    // 同目录载入工具集
cd "C:/Users/<用户名>/Desktop/<论文项目名>"           // 按实际工作目录修改
global projdir = c(pwd)                              // 记住项目目录：thesis_table 用它锚定输出路径，防 CWD 漂移
thesis_env, logname("实证分析") pkgs(outreg2)

* ---- 1. 导入与清洗（每张 CSMAR 原始表重复此段）----
* 固定套路：import → 中文键重命名 → 生成 year → 只留年报（12月）
* → 按代码+年份去重 → 存临时 dta。年报口径的原理见 data-schema.md
foreach tbl in <财务绩效> <财务指标> <研发投入> <薪酬> <股权> <营业收入> <托宾q> {
    * import excel "`tbl'.xlsx", firstrow clear          // 首行作变量名
    * rename 证券代码 code                               // 统一键 1：6 位代码
    * rename 统计截止日期 date_str                       // 统一键 2：报告期
    * gen date = date(date_str, "YMD")                  // 字符串转 Stata 日期
    * format date %tdCCYY-NN-DD
    * drop date_str
    * gen year  = year(date)
    * gen month = month(date)
    * keep if month == 12                               // 只留年报：剔除季报/半年报重复观测
    * duplicates drop code year, force                  // 同一年份多行时保留一行（先检查再 force）
    * save "`tbl'_temp.dta", replace
}

* ---- 2. 合并 ----
* 以主表（被解释变量所在表）为锚，1:1 逐张并入；keep(3) 丢弃
* 任何一侧缺失的匹配——宁可样本小一点也不要半残观测
use "<主表>_temp.dta", clear
foreach t in <表1> <表2> <表3> {
    * merge 1:1 code year using "`t'_temp.dta", keepusing(<需要的变量>)
    * keep if _merge == 3                                // 双方都匹配上的才留下
    * drop _merge
}
* merge m:1 code using "公司基本信息_temp.dta"           // 静态信息（行业/省份/IPO 年份）按代码并入
* keep if _merge == 3
* drop _merge

* ---- 3. 变量构造 ----
* 按论文变量定义表逐个生成；注意取对数与滞后期的时机（见行内注释）
* gen ln_<X> = ln(<X原值>) if <X原值> > 0        // 连续正值的 X 取对数，量纲压缩且接近正态
* gen size = ln(total_assets)                    // 公司规模：总资产取自然对数
* gen age = year - ipo_year + 1                  // 上市年龄
* gen growth = (revenue - revenue_lag) / revenue_lag   // 成长性：营收增长率
* encode industry_code, gen(industry_num)        // 行业字符串编码为数值，供分组/固定效应用
* bysort industry_num year: egen hhi = sum(market_share^2)   // 行业竞争度 HHI（调节变量示例）
* sort code year
* by code: gen l_<X> = <X>[_n-1]                 // 滞后一期：缓解反向因果（内生性检验用）
* bysort industry_num year: egen industry_avg_<X> = mean(<X>)
* gen iv_industry = industry_avg_<X> - <X>       // leave-one-out 工具变量：同行均值剔除自身，与自身相关、与自身扰动无关
egen id = group(code)                            // xtset 需要数值型个体 id

* ---- 4. 样本筛选与缩尾（顺序：先删缺失 → 缩尾 → 再删缺失）----
* 缩尾用通用程序 thesis_winsor（thesis_utils.ado 提供），默认 1%/99%
local winsor_vars <Y1> <Y2> ln_<X> <Z> size lev growth top1 age
foreach var in `winsor_vars' {
    * drop if missing(`var')                      // 关键变量缺失的观测先剔除
}
thesis_winsor `winsor_vars'                      // 1%/99% 缩尾，抑制极端值；要改分位写 thesis_winsor `winsor_vars', p(5 95)
foreach var in `winsor_vars' {
    * drop if missing(`var')                      // 缩尾本身不产生缺失，此步保险
}
xtset id year                                    // 声明面板结构，后续 xtreg/lag 依赖它

* ---- 5. 描述统计 + 相关性 + VIF ----
* 论文 5.1-5.2 节素材；VIF 用混合 OLS 检查共线性，均值 <10 可接受
sum `winsor_vars'
correlate `winsor_vars'
reg <Y1> ln_<X> size lev growth top1 <Z> age i.year
estat vif

* ---- 6. 基准回归（双向固定效应 + 公司聚类稳健标准误）----
* fe 吸收公司不随时间变化的特征；i.year 吸收宏观年度冲击；
* robust 按公司聚类，允许同一公司残差自相关
xtreg <Y1> ln_<X> size lev growth top1 <Z> age i.year, fe robust
estimates store m_y1                             // 存结果供 outreg2 并列出表
xtreg <Y2> ln_<X> size lev growth top1 <Z> age i.year, fe robust
estimates store m_y2

* ---- 7. 稳健性（至少两项，本科合格线见 pipeline.md）----
* a. 行业调整 Y：剔除行业共同波动，X 效应仍在则稳健
* bysort industry_num year: egen ind_mean_y = mean(<Y1>)
* gen adj_y = <Y1> - ind_mean_y
* xtreg adj_y ln_<X> ... , fe robust
* b. 替换 X 度量：同一概念换口径（如绝对值→占比）
* c. 调节变量滞后一期：缓解同期互为因果

* ---- 8. 内生性（滞后解释变量 + 行业 leave-one-out 工具变量 2SLS）----
* xtreg <Y1> l_ln_<X> l_size l_lev l_growth l_top1 l_<Z> age i.year, fe robust
* ivregress 2sls <Y1> (ln_<X> = iv_industry) size lev growth top1 <Z> age i.year, robust
* estat firststage                              // 弱工具变量检验：F > 10 才算可用

* ---- 9. 调节效应（交互项 + 分组 + 简单斜率）----
* 交互项系数显著 ≠ 调节成立，还要看简单斜率在两端是否同号
* gen pay_z = ln_<X> * l_<Z>                    // 交互项
* xtreg <Y1> ln_<X> pay_z l_<Z> ..., fe robust  // 主效应与交互项必须同时进模型
* sum l_<Z>
* local z_low  = r(mean) - r(sd)                // 调节变量取低值（均值-1sd）
* local z_high = r(mean) + r(sd)
* lincom _b[ln_<X>] + _b[pay_z]*`z_low'         // 简单斜率：低调节水平下 X 的边际效应
* lincom _b[ln_<X>] + _b[pay_z]*`z_high'        // 高调节水平下 X 的边际效应

* ---- 10. 异质性（东中西部分组，分组回归看系数差异）----
* gen region = .
* replace region = 1 if inlist(province,"北京","天津","河北","辽宁") | inlist(province,"上海","江苏","浙江","福建") | inlist(province,"山东","广东","海南")
* replace region = 2 if inlist(province,"山西","吉林","黑龙江") | inlist(province,"安徽","江西","河南") | inlist(province,"湖北","湖南")
* replace region = 3 if inlist(province,"内蒙古","广西","重庆","四川") | inlist(province,"贵州","云南","西藏") | inlist(province,"陕西","甘肃","青海","宁夏","新疆")
* foreach r of numlist 1/3 {
*     quietly xtreg <Y1> ... if region == `r', fe robust
*     estimates store region_`r'
* }

* ---- 11. 导出（thesis_table 统一三线表格式，每类检验一张表）----
thesis_table m_y1 m_y2 using "基础回归结果.xlsx", title("基础回归结果") replace
* 同一张表追加模型时去掉 replace：thesis_table m3 using "基础回归结果.xlsx"

save "最终数据集_完整版.dta", replace
log close
di as result ">>> 管线运行完毕。对照 references/pipeline.md 检查检验是否齐格线（稳健≥2、内生性≥1、调节或异质性≥1）。"
