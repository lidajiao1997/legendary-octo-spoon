* ============================================================
* thesis_utils.ado —— mgmt-thesis 通用工具程序集（Stata 16 基线）
* ------------------------------------------------------------
* 用途：把论文实证中反复出现的操作封装成通用程序，学生换选题时
*       只改参数不改逻辑。
* 安装（二选一）：
*   1) 复制本文件到 PERSONAL 目录：di c(sysdir_personal) 查看位置，
*      之后任何 do 文件可直接调用其中的程序；
*   2) 在 do 文件开头写 `do "路径/thesis_utils.ado"`，每次运行时载入。
* 内含程序：
*   thesis_env   —— 环境自检（版本、外部包）+ 开 log
*   thesis_winsor —— 按 1%/99% 分位缩尾（可调分位）
*   thesis_table —— 统一格式导出 outreg2 结果表
*   thesis_event —— 生成事件研究/DID 平行趋势的相对时间虚拟变量
* 依赖：outreg2（仅 thesis_table 需要）
* ============================================================

* ============================================================
* 1. thesis_env：环境自检 + 开 log
* 用法：thesis_env, log("实证分析") pkgs(reghdfe coefplot)
*   log()  日志文件名（自动加时间戳）
*   pkgs() 需要检查的外部包清单（空格分隔），缺失时给出安装命令
* 效果：版本 < 16 直接报错退出；缺包给出提示；随后开始记录 log
* ============================================================
capture program drop thesis_env
program define thesis_env
    version 16
    syntax , LOGname(string) [pkgs(string)]

    * ---- 版本检查：低于 16 不兼容模板语法，直接停止 ----
    if c(stata_version) < 16 {
        di as error "本模板要求 Stata 16 及以上，当前版本为 " ///
            c(stata_version) "。请升级或联系指导教师。"
        exit 199
    }
    di as text "Stata 版本检查通过：" c(stata_version) " " c(flavor)

    * ---- 批处理下 profile.do 可能不生效，显式提示 PLUS 路径 ----
    if "$S_CONSOLE" != "" | c(mode) == "batch" {
        di as text "（批处理模式提醒：若外部包报 r(199)，在 do 开头加" ///
            `" sysdir set PLUS "外部包目录" "）"'
    }

    * ---- 逐个检查外部包 ----
    foreach p of local pkgs {
        capture which `p'
        if _rc != 0 {
            di as error "缺少外部包：`p'。请手动执行：ssc install `p', replace"
            di as error "（部分环境网络受限，安装包可向学校镜像或指导教师索取）"
        }
        else {
            di as text "外部包就绪：`p'"
        }
    }

    * ---- 开 log（带时间戳，避免覆盖）----
    local date = subinstr("${S_DATE}", " ", "_", .)
    local time = subinstr("${S_TIME}", ":", "-", .)
    log using "`logname'_`date'_`time'.log", text replace
    di as text "日志已开启：`logname'_`date'_`time'.log"
end

* ============================================================
* 2. thesis_winsor：分位缩尾（默认 1%/99%）
* 用法：thesis_winsor ln_x size lev, p(1 99)
* 原理：把超出分位点的值替换为分位点值本身，抑制极端值对回归的
*       干扰；顺序应为先删缺失、再缩尾、再删缺失（见 pipeline.md）
* ============================================================
capture program drop thesis_winsor
program define thesis_winsor
    syntax varlist(numeric) [, p(numlist ascending min=2 max=2)]
    if "`p'" == "" local p "1 99"
    tokenize `p'
    local lo `1'
    local hi `2'
    foreach var of varlist `varlist' {
        quietly count if missing(`var')
        local nmiss = r(N)
        quietly _pctile `var', p(`lo' `hi')
        quietly replace `var' = r(r1) if `var' < r(r1) & !missing(`var')
        quietly replace `var' = r(r2) if `var' > r(r2) & !missing(`var')
        di as text "缩尾完成：`var'（`lo'%=`r(r1)'，`hi'%=`r(r2)'，缺失 `nmiss' 例）"
    }
end

* ============================================================
* 3. thesis_table：统一格式导出回归表（outreg2 封装）
* 用法：thesis_table m1 m2 m3 using "基础回归.xlsx", title("基准回归")
* 统一格式：dec(4)、标注公司/年度固定效应、中文标题；
*   追加模式：换一张表时加 replace；同一张表追加模型时不加 replace
* ============================================================
capture program drop thesis_table
program define thesis_table
    version 16
    syntax namelist(min=1 max=30) using/ , [TITle(string) REPlace ADDtext(string)]
    * 鲁棒性：批处理下 CWD 可能被 do 调用切走（实测输出会落到安装目录）。
    * 相对路径一律锚定到 $projdir（模板在第 0 节用 global projdir = c(pwd) 记录）
    if "$projdir" != "" & substr("`using'", 2, 1) != ":" {
        local using "$projdir/`using'"
    }
    local at "公司固定效应, 是, 年度固定效应, 是"
    if "`addtext'" != "" local at "`at', `addtext'"
    if "`title'" == "" local title "回归结果"
    if "`replace'" != "" {
        outreg2 [`namelist'] using `using', replace excel dec(4) ///
            addtext(`at') title("`title'")
    }
    else {
        outreg2 [`namelist'] using `using', excel dec(4) ///
            addtext(`at') title("`title'")
    }
    di as text "已导出：`using'（标题：`title'）"
end

* ============================================================
* 4. thesis_event：生成事件研究/平行趋势相对时间虚拟变量
* 用法（先手工生成 rel 变量 = year - 政策年份，对照组为缺失）：
*   thesis_event rel, pre(5) post(5) controlgroup(treat)
*   之后回归加入 pre5-pre2 current post1-post5（基准期 = 前一期）
*   controlgroup() 指定对照组指示变量：其各期虚拟变量取 0
* ============================================================
capture program drop thesis_event
program define thesis_event
    version 16
    syntax varname(numeric) , PRE(integer) POST(integer) [controlgroup(varname)]
    local rel `varlist'

    * 政策前：pre5..pre2（-1 期留作基准期，避免完全共线）
    forvalues k = `pre'(-1)2 {
        quietly gen pre`k' = (rel <= -`k')
    }
    * 政策当年
    quietly gen current = (rel == 0)
    * 政策后：post1..postN
    forvalues k = 1/`post' {
        quietly gen post`k' = (rel >= `k')
    }
    * 对照组：全部取 0（其相对时间未定义）
    if "`controlgroup'" != "" {
        foreach v of varlist pre* post* current {   // 注意：通配符不能写成 pre*-post* 范围形式
            quietly replace `v' = 0 if `controlgroup' == 0
        }
    }
    di as text "已生成相对时间虚拟变量：pre`pre'-pre2、current、post1-post`post'"
    di as text "（基准期 = 政策前一期 -1；回归时不要加入 pre1，否则共线）"
end
