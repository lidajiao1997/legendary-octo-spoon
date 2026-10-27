# -*- coding: utf-8 -*-
"""
路线 B：年报文本词频构造解释变量（模板）
流程：读取年报 txt（文件名 <代码>_<年份>.txt）-> jieba 分词 -> 统计词典词频 -> ln(词频+1)
用法：python text_freq.py <年报txt目录> [输出.csv]
依赖：pip install jieba pandas
词典：KEYWORDS 按研究主题替换（示例为人工智能词表，参考姚加权等 2024 的做法自行扩充）
"""

import os
import re
import sys
import jieba
import numpy as np
import pandas as pd

TXT_DIR = sys.argv[1] if len(sys.argv) > 1 else "reports"
OUT = sys.argv[2] if len(sys.argv) > 2 else "ai_freq.csv"

# 范围：MD&A 段落定位（年报 txt 中按标题截取；找不到则回退全文，稳健性检验用全文口径）
MDA_PAT = re.compile(r"(管理层讨论与分析|经营情况讨论和分析)([\s\S]*?)(第四节|第三节|重要事项|$)")

KEYWORDS = [
    "人工智能", "机器学习", "深度学习", "神经网络", "自然语言处理", "计算机视觉",
    "智能算法", "大数据分析", "智能决策", "知识图谱", "智能机器人",
]

if not os.path.isdir(TXT_DIR):
    sys.exit(f"[错误] 找不到年报目录：{TXT_DIR}\n"
             f"目录内 txt 文件请按 <股票代码>_<年份>.txt 命名，如 000001_2023.txt")

for kw in KEYWORDS:
    jieba.add_word(kw, freq=1000)

rows = []
for fn in sorted(os.listdir(TXT_DIR)):
    if not fn.endswith(".txt"):
        continue
    stem = os.path.splitext(fn)[0]
    try:
        code, year = stem.rsplit("_", 1)
    except ValueError:
        print(f"[跳过] 文件名不符合 <代码>_<年份>.txt：{fn}")
        continue
    with open(os.path.join(TXT_DIR, fn), encoding="utf-8") as f:
        text = f.read()
    m = MDA_PAT.search(text)
    scope = m.group(2) if m else text
    words = jieba.lcut(scope)
    freq = sum(1 for w in words if w in KEYWORDS)
    full_freq = sum(1 for w in jieba.lcut(text) if w in KEYWORDS)   # 全文口径（稳健性用）
    rows.append({"code": code, "year": int(year), "freq_mda": freq,
                 "freq_all": full_freq})

df = pd.DataFrame(rows).sort_values(["code", "year"])
df["ln_ai"] = (df["freq_mda"] + 1).map(lambda v: round(float(np.log(v)), 4))
df["ln_ai_all"] = (df["freq_all"] + 1).map(lambda v: round(float(np.log(v)), 4))
df.to_csv(OUT, index=False, encoding="utf-8-sig")
print(f"完成：{len(df)} 条 -> {OUT}")
print(df.head(10).to_string(index=False))
