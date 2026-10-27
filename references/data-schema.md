# CSMAR 数据合并与清洗规范

以一篇高管薪酬—企业绩效本科毕业论文的公开范式为蓝本。CSMAR 导出的原始表均为 xlsx，每张表一个指标，靠「证券代码 + 统计截止日期」两个键对齐。

## 1. 原始表 → 变量命名映射

| 原始表 | 关键列（CSMAR 原名） | 重命名 | 含义 |
|--------|---------------------|--------|------|
| 财务绩效 | 股票代码 / 统计截止日期 / ROA / ROE | code / date / roa / roe | 被解释变量（注意此表主键叫「股票代码」，其他表多为「证券代码」，rename 时要分表处理） |
| 财务指标 | 证券代码 / 总资产 / 资产负债率 | code / total_assets / lev | 控制变量来源 |
| 研发投入情况表 | 研发投入占营业收入比例 | rd_intensity | 调节变量 |
| 董事及薪酬总额 | 高管前三薪酬总额 | top3_salary | 解释变量（取 ln） |
| 股权集中度季度指标 | 公司第1大股东持股比例 | top1 | 控制变量 |
| 营业收入 | 营业收入 | revenue | 用于构造 growth |
| 托宾q | 托宾Q值 | tobinq | 被解释变量替代 |
| 公司基本信息 | 股票代码 / 行业代码 / 首次上市日期 / 所属省份 / 所属城市 | code / industry_code / ipo_date_str / province / city | 面板维度、行业分组、区域异质性来源 |

## 2. 标准清洗管线（每张表相同）

```stata
import excel "xxx.xlsx", firstrow clear
rename 证券代码 code
rename 统计截止日期 date_str
gen date = date(date_str, "YMD")
format date %tdCCYY-NN-DD
drop date_str
gen year = year(date)
gen month = month(date)
keep if month == 12        // 只留年报
duplicates drop code year, force
save "xxx_temp.dta", replace
```

季度表（如股权集中度）同样取 month==12 转为年度。

## 3. 合并规则

- 主键 `code year`，逐张 `merge 1:1 code year using ...`，一律 `keep if _merge == 3` 后 `drop _merge`
- 公司静态信息（行业、省份、IPO 日期）用 `merge m:1 code`
- 稳健做法：合并前先 `describe` 核对每张表的键名是否一致；合并后立即 `count`、`misstable summarize` 报告样本量变化

## 4. 变量构造（管理类论文通用件）

```stata
gen ln_pay = ln(top3_salary) if top3_salary > 0      // 薪酬取对数
gen size = ln(total_assets)                           // 公司规模
gen ipo_year = year(date(ipo_date_str, "YMD"))
gen age = year - ipo_year + 1                         // 上市年限
gen growth = (revenue - revenue_lag) / revenue_lag    // 营收增长率
encode industry_code, gen(industry_num)
bysort industry_num year: egen industry_revenue = sum(revenue)
gen market_share = revenue / industry_revenue
bysort industry_num year: egen hhi = sum(market_share^2)   // 行业竞争度
sort code year
by code: gen l_`var' = `var'[_n-1]                    // 滞后一期（内生性用）
bysort industry_num year: egen industry_avg_pay = mean(ln_pay)
gen iv_industry = industry_avg_pay - ln_pay           // 行业工具变量（leave-one-out）
```

## 5. 样本筛选与缩尾（顺序不能反）

```stata
// 先删缺失，再缩尾，缩尾后再删一次缺失
foreach var in roa roe tobinq ln_pay rd_intensity size lev growth top1 age {
    drop if missing(`var')
}
foreach var in ... {
    _pctile `var', p(1 99)
    replace `var` = r(r1) if `var' < r(r1) & !missing(`var')
    replace `var' = r(r2) if `var' > r(r2) & !missing(`var')
}
// 再 drop if missing 一轮
egen id = group(code)
xtset id year
```

常见坑：
- 缩尾用 `_pctile` 的 1%/99%，不要用 winsor2 时忘了说明处理范围（论文里要写「上下 1% 缩尾」）
- 区域信息中「开曼群岛」等境外注册地要剔除
- 省份名去掉「省/市/自治区/壮族/回族/维吾尔」后缀再分组，否则 inlist 匹配不上

## 6. 论文中要交代的数据段落要素

数据来源（CSMAR）、样本区间（如 20XX–20XX）、行业筛选（如仅制造业，`substr(industry_code,1,1)=="C"`）、缩尾说明、最终样本量（公司数 × 年数）。
