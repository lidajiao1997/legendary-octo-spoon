# -*- coding: utf-8 -*-
"""
路线 D：问卷调研分析管线模板（Python）
管线：清洗 -> 信度 -> KMO/Bartlett -> CFA(semopy) -> Harman -> 相关 -> 层级回归 -> Bootstrap 中介
用法：python survey_pipeline.py [数据.csv] [输出.md]
      不带参数时默认读当前目录 survey_data.csv；量表编码按需修改下方 X/M/Y_ITEMS
依赖：pip install pandas numpy pingouin semopy statsmodels tabulate
"""

import sys
import os
import pandas as pd
import numpy as np
import pingouin as pg
from semopy import Model, calc_stats

CSV = sys.argv[1] if len(sys.argv) > 1 else "survey_data.csv"
OUT = sys.argv[2] if len(sys.argv) > 2 else "问卷分析结果.md"

X_ITEMS = ["X1", "X2", "X3", "X4"]        # 自变量量表题项
M_ITEMS = ["M1", "M2", "M3", "M4"]        # 中介量表题项
Y_ITEMS = ["Y1", "Y2", "Y3", "Y4"]        # 因变量量表题项
REVERSE = ["M2"]                          # 反向题列表
CONTROLS = ["gender", "age", "tenure"]    # 控制变量

if not os.path.exists(CSV):
    sys.exit(f"[错误] 找不到数据文件：{CSV}\n"
             f"用法：python survey_pipeline.py <问卷数据.csv> [输出.md]\n"
             f"问卷星导出后请把列名改为 {X_ITEMS + M_ITEMS + Y_ITEMS + CONTROLS} 或修改上方编码。")

df = pd.read_csv(CSV)
lines = ["# 问卷分析结果\n"]

# ---- 1. 清洗：反向计分 + 剔除无效样本 ----
for it in REVERSE:
    scale_max = df[it].max()
    df[it] = scale_max + 1 - df[it]
before = len(df)
df = df.dropna(subset=X_ITEMS + M_ITEMS + Y_ITEMS + CONTROLS)
items_all = X_ITEMS + M_ITEMS + Y_ITEMS
df = df[df[items_all].std(axis=1) > 0]          # 剔除规律作答（所有题项同值）
lines.append(f"样本：回收 {before}，有效 {len(df)}（剔除缺失与规律作答）\n")


def kmo_bartlett(X):
    """KMO 与 Bartlett 球形检验（相关矩阵法，纯 numpy）"""
    R = np.corrcoef(X, rowvar=False)
    p = R.shape[0]
    Ri = np.linalg.inv(R)
    D = np.sqrt(np.diag(np.diag(Ri)))
    P = -np.linalg.inv(D) @ Ri @ np.linalg.inv(D)   # 偏相关矩阵
    off = ~np.eye(p, dtype=bool)
    kmo = (R[off] ** 2).sum() / ((R[off] ** 2).sum() + (P[off] ** 2).sum())
    sign, logdet = np.linalg.slogdet(R)
    chi2 = -(len(X) - 1 - (2 * p + 5) / 6) * logdet
    dof = p * (p - 1) / 2
    from scipy import stats as sps
    pval = sps.chi2.sf(chi2, dof)
    return kmo, chi2, dof, pval


def eigen_variance(X):
    """相关矩阵特征根 -> 各成分方差解释比例（用于特征根>1 判定与 Harman）"""
    R = np.corrcoef(X, rowvar=False)
    ev = np.sort(np.linalg.eigvalsh(R))[::-1]
    return ev, ev / ev.sum() * 100


# ---- 2. 信度（各量表 Cronbach alpha）----
for name, items in [("X", X_ITEMS), ("M", M_ITEMS), ("Y", Y_ITEMS)]:
    a = pg.cronbach_alpha(data=df[items])
    lines.append(f"量表 {name}：alpha = {a[0]:.3f}（合格 >= 0.7）\n")

# ---- 3. KMO 与 Bartlett ----
kmo, chi2, dof, pval = kmo_bartlett(df[items_all].to_numpy())
lines.append(f"KMO = {kmo:.3f}（>=0.7），Bartlett chi2({int(dof)}) = {chi2:.1f}, p = {pval:.3g}\n")
ev, _ = eigen_variance(df[items_all].to_numpy())
lines.append(f"特征根>1 的因子数：{(ev > 1).sum()}（辅助判断因子结构）\n")

# ---- 4. CFA（semopy 三因子模型；验证性分析以此为准）----
model_desc = f"""
X =~ {' + '.join(X_ITEMS)}
M =~ {' + '.join(M_ITEMS)}
Y =~ {' + '.join(Y_ITEMS)}
"""
m = Model(model_desc)
m.fit(df[items_all])
lines.append("## CFA 整体拟合指标（标准：CFI/TLI>0.9, RMSEA<0.08, SRMR<0.08）\n")
fit = calc_stats(m).T.round(3)
lines.append(f"`{fit.to_markdown()}`\n")
stats = m.inspect().round(3)
lines.append("## CFA 因子载荷（标准化前系数；首题为参照固定为 1）\n")
lines.append(f"`{stats.to_markdown(index=False)}`\n")

# ---- 5. 共同方法偏差：Harman 单因子 ----
_, var_pct = eigen_variance(df[items_all].to_numpy())
lines.append(f"Harman 单因子：第一因子解释 {var_pct[0]:.1f}%（< 40% 可接受）\n")

# ---- 6. 变量合成与相关 ----
for name, items in [("X", X_ITEMS), ("M", M_ITEMS), ("Y", Y_ITEMS)]:
    df[name] = df[items].mean(axis=1)
corr = df[["X", "M", "Y"] + CONTROLS].corr().round(3)
lines.append("## 相关系数矩阵\n")
lines.append(f"`{corr.to_markdown()}`\n")

# ---- 7. 层级回归：X -> Y，加控制 ----
import statsmodels.api as sm
m1 = sm.OLS(df["Y"], sm.add_constant(df[CONTROLS])).fit(cov_type="HC3")
m2 = sm.OLS(df["Y"], sm.add_constant(df[CONTROLS + ["X"]])).fit(cov_type="HC3")
lines.append("## 层级回归（Y）\n")
lines.append(f"模型1(仅控制)：R2={m1.rsquared:.3f}\n\n"
             f"模型2(+X)：X 系数={m2.params['X']:.3f}, p={m2.pvalues['X']:.4f}, R2={m2.rsquared:.3f}\n")

# ---- 8. Bootstrap 中介：X -> M -> Y ----
boot = []
rng = np.random.default_rng(42)
for _ in range(5000):
    s = df.sample(len(df), replace=True, random_state=None)
    a = sm.OLS(s["M"], sm.add_constant(s[CONTROLS + ["X"]])).fit().params["X"]
    b = sm.OLS(s["Y"], sm.add_constant(s[CONTROLS + ["X", "M"]])).fit().params["M"]
    boot.append(a * b)
lo, hi = np.percentile(boot, [2.5, 97.5])
lines.append("## Bootstrap 中介（5000 次）\n")
lines.append(f"间接效应 = {np.mean(boot):.4f}，95% CI [{lo:.4f}, {hi:.4f}]，"
             f"{'显著' if lo * hi > 0 else '不显著'}（CI 不含 0 即显著）\n")

with open(OUT, "w", encoding="utf-8") as f:
    f.writelines(lines)
print("完成，结果已写入", OUT)
