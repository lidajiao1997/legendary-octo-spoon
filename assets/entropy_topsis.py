# -*- coding: utf-8 -*-
"""
路线 F：熵值法 + TOPSIS 综合评价模板
输入：DataFrame，行=评价对象（如城市/企业），列=指标；directions 指定每列 '+' 正向 / '-' 负向
输出：熵值法权重、加权得分、TOPSIS 相对贴近度 C_i 及排名
用法：from entropy_topsis import entropy_weight, topsis；或直接命令行 python entropy_topsis.py <数据.csv> <对象列名>
依赖：pip install pandas numpy
"""

import sys
import numpy as np
import pandas as pd


def _standardize(X, directions):
    """min-max 标准化；负向指标反向。X: (n, m)"""
    Z = np.zeros_like(X, dtype=float)
    for j, d in enumerate(directions):
        col = X[:, j].astype(float)
        rng = col.max() - col.min()
        if rng == 0:
            Z[:, j] = 0.0
        elif d == "+":
            Z[:, j] = (col - col.min()) / rng
        else:
            Z[:, j] = (col.max() - col) / rng
    return Z


def entropy_weight(X, directions):
    """熵值法客观赋权。返回 weights (m,) 与标准化矩阵"""
    Z = _standardize(X, directions)
    n, m = Z.shape
    P = Z / Z.sum(axis=0)
    P = np.where(P <= 0, 1e-12, P)                 # 平移零值，保证 ln 有定义
    k = 1.0 / np.log(n)
    e = -k * (P * np.log(P)).sum(axis=0)           # 各指标熵值
    d = 1 - e                                      # 差异系数
    w = d / d.sum()
    return w, Z


def topsis(X, directions, weights):
    """TOPSIS 相对贴近度。返回 C_i (n,) 与排名 (n,)"""
    Z = _standardize(X, directions) * weights
    pos, neg = Z.max(axis=0), Z.min(axis=0)
    dp = np.sqrt(((Z - pos) ** 2).sum(axis=1))
    dn = np.sqrt(((Z - neg) ** 2).sum(axis=1))
    C = dn / (dp + dn)
    rank = pd.Series(C).rank(ascending=False).astype(int).to_numpy()
    return C, rank


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit("用法：python entropy_topsis.py <数据.csv> <对象列名> [指标列,方向;指标列,方向...]\n"
                 "示例：python entropy_topsis.py cities.csv 城市 数字化水平,+;人均GDP,+;失业率,-")
    df = pd.read_csv(sys.argv[1])
    obj_col = sys.argv[2]
    spec = sys.argv[3] if len(sys.argv) > 3 else None
    cols = [c for c in df.columns if c != obj_col]
    directions = ["+"] * len(cols)
    if spec:
        pairs = [s.split(",") for s in spec.split(";")]
        cols = [p[0].strip() for p in pairs]
        directions = [p[1].strip() for p in pairs]
    X = df[cols].to_numpy()
    w, _ = entropy_weight(X, directions)
    C, rank = topsis(X, directions, w)
    out = pd.DataFrame({obj_col: df[obj_col], "得分_C": C.round(4), "排名": rank})
    out = out.sort_values("排名")
    print("熵值法权重：")
    for c, wi in zip(cols, w):
        print(f"  {c}: {wi:.4f}")
    print(f"权重合计 = {w.sum():.6f}（应为 1）")
    print("\nTOPSIS 排名前 10：")
    print(out.head(10).to_string(index=False))
    out.to_csv("综合评价结果.csv", index=False, encoding="utf-8-sig")
    print("\n完整结果已写入 综合评价结果.csv")
