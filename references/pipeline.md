# 九步实证流程详解

顺序固定，即论文实证章节顺序。每步给出关键代码（以高管薪酬→ROA 为例，替换 X/Y 即可平移）与解读要点。

## 第 1 步：描述性统计与相关性

```stata
sum roa roe tobinq ln_pay rd_intensity size lev growth top1 age hhi
correlate roa roe tobinq ln_pay size lev growth top1 rd_intensity age
```

解读要点：报告均值/标准差/最小最大值；初步判断 X 与 Y 方向是否和假设一致；相关系数 > 0.8 的变量对要在 VIF 后讨论。

## 第 2 步：VIF 多重共线性

```stata
reg roa ln_pay size lev growth top1 rd_intensity age i.year
estat vif
```

标准：VIF < 10（严格些 < 5）。交互项回归前必须报告此步，因为交互项天然与主效应高相关。

## 第 3 步：基准回归

```stata
xtreg roa ln_pay size lev growth top1 rd_intensity age i.year, fe robust
estimates store m_roa
xtreg roe ... , fe robust      // 替换被解释变量
xtreg tobinq ... , fe robust
```

- 双固定效应：公司固定效应（fe）+ 年度虚拟变量 i.year
- 标准误聚类到公司：`fe robust`（面板内默认按 id 聚类）
- 被解释变量至少给两个（财务绩效 roa/roe + 市场绩效 tobinq），证明结果不依赖单一度量

## 第 4 步：稳健性检验（至少做两项）

| 方法 | 代码要点 | 逻辑 |
|------|---------|------|
| 行业调整被解释变量 | `gen adj_roa = roa - industry_mean_roa` 后重跑 | 排除行业景气干扰 |
| 替换变量度量 | 用 `top3_salary` 原值替代 `ln_pay` | 结果不依赖度量方式 |
| 调节变量滞后一期 | 用 `l_rd_intensity` 替代当期 | 缓解反向因果 |
| 替换固定效应 | 行业×年度固定效应 | 排除行业时变冲击 |

## 第 5 步：内生性检验（至少一项）

```stata
// 方法一：解释变量整体滞后一期
xtreg roa l_ln_pay l_size l_lev l_growth l_top1 l_rd_intensity age i.year, fe robust

// 方法二：行业工具变量 2SLS（leave-one-out 均值，构造见 data-schema.md）
ivregress 2sls roa (ln_pay = iv_industry) size lev growth top1 rd_intensity age i.year, robust
```

工具变量逻辑（论文里要写清楚）：同行业其他公司平均薪酬与本企业薪酬相关（相关性），但不直接影响本企业绩效（排他性）。可加 `estat firststage` 报告弱工具检验。

## 第 6 步：调节效应（交互项 + 分组双保险）

```stata
gen pay_hhi = ln_pay * hhi
xtreg roa ln_pay pay_hhi size lev growth top1 rd_intensity age i.year, fe robust   // 交互项
// 分组回归互为佐证
bysort year: egen hhi_median = median(hhi)
gen high_hhi = (hhi > hhi_median) if !missing(hhi)
xtreg roa ... if high_hhi==1, fe robust
xtreg roa ... if high_hhi==0, fe robust
```

调节变量建议用滞后一期以缓解内生性：`gen pay_rd = ln_pay * l_rd_intensity`。

## 第 7 步：简单斜率分析（调节效应可视化）

```stata
sum l_rd_intensity
local rd_low  = r(mean) - r(sd)
local rd_high = r(mean) + r(sd)
quietly xtreg roa ln_pay pay_rd l_rd_intensity ..., fe robust
lincom _b[ln_pay] + _b[pay_rd]*`rd_low'      // 低研发下的边际效应
lincom _b[ln_pay] + _b[pay_rd]*`rd_mean'
lincom _b[ln_pay] + _b[pay_rd]*`rd_high'
```

三组 lincom 结果做成表格或 `marginsplot`；简单斜率图（.gph）是答辩加分项。

## 第 8 步：异质性分析

区域分组（东中西部划分见 assets 模板内 inlist 清单）：

```stata
foreach r of numlist 1/3 {
    quietly xtreg roa ... if region == `r', fe robust
    estimates store region_`r'
}
// 交互项检验（以东部为基准组）
tab region, gen(reg_dum)
xtreg roa ln_pay reg_dum2 c.ln_pay#reg_dum2 reg_dum3 c.ln_pay#reg_dum3 ..., fe robust
// 城市分组：一线及直辖市 vs 其他
```

## 第 9 步：表格导出

```stata
outreg2 [m_roa m_roe m_tobinq] using "基础回归结果.xlsx", replace excel dec(4) ///
    addtext(年度固定效应, 是, 公司固定效应, 是) title("基础回归结果")
```

每类检验导出一张表；论文表格转为三线表（表格线仅保留顶线、表头线、底线），注释放表下（标准误括号值、* p<0.1 ** p<0.05 *** p<0.01）。

## 本科论文「检验够不够」判断标准

最低合格组合：描述统计 + VIF + 基准回归（≥2 个 Y）+ 稳健性 ≥2 项 + 内生性 ≥1 项 + 调节或异质性 ≥1 组。答辩常被追问的是：为什么用固定效应不用随机效应（答：Hausman 检验，或理论理由）、工具变量的外生性、调节效应为何不显著。

## 调节效应不显著的补救顺序

1. 调节变量滞后一期重试
2. 连续交互改中位数分组回归
3. 检查调节变量是否需取对数/去趋势
4. 如实报告不显著并给出理论解释——本科论文允许「部分假设未获支持」，比造假安全得多

---

## 路线 B 补充（文本词频 X + 专利 Y）

本文件的九步骨架对两条路线通用，但机制检验一步不同：路线 A 用调节效应（第 6-7 步），**路线 B 用中介效应**（逐步回归法），且稳健性/内生性工具箱更宽（替换词频口径、滞后多期、PSM）。走路线 B 时，第 6-7 步替换为 route-text-patent.md 第 3 节的中介效应流程，第 5 步内生性增加 PSM（同文件第 4 节）。
