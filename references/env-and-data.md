# 软硬件环境与数据权限定义

本文件回答两个前置问题：**跑这套流程需要什么环境？数据从哪里来、没权限怎么办？**
选型阶段（route-selection.md 第 2、3 步）用它做可行性检查；动手写代码前用它做环境预检。

---

## 一、学生侧：六路线软硬件门槛

| 路线 | 软件最低要求 | 硬件/其他 | 环境坑提示 |
|------|------------|----------|-----------|
| A 财务指标 | Stata 12+（模板按 16 写，`version 16`），reghdfe/estout/outreg2 | 内存 ≥ 4G（面板十万行内无压力） | reghdfe 需同步装 ftools；离线安装包找导师或学校镜像 |
| B 文本+专利 | A 的全部 + Python 3.9+（jieba、pandas、numpy） | 年报文本存储约 2-5G | jieba 装不上可用学校内网源；无 Python 时降级方案见 route-text-patent.md |
| C 政策评估 | 同 A（DID 需 reghdfe；进阶 csdid 可选） | 同 A | 批处理跑 reghdfe 前先 `capture which reghdfe` 自检 |
| D 问卷调研 | SPSS 20+（最稳）或 Python（本技能 survey_pipeline.py） | 无特殊 | Python 版已去 factor_analyzer 依赖，装 pandas/numpy/semopy 即可；semopy 需 Python 3.8+ |
| E 事件研究 | Stata（配 CSMAR/CSMAR 交易数据库导出的日收益 csv） | 无特殊 | 数据量大时（10 年日频×5000 股）用 `import delimited` 分块或转 dta |
| F 案例/评价 | 案例支线：仅 Word；评价支线：Excel 或 Python（entropy_topsis.py，仅需 numpy/pandas） | 无特殊 | Excel 手工版熵值法步骤见 route-case-index.md |

**通用底线**：能开 log 的完整 Stata（Stata/SE 或 MP，不要用受限的 Be 版）；Python 用 Anaconda 或官方发行版，避免应用商店版（路径问题多）。

## 二、学生侧：数据库权限矩阵（选型一票否决的依据）

| 数据源 | 覆盖内容 | 服务的路线 | 常见获取方式 | 没有权限时的免费/降级替代 |
|--------|---------|-----------|------------|------------------------|
| CSMAR（国泰安） | 财务指标、治理结构、研发、专利、日收益率等 | A/B/C/E 主力 | 学校图书馆订购；个人账号很贵 | 锐思 RESSET（若学校有）、网易财经/新浪财经手工摘录（小样本）、巨潮资讯网公告 |
| Wind/同花顺 iFinD | 同上 + 行业分类 | A/B/C/E 替代源 | 商学院实验室常有 | 同上 |
| 国家知识产权局/CSMAR 专利子库 | 发明、实用新型专利申请与授权数 | B 的 Y | CSMAR 子库或 incoPat | 国家知识产权局官网专利检索批量导出（小样本可行） |
| 年报全文（MD&A 文本） | 文本词频原料 | B 的 X | 巨潮资讯网免费下载 PDF（cninfo.com.cn） | 天然免费——巨潮不需要任何账号，按代码+年份逐份下载 |
| 政策试点名单 | 低碳城市、智慧城市、沪深港通标的等 | C 的处理组 | 政府文件、部委公告、已发表论文附录 | **天然免费**——发文机关官网公开 |
| CSMAR/CNRDS 交易数据 | 个股与市场日收益率 | E | 学校数据库 | 网易财经历史数据导出（免费，需清洗复权）；akshare/tushare（免费额度够本科用） |
| 统计年鉴/城市面板 | 地级市指标 | F 评价支线 | 国家统计局、各省统计局官网 | **天然免费** |
| 问卷渠道 | 一手调查数据 | D | 问卷星/问卷网免费版即可（注意导出原始数据需核对） | 无替代——收不到 200+ 份就别选 D |

**判定规则**（对应 route-selection.md 第 2 步）：
1. 学校有任何付费库（CSMAR/Wind/RESSET）→ A/B/C/E 全部可行
2. 一个付费库都没有 → 剩 D（能收问卷）和 F（统计年鉴免费）；E 可用免费交易数据做小样本，但要提醒数据清洗工作量大
3. B 的文本原料（巨潮年报）和 C 的试点名单（政府文件）永远免费，瓶颈只在愿不愿做文本处理和面板清洗

## 三、执行侧：环境约定（按自己环境替换 `<...>` 占位符）

以下规范经 Windows + Stata 16 实测验证。路径均为占位符，使用者按本机环境替换。

### Stata 批处理调用规范（实测验证）

- 基准可执行文件：`<Stata安装目录>\StataSE-64.exe`（代码基准为 Stata 16，`version 16`；更高版本仅供测试对照，不作代码基准）
- **Windows 批处理调用推荐 PowerShell**：`Start-Process -FilePath "<Stata安装目录>\StataSE-64.exe" -ArgumentList '/e','do',"<绝对Windows路径>.do" -WorkingDirectory "<do所在目录>" -Wait`；Git Bash 直调 `/e do` 会因路径转换报 r(671)
- **批处理下 profile.do 不生效**：do 文件开头需显式 `sysdir set PLUS "<外部包目录>"`，否则 reghdfe/outreg2 等报 r(199)
- do 文件内路径一律用绝对路径；日志 `log using` 带 `replace` 前先确认不覆盖旧 log
- 注意：外部包若由更高版本 Stata 编译（.mo 文件），低版本加载依赖 moremata 的类包（medeff/khb）可能报 "created by newer version"；reghdfe/esttab/outreg2 等纯 .ado 包不受影响

### Python 环境

- 解释器：任一 Python 3.9+（Anaconda 发行版最佳），无特殊路径要求
- 技能脚本实测可用依赖：pandas、numpy、jieba、semopy、statsmodels、scipy、tabulate、pingouin
- **已剔除的依赖**：factor_analyzer（与新 sklearn 不兼容）——KMO/Bartlett/Harman 用纯 numpy 实现（survey_pipeline.py 内置），无需额外安装
- 运行技能脚本统一用 CLI 传参：`python <脚本> <输入> <输出>`，脚本内不写死路径
- 沙箱/受限网络环境下 ssc install 会失败，需装新包时先手动准备安装包

### 环境预检清单（动手前 30 秒过一遍）

- [ ] do 文件：`version 16`、`sysdir set PLUS`、`capture which` 关键包三件套在开头
- [ ] PowerShell Start-Process + `-Wait`，读完 log 再判结果（grep `r(\d+);`）
- [ ] Python：确认用目标解释器；新依赖先 `pip install`，装不上改纯 numpy/pandas 实现
- [ ] 数据文件：UTF-8（csv 带 BOM 更稳），xlsx 中文列名直接可用；GBK 乱码 zip 用 Python zipfile 按 gbk 重解压
- [ ] 输出：新文件不覆盖同名；结果文件落工作目录而非技能目录
