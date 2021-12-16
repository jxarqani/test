#!/bin/bash
## Author: SuperManito
## Modified: 2021-12-16

ShellDir=${WORK_DIR}/shell
. $ShellDir/share.sh

## 匹配脚本，通过各种判断将得到的必要信息传给接下来运行的函数或命令
## 最终得到的信息："FileName" 脚本名称（去后缀）、"FileSuffix" 脚本后缀、"FileFormat" 脚本类型、"WhichDir" 脚本所在目录（绝对路径）
## 不论何种匹配方式或查找方式当未指定脚本类型但存在同名脚本时，执行优先级为 JavaScript > Python > TypeScript > Shell
function Find_Script() {
    local InputContent=$1
    FileName=""
    WhichDir=""
    FileFormat=""

    ## 匹配指定路径下的脚本
    function MatchingPathFile() {
        local AbsolutePath PwdTmp FileNameTmp WhichDirTmp
        ## 判定传入的是绝对路径还是相对路径
        echo ${InputContent} | grep "$RootDir/" -q
        if [ $? -eq 0 ]; then
            AbsolutePath=${InputContent}
        else
            echo ${InputContent} | grep "\.\./" -q
            if [ $? -eq 0 ]; then
                PwdTmp=$(pwd | perl -pe "{s|/$(pwd | awk -F '/' '{printf$NF}')||g;}")
                AbsolutePath=$(echo "${InputContent}" | perl -pe "{s|\.\./|${PwdTmp}/|;}")
            else
                if [[ $(pwd) == "/root" ]]; then
                    AbsolutePath=$(echo "${InputContent}" | perl -pe "{s|\./||; s|^*|$RootDir/|;}")
                else
                    AbsolutePath=$(echo "${InputContent}" | perl -pe "{s|\./||; s|^*|$(pwd)/|;}")
                fi
            fi
        fi
        ## 判定传入是否含有后缀格式
        FileNameTmp=${AbsolutePath##*/}
        WhichDirTmp=${AbsolutePath%/*}
        echo ${FileNameTmp} | grep "\." -q
        if [ $? -eq 0 ]; then
            if [ -f ${AbsolutePath} ]; then
                FileSuffix=${FileNameTmp##*.}
                ## 判断并定义脚本类型
                case ${FileSuffix} in
                js)
                    FileFormat="JavaScript"
                    ;;
                py)
                    FileFormat="Python"
                    ;;
                ts)
                    FileFormat="TypeScript"
                    ;;
                sh)
                    FileFormat="Shell"
                    ;;
                *)
                    echo -e "\n$ERROR 项目不支持运行 .${FileSuffix} 类型的脚本！\n"
                    exit ## 终止退出
                    ;;
                esac
                FileName=${FileNameTmp%.*}
                WhichDir=${WhichDirTmp}
            fi
        else
            if [ -f ${WhichDirTmp}/${FileNameTmp}.js ]; then
                FileName=${FileNameTmp}
                FileFormat="JavaScript"
                WhichDir=${WhichDirTmp}
            elif [ -f ${WhichDirTmp}/${FileNameTmp}.py ]; then
                FileName=${FileNameTmp}
                FileFormat="Python"
                WhichDir=${WhichDirTmp}
            elif [ -f ${WhichDirTmp}/${FileNameTmp}.ts ]; then
                FileName=${FileNameTmp}
                FileFormat="TypeScript"
                WhichDir=${WhichDirTmp}
            elif [ -f ${WhichDirTmp}/${FileNameTmp}.sh ]; then
                FileName=${FileNameTmp}
                FileFormat="Shell"
                WhichDir=${WhichDirTmp}
            fi
        fi

        ## 判定变量是否存在否则报错终止退出
        if [ -n "${FileName}" ] && [ -n "${WhichDir}" ]; then
            ## 添加依赖文件
            [[ ${FileFormat} == "JavaScript" ]] && [[ ${WhichDir} != $ScriptsDir ]] && Check_Moudules $WhichDir
            ## 定义日志路径
            if [[ $(echo ${AbsolutePath} | awk -F '/' '{print$3}') == "own" ]]; then
                LogPath="$LogDir/$(echo ${AbsolutePath} | awk -F '/' '{print$4}')_${FileName}"
            else
                LogPath="$LogDir/${FileName}"
            fi
            Make_Dir ${LogPath}
        else
            echo -e "\n$ERROR 在 ${BLUE}${AbsolutePath%/*}${PLAIN} 目录未检测到 ${BLUE}${AbsolutePath##*/}${PLAIN} 脚本的存在，请重新确认！\n"
            exit ## 终止退出
        fi
    }

    ## 匹配 Scripts 目录下的脚本
    function MatchingScriptsFile() {
        local FileNameTmp1 FileNameTmp2 FileNameTmp3 SeekDir SeekExtension
        ## 定义目录范围，优先级为 /jd/scripts > /jd/scripts/activity > /jd/scripts/utils > /jd/scripts/backUp
        SeekDir="$ScriptsDir $ScriptsDir/activity $ScriptsDir/utils $ScriptsDir/backUp"
        ## 定义后缀格式
        SeekExtension="js py ts sh"

        ## 判定传入是否含有后缀格式
        ## 如果存在后缀格式则为精确查找，否则为模糊查找，仅限关于脚本名称的定位目录除外
        ## 当模糊查找的脚本名称含有 "jd_" 或 "jx_" 开头时，支持省略、去掉该前缀后传入，同时当存在相同类型的脚本时前者优先级大于后者

        ## 判定是否传入了后缀格式
        echo ${InputContent} | grep "\." -q
        ## 精确查找
        if [ $? -eq 0 ]; then
            ## 判断并定义脚本类型
            FileSuffix=${InputContent##*.}
            case ${FileSuffix} in
            js)
                FileFormat="JavaScript"
                ;;
            py)
                FileFormat="Python"
                ;;
            ts)
                FileFormat="TypeScript"
                ;;
            sh)
                FileFormat="Shell"
                ;;
            *)
                echo -e "\n$ERROR 项目不支持运行 .${FileSuffix} 类型的脚本！\n"
                exit ## 终止退出
                ;;
            esac
            for dir in ${SeekDir}; do
                if [ -f ${dir}/${InputContent} ]; then
                    FileName=${InputContent%.*}
                    WhichDir=${dir}
                    break
                fi
            done
        ## 模糊查找
        else
            FileNameTmp1=$(echo ${InputContent} | perl -pe "{s|\.js||; s|\.py||; s|\.ts||; s|\.sh||}")
            FileNameTmp2=$(echo ${FileNameTmp1} | perl -pe "{s|jd_||; s|^|jd_|}")
            FileNameTmp3=$(echo ${FileNameTmp1} | perl -pe "{s|jx_||; s|^|jx_|}")
            for dir in ${SeekDir}; do
                for ext in ${SeekExtension}; do
                    ## 第一种名称类型
                    if [ -f ${dir}/${FileNameTmp1}\.${ext} ]; then
                        FileName=${FileNameTmp1}
                        WhichDir=${dir}
                        FileSuffix=${ext}
                        break 2
                    ## 第二种名称类型
                    elif [ -f ${dir}/${FileNameTmp2}\.${ext} ]; then
                        FileName=${FileNameTmp2}
                        WhichDir=${dir}
                        FileSuffix=${ext}
                        break 2
                    ## 第三种名称类型
                    elif [ -f ${dir}/${FileNameTmp3}\.${ext} ]; then
                        FileName=${FileNameTmp3}
                        WhichDir=${dir}
                        FileSuffix=${ext}
                        break 2
                    fi
                done
            done

            ## 判断并定义脚本类型
            if [ -n "${FileName}" ] && [ -n "${WhichDir}" ]; then
                case ${FileSuffix} in
                js)
                    FileFormat="JavaScript"
                    ;;
                py)
                    FileFormat="Python"
                    ;;
                ts)
                    FileFormat="TypeScript"
                    ;;
                sh)
                    FileFormat="Shell"
                    ;;
                esac
            fi
        fi

        ## 判定变量是否存在否则报错终止退出
        if [ -n "${FileName}" ] && [ -n "${WhichDir}" ]; then
            ## 添加依赖文件
            [[ ${FileFormat} == "JavaScript" ]] && [[ ${WhichDir} != $ScriptsDir ]] && Check_Moudules $WhichDir
            ## 定义日志路径
            LogPath="$LogDir/${FileName}"
            Make_Dir ${LogPath}
        else
            echo -e "\n$ERROR 在 ${BLUE}$ScriptsDir${PLAIN} 目录下的根目录以及 ${BLUE}./activity${PLAIN} ${BLUE}./backUp${PLAIN} ${BLUE}./utils${PLAIN} 三个子目录范围内均未检测到 ${BLUE}${InputContent}${PLAIN} 脚本的存在，请重新确认！\n"
            exit ## 终止退出
        fi
    }

    ## 匹配位于远程仓库的脚本
    function MatchingRemoteFile() {
        local DownloadJudge RepositoryJudge ProxyJudge RepositoryName InputContentFormat
        local FileNameTmp=${InputContent##*/}

        ## 判断并定义脚本类型
        FileSuffix=${FileNameTmp##*.}
        case ${FileSuffix} in
        js)
            FileFormat="JavaScript"
            ;;
        py)
            FileFormat="Python"
            ;;
        ts)
            FileFormat="TypeScript"
            ;;
        sh)
            FileFormat="Shell"
            ;;
        "")
            echo -e "\n$ERROR 未能识别脚本类型，请检查链接是否正确！\n"
            exit ## 终止退出
            ;;
        *)
            echo -e "\n$ERROR 项目不支持运行 ${BLUE}.${FileSuffix}${PLAIN} 类型的脚本！\n"
            exit ## 终止退出
            ;;
        esac

        ## 判断来源仓库
        RepositoryName=$(echo ${InputContent} | grep -Eo "github|gitee|gitlab")
        case ${RepositoryName} in
        github)
            RepositoryJudge=" Github "
            ;;
        gitee)
            RepositoryJudge=" Gitee "
            ;;
        gitlab)
            RepositoryJudge=" GitLab "
            ;;
        *)
            RepositoryJudge=""
            ;;
        esac

        ## 纠正链接地址（将传入的链接地址转换为对应代码托管仓库的raw原始文件链接地址）
        echo ${InputContent} | grep "\.com\/.*\/blob\/.*" -q
        if [ $? -eq 0 ]; then
            if [[ ${RepositoryJudge} == " Github " ]]; then
                echo ${InputContent} | grep "github\.com\/.*\/blob\/.*" -q
                if [ $? -eq 0 ]; then
                    InputContentFormat=$(echo ${InputContent} | perl -pe "{s|github\.com|raw\.githubusercontent\.com/|g; s|\/blob\/|\/|g}")
                else
                    InputContentFormat=${InputContent}
                fi
            elif [[ ${RepositoryJudge} == " Gitee " ]]; then
                InputContentFormat=$(echo ${InputContent} | sed "s/\/blob\//\/raw\//g")
            else
                InputContentFormat=${InputContent}
            fi
        else
            InputContentFormat=${InputContent}
        fi

        ## 判定是否使用代理
        if [[ ${DOWNLOAD_PROXY} == true ]]; then
            ProxyJudge="使用代理"
            DownloadJudge="https://ghproxy.com/"
        else
            ProxyJudge=""
            DownloadJudge=""
        fi

        ## 拉取脚本
        echo -en "\n$WORKING 正在从${RepositoryJudge}远程仓库${ProxyJudge}下载 ${FileNameTmp} 脚本..."
        wget -q --no-check-certificate "${DownloadJudge}${InputContentFormat}" -O "$ScriptsDir/${FileNameTmp}.new" -T 8
        local ExitStatus=$?
        echo ''

        ## 判定拉取结果
        if [[ $ExitStatus -eq 0 ]]; then
            mv -f "$ScriptsDir/${FileNameTmp}.new" "$ScriptsDir/${FileNameTmp}"
            case ${RUN_MODE} in
            normal)
                RunModJudge="依次"
                ;;
            concurrent)
                RunModJudge="并发"
                ;;
            esac
            echo ''
            ## 等待动画
            local spin=('.   ' '..  ' '... ' '....')
            local n=0
            while (true); do
                ((n++))
                echo -en "\033[?25l$COMPLETE 下载完成，倒计时 3 秒后开始${RunModJudge}执行${spin[$((n % 4))]}${PLAIN}" "\r"
                sleep 0.3
                [ $n = 10 ] && echo -e "\033[?25h\n${PLAIN}" && break
            done
            FileName=${FileNameTmp%.*}
            WhichDir=$ScriptsDir
            ## 定义日志路径
            LogPath="$LogDir/${FileName}"
            Make_Dir ${LogPath}
            RUN_REMOTE="true"
        else
            [ -f "$ScriptsDir/${FileNameTmp}.new" ] && rm -rf "$ScriptsDir/${FileNameTmp}.new"
            echo -e "\n$ERROR 脚本 ${FileNameTmp} 下载失败，请检查目标 URL 地址是否正确或网络连通性问题...\n"
            exit ## 终止退出
        fi
    }

    ## 检测环境，添加依赖文件
    function Check_Moudules() {
        local CurrentDir=$(pwd)
        local WorkDir=$1
        cd $WorkDir
        [ ! -f $WorkDir/jdCookie.js ] && cp -rf $UtilsDir/jdCookie.js .
        [ ! -f $WorkDir/USER_AGENTS.js ] && cp -rf $UtilsDir/USER_AGENTS.js .
        cp -rf $FileSendNotify .
        cd $CurrentDir
    }

    ## 根据传入内容判断匹配方式（主要）
    echo ${InputContent} | grep "/" -q
    if [ $? -eq 0 ]; then
        ## 判定传入的是路径还是URL
        echo ${InputContent} | grep -Eq "http.*:"
        if [ $? -eq 0 ]; then
            MatchingRemoteFile
        else
            MatchingPathFile
        fi
    else
        MatchingScriptsFile
    fi

    ## 针对较旧的处理器架构进行一些处理
    case ${ARCH} in
    armv7l | armv6l)
        if [[ ${RUN_MODE} == "concurrent" ]]; then
            echo -e "\n$ERROR 检测到当前使用的是32位处理器，考虑到性能不佳已禁用并发功能！\n"
            exit ## 终止退出
        fi
        case ${FileFormat} in
        Python | TypeScript)
            echo -e "\n$ERROR 宿主机的处理器架构不支持运行 Python 和 TypeScript 脚本，建议更换运行环境！\n"
            exit ## 终止退出
            ;;
        esac
        ;;
    esac
}

## 随机延迟
function Random_Delay() {
    if [[ -n ${RandomDelay} ]] && [[ ${RandomDelay} -gt 0 ]]; then
        local CurMin=$(date "+%-M")
        ## 当时间处于每小时的 0~3,30,58~59 分时不延迟
        if [[ ${CurMin} -gt 3 && ${CurMin} -lt 30 ]] || [[ ${CurMin} -gt 31 && ${CurMin} -lt 58 ]]; then
            CurDelay=$((${RANDOM} % ${RandomDelay} + 1))
            echo -en "\n$WORKING 已启用随机延迟，此任务将在 ${CurDelay} 秒后开始运行..."
            sleep ${CurDelay}
        else
            echo -e "\n$WORKING 检测到当前处于整点，为了适配定时任务随机延迟在此时间段内不会生效，开始执行任务...\n"
        fi
    fi
}

## 判定账号是否存在
function ExistenceJudgment() {
    local Num=$1
    local Tmp=Cookie$Num
    if [[ -z ${!Tmp} ]]; then
        echo -e "\n$ERROR 账号 ${BLUE}$Num${PLAIN} 不存在，请重新确认！\n"
        exit ## 终止退出
    fi
}

## 普通执行
function Run_Normal() {
    local InputContent=$1
    local Accounts UserNum LogFile
    ## 匹配脚本
    Find_Script ${InputContent}
    ## 导入配置文件
    Import_Config ${FileName}
    ## 统计账号数量
    Count_UserSum

    ## 组合账号变量
    function Combine_Account() {
        local Num=$1
        local Tmp1=Cookie$Num
        local Tmp2=${!Tmp1}
        local CombinAll="${COOKIE_TMP}&${Tmp2}"
        COOKIE_TMP=$(echo $CombinAll | perl -pe "{s|^&||}")
    }

    ## 加载账号
    if [[ ${RUN_DESIGNATED} == true ]]; then
        local Accounts=$(echo ${DESIGNATED_NUMS} | perl -pe '{s|,| |g}')
        for UserNum in ${Accounts}; do
            echo ${UserNum} | grep "-" -q
            if [ $? -eq 0 ]; then
                if [[ ${UserNum%-*} -lt ${UserNum##*-} ]]; then
                    for ((i = ${UserNum%-*}; i <= ${UserNum##*-}; i++)); do
                        ExistenceJudgment $i
                        Combine_Account $i
                    done
                else
                    Help
                    echo -e "$ERROR 检测到无效参数值 ${BLUE}${UserNum}${PLAIN} ，账号区间语法有误，请重新输入！\n"
                    exit ## 终止退出
                fi
            else
                ExistenceJudgment $UserNum
                Combine_Account $UserNum
            fi
        done
        ## 声明变量
        export JD_COOKIE=${COOKIE_TMP}
    else
        Combin_Cookie
    fi

    ## 处理其它参数
    if [[ ${RUN_RAPID} != true ]]; then
        ## 同步定时清单
        Synchronize_Crontab
        Combin_ShareCodes
    fi
    [[ ${RUN_DELAY} == true ]] && Random_Delay

    ## 进入脚本所在目录
    cd ${WhichDir}
    ## 定义日志文件
    LogFile="${LogPath}/$(date "+%Y-%m-%d-%H-%M-%S").log"
    ## 执行脚本
    if [[ ${RUN_BACKGROUND} == true ]]; then
        ## 记录执行开始时间
        echo -e "[$(date "${TIME_FORMAT}" | cut -c1-23)] 执行开始，后台运行不记录结束时间\n" >>${LogFile}
        case ${FileFormat} in
        JavaScript)
            if [[ ${EnableGlobalProxy} == true ]]; then
                node -r 'global-agent/bootstrap' ${FileName}.js 2>&1 &>>${LogFile} &
            else
                node ${FileName}.js 2>&1 &>>${LogFile} &
            fi
            ;;
        Python)
            python3 -u ${FileName}.py 2>&1 &>>${LogFile} &
            ;;
        TypeScript)
            ts-node-transpile-only ${FileName}.ts 2>&1 &>>${LogFile} &
            ;;
        Shell)
            bash ${FileName}.sh 2>&1 &>>${LogFile} &
            ;;
        esac
        echo -e "\n$COMPLETE 已部署当前任务并于后台运行中，如需查询脚本运行记录请前往 ${BLUE}${LogPath}${PLAIN} 目录查看相关日志\n"
    else
        ## 记录执行开始时间
        echo -e "[$(date "${TIME_FORMAT}" | cut -c1-23)] 执行开始\n" >>${LogFile}
        case ${FileFormat} in
        JavaScript)
            if [[ ${EnableGlobalProxy} == true ]]; then
                node -r 'global-agent/bootstrap' ${FileName}.js 2>&1 | tee -a ${LogFile}
            else
                node ${FileName}.js 2>&1 | tee -a ${LogFile}
            fi
            ;;
        Python)
            python3 -u ${FileName}.py 2>&1 | tee -a ${LogFile}
            ;;
        TypeScript)
            ts-node-transpile-only ${FileName}.ts 2>&1 | tee -a ${LogFile}
            ;;
        Shell)
            bash ${FileName}.sh 2>&1 | tee -a ${LogFile}
            ;;
        esac
        ## 记录执行结束时间
        echo -e "\n[$(date "${TIME_FORMAT}" | cut -c1-23)] 执行结束" >>${LogFile}
    fi

    ## 判断远程脚本执行后是否删除
    if [[ ${RUN_REMOTE} == true && ${AutoDelRawFiles} == true ]]; then
        rm -rf "${WhichDir}/${FileName}.${FileSuffix}"
    fi
}

## 并发执行
function Run_Concurrent() {
    local InputContent=$1
    local Accounts UserNum LogFile
    ## 匹配脚本
    Find_Script ${InputContent}
    ## 导入配置文件
    Import_Config ${FileName}
    ## 统计账号数量
    Count_UserSum

    function Main() {
        local Num=$1
        local Tmp=Cookie${Num}
        export JD_COOKIE=${!Tmp}
        ## 定义日志文件
        LogFile="${LogPath}/$(date "+%Y-%m-%d-%H-%M-%S")_${Num}.log"
        ## 记录执行开始时间
        echo -e "[$(date "${TIME_FORMAT}" | cut -c1-23)] 执行开始，后台运行不记录结束时间\n" >>${LogFile}
        ## 执行脚本
        case ${FileFormat} in
        JavaScript)
            if [[ ${EnableGlobalProxy} == true ]]; then
                node -r 'global-agent/bootstrap' ${FileName}.js 2>&1 &>>${LogFile} &
            else
                node ${FileName}.js 2>&1 &>>${LogFile} &
            fi
            ;;
        Python)
            python3 -u ${FileName}.py 2>&1 &>>${LogFile} &
            ;;
        TypeScript)
            ts-node-transpile-only ${FileName}.ts 2>&1 &>>${LogFile} &
            ;;
        Shell)
            bash ${FileName}.sh 2>&1 &>>${LogFile} &
            ;;
        esac
    }

    ## 处理其它参数
    if [[ ${RUN_RAPID} != true ]]; then
        ## 同步定时清单
        Synchronize_Crontab
        Combin_ShareCodes
    fi
    [[ ${RUN_DELAY} == true ]] && Random_Delay

    ## 进入脚本所在目录
    cd ${WhichDir}
    ## 加载账号并执行
    if [[ ${RUN_DESIGNATED} == true ]]; then
        ## 判定账号是否存在
        local Accounts=$(echo ${DESIGNATED_NUMS} | perl -pe '{s|,| |g}')
        for UserNum in ${Accounts}; do
            echo ${UserNum} | grep "-" -q
            if [ $? -eq 0 ]; then
                if [[ ${UserNum%-*} -lt ${UserNum##*-} ]]; then
                    for ((i = ${UserNum%-*}; i <= ${UserNum##*-}; i++)); do
                        ExistenceJudgment $i
                    done
                else
                    Help
                    echo -e "$ERROR 检测到无效参数值 ${BLUE}${UserNum}${PLAIN} ，账号区间语法有误，请重新输入！\n"
                    exit ## 终止退出
                fi
            else
                ExistenceJudgment $UserNum
            fi
        done

        for UserNum in ${Accounts}; do
            echo ${UserNum} | grep "-" -q
            if [ $? -eq 0 ]; then
                for ((i = ${UserNum%-*}; i <= ${UserNum##*-}; i++)); do
                    Main $i
                done
            else
                Main ${UserNum}
            fi
        done
    else
        for ((UserNum = 1; UserNum <= ${UserSum}; UserNum++)); do
            for num in ${TempBlockCookie}; do
                [[ $UserNum -eq $num ]] && continue 2
            done
            Main ${UserNum}
        done
    fi
    echo -e "\n$COMPLETE 已部署当前任务并于后台运行中，如需查询脚本运行记录请前往 ${BLUE}${LogPath}${PLAIN} 目录查看相关日志\n"

    ## 判断远程脚本执行后是否删除
    if [[ ${RUN_REMOTE} == true && ${AutoDelRawFiles} == true ]]; then
        rm -rf "${WhichDir}/${FileName}.${FileSuffix}"
    fi
}

## 终止执行
function Process_Kill() {
    local InputContent=$1
    local ProcessShielding="grep|pkill|/bin/bash /usr/local/bin| task "
    local Input
    ## 匹配脚本
    Find_Script ${InputContent}
    local ProcessKeywords="${FileName}\.${FileSuffix}\b"
    ## 判定对应脚本是否存在相关进程
    ps -ef | grep -Ev "grep|pkill" | grep "${FileName}\.${FileSuffix}\b" -wq
    local ExitStatus=$?
    if [[ ${ExitStatus} == 0 ]]; then
        ## 列出进程到的相关进程
        echo -e "\n检测到下列关于 ${BLUE}${FileName}.${FileSuffix}${PLAIN} 脚本的进程："
        echo -e "\n${BLUE}[进程号] [脚本名称]${PLAIN}"
        ps -axo pid,command | grep -E "${FileName}\.${FileSuffix}\b" | grep -Ev "${ProcessShielding}"
        while true; do
            read -p "$(echo -e "\n${BOLD}└ 是否确认终止上述进程 [ Y/n ]：${PLAIN}")" Input
            [ -z ${Input} ] && Input=Y
            case ${Input} in
            [Yy] | [Yy][Ee][Ss])
                break
                ;;
            [Nn] | [Nn][Oo])
                echo -e "\n$COMPLETE 已退出，没有进行任何操作\n"
                exit ## 终止退出
                ;;
            esac
            echo -e "\n$ERROR 输入错误，请重新输入！\n"
        done

        ## 杀死进程
        kill -9 $(ps -ef | grep -E "${ProcessKeywords}" | grep -Ev "${ProcessShielding}" | awk '$0 !~/grep/ {print $2}' | tr -s '\n' ' ') >/dev/null 2>&1
        sleep 1
        kill -9 $(ps -ef | grep -E "${ProcessKeywords}" | grep -Ev "${ProcessShielding}" | awk '$0 !~/grep/ {print $2}' | tr -s '\n' ' ') >/dev/null 2>&1

        ## 验证
        ps -ef | grep -Ev "grep|pkill" | grep "\.${FileSuffix}\b" -wq
        if [ $? -eq 0 ]; then
            ps -axo pid,command | less | grep -E "${ProcessKeywords}" | grep -Ev "${ProcessShielding}"
            echo -e "\n$ERROR 进程终止失败，请尝试手动终止 ${BLUE}kill -9 <pid>${PLAIN}\n"
        else
            echo -e "\n$SUCCESS 已终止相关进程\n"
        fi
    else
        echo -e "\n$ERROR 未检测到与 ${BLUE}${FileName}${PLAIN} 脚本相关的进程，可能此时没有正在运行，请确认！\n"
    fi
}

## 进程清理功能（终止卡死进程释放内存）
function Process_CleanUp() {
    local CheckHour ProcessArray FormatCurrentTime StartTime FormatDiffTime Tmp
    ## 判断检测时间，单位小时
    case $# in
    0)
        CheckHour=6
        ;;
    1)
        CheckHour=$1
        ;;
    esac
    ## 生成进程清单
    ps -axo pid,time,user,start,command | egrep "\.js\b|\.py\b|\.ts\b" | egrep -v "server\.js|pm2|egrep|perl|sed|bash" | grep -E "00:[0-9][0-9]:[0-9][0-9] root" >${FileProcessList}
    if [ -s ${FileProcessList} ]; then
        echo -e "\n$WORKING 开始匹配并清理启动超过 ${BLUE}${CheckHour}${PLAIN} 小时的卡死进程...\n"
        ## 生成进程 PID 数组
        ProcessArray=($(
            cat ${FileProcessList} | awk -F ' ' '{print$1}'
        ))
        ## 定义当前时间戳
        FormatCurrentTime=$(date +%s)
        for ((i = 1; i <= ${#ProcessArray[@]}; i++)); do
            local n=$((i - 1))
            ## 判断启动时间的类型（距离启动超过1天会显示为日期）
            StartTime=$(grep "${ProcessArray[n]}" ${FileProcessList} | awk -F ' ' '{print$4}')
            if [[ ${StartTime} = [0-9][0-9]:[0-9][0-9]:[0-9][0-9] ]]; then
                ## 定义实际时间戳
                Tmp=$(date +%s -d "$(date "+%Y-%m-%d") ${StartTime}")
                [[ ${Tmp} -gt ${FormatCurrentTime} ]] && FormatStartTime=$((${Tmp} - 86400)) || FormatStartTime=${Tmp}
                ## 比较时间
                FormatDiffTime=$((${FormatCurrentTime} - 3600 * ${CheckHour}))
                if [[ ${FormatDiffTime} -gt ${FormatStartTime} ]]; then
                    echo -e "已终止进程：${ProcessArray[n]}  脚本名称：$(grep ${ProcessArray[n]} ${FileProcessList} | awk -F ' ' '{print$NF}')"
                    kill -9 ${ProcessArray[n]} >/dev/null 2>&1
                else
                    continue
                fi
            elif [[ ${StartTime} = [ADFJMNOS][a-z]* ]]; then
                echo -e "已终止进程：${ProcessArray[n]}  脚本名称：$(grep ${ProcessArray[n]} ${FileProcessList} | awk -F ' ' '{print$NF}')"
                kill -9 ${ProcessArray[n]} >/dev/null 2>&1
            fi
        done
        echo -e "\n$COMPLETE 运行结束\n"
        [ -f ${FileProcessList} ] && rm -rf ${FileProcessList}
    else
        echo -e "\n$COMPLETE 未查询到正在运行中的进程\n"
    fi
}

## 账号控制功能
function Cookies_Control() {
    local TRUE_ICON="[✔]"
    local FALSE_ICON="[X]"
    local INTERFACE_URL="https://bean.m.jd.com/bean/signIndex.action"
    case $1 in
    check)
        ## 导入配置文件
        Import_Config
        ## 统计账号数量
        Count_UserSum
        [ -f $FileSendMark ] && rm -rf $FileSendMark

        ## 生成 pt_pin 数组
        function Gen_pt_pin_Array() {
            local Tmp1 Tmp2 i pt_pin_temp
            for ((user_num = 1; user_num <= $UserSum; user_num++)); do
                Tmp1=Cookie$user_num
                Tmp2=${!Tmp1}
                i=$(($user_num - 1))
                pt_pin_temp=$(echo $Tmp2 | perl -pe "{s|.*pt_pin=([^; ]+)(?=;?).*|\1|}")
                pt_pin[i]=$pt_pin_temp
            done
        }

        ## 检测
        function CheckCookie() {
            local InputContent=$1
            local ConnectionTest="$(curl -I -s --connect-timeout 5 ${INTERFACE_URL} -w %{http_code} | tail -n1)"
            local CookieValidityTest="$(curl -s --noproxy "*" "${INTERFACE_URL}" -H "cookie: ${InputContent}")"
            if [[ ${ConnectionTest} == 302 ]]; then
                if [[ ${CookieValidityTest} ]]; then
                    echo -e "${GREEN}${TRUE_ICON}${PLAIN}"
                else
                    echo -e "${RED}${FALSE_ICON}${PLAIN}"
                fi
            else
                sleep 2
                local ConnectionTestAgain="$(curl -I -s --connect-timeout 5 ${INTERFACE_URL} -w %{http_code} | tail -n1)"
                local CookieValidityTestAgain="$(curl -s --noproxy "*" "${INTERFACE_URL}" -H "cookie: ${InputContent}")"
                if [[ ${ConnectionTestAgain} == 302 ]]; then
                    if [[ ${CookieValidityTestAgain} ]]; then
                        echo -e "${GREEN}${TRUE_ICON}${PLAIN}"
                    else
                        echo -e "${RED}${FALSE_ICON}${PLAIN}"
                    fi
                else
                    echo -e "${RED}[ API 请求失败 ]${PLAIN}"
                fi
            fi
        }

        ## 汇总输出以及计算时间
        function Print_Info() {
            local CookieUpdatedDate UpdateTimes TmpDays TmpTime Tmp1 Tmp2 Tmp3
            echo -e "\n检测到本地共有 ${BLUE}$UserSum${PLAIN} 个账号，当前状态信息如下（${TRUE_ICON}为有效，${FALSE_ICON}为无效）："
            for ((m = 0; m < $UserSum; m++)); do
                ## 查询上次更新时间
                FormatPin=$(echo ${pt_pin[m]} | perl -pe '{s|[\.\/\[\]\!\@\#\$\%\^\&\*\(\)]|\\$&|g;}')
                CookieUpdatedDate=$(grep "\#.*上次更新：" $FileConfUser | grep ${FormatPin} | head -1 | perl -pe "{s|pt_pin=.*;||g; s|.*上次更新：||g; s|备注：.*||g; s|[ ]*$||g;}")
                if [[ ${CookieUpdatedDate} ]]; then
                    UpdateTimes="更新日期：[${BLUE}${CookieUpdatedDate}${PLAIN}]"
                    Tmp1=$(($(date -d $(date "+%Y-%m-%d") +%s) - $(date -d "$(echo ${CookieUpdatedDate} | grep -Eo "20[2-9][0-9]-[0-9]{1,2}-[0-9]{1,2}")" +%s)))
                    Tmp2=$(($Tmp1 / 86400))
                    Tmp3=$((30 - $Tmp2))
                    [ -z $CheckCookieDaysAgo ] && TmpDays="2" || TmpDays=$(($CheckCookieDaysAgo - 1))
                    if [ $Tmp3 -le $TmpDays ] && [ $Tmp3 -ge 0 ]; then
                        [ $Tmp3 = 0 ] && TmpTime="今天" || TmpTime="$Tmp3天后"
                        echo -e "账号$((m + 1))：$(printf $(echo ${FormatPin} | perl -pe "s|%|\\\x|g;")) 将在$TmpTime过期" >>$FileSendMark
                    fi
                else
                    UpdateTimes="更新日期：[${BLUE}Unknow${PLAIN}]"
                fi
                sleep 1 ## 降低频率减少出现因查询太快导致API请求失败的情况
                num=$((m + 1))
                echo -e "$num：$(printf $(echo ${FormatPin} | perl -pe "s|%|\\\x|g;")) $(CheckCookie $(grep -E "Cookie[1-9]" $FileConfUser | grep ${FormatPin} | awk -F "[\"\']" '{print$2}'))    ${UpdateTimes}"
            done
        }

        Gen_pt_pin_Array
        Print_Info

        ## 过期提醒推送通知
        if [ -f $FileSendMark ]; then
            echo -e "\n${YELLOW}检测到下面的账号将在近期失效，请注意即时更新！${PLAIN}\n"
            cat $FileSendMark
            sed -i 's/$/&\\n/g' $FileSendMark
            echo ''
            Notify "账号过期提醒" "$(cat $FileSendMark)"
            rm -rf $FileSendMark
        fi
        echo ''
        ;;
    update)
        Import_Config_Not_Check "UpdateCookies"
        local ExitStatus LogPath LogFile
        [ -f $FileSendMark ] && rm -rf $FileSendMark

        ## 更新 sign 签名
        function UpdateSign() {
            Make_Dir $SignDir
            if [ ! -d $SignDir/.git ]; then
                git clone -b master ${SignsRepoGitUrl} $SignDir >/dev/null
                ExitStatus=$?
            else
                cd $SignDir
                if [[ $(date "+%-H") -eq 9 || $(date "+%-H") -eq 21 ]] && [[ $(date "+%-S") -eq 0 ]]; then
                    local Tmp=$((${RANDOM} % 10))
                    echo -en "\n检测到当前处于整点，已启用随机延迟，此任务将在 $Tmp 秒后开始执行..."
                    sleep $Tmp
                    echo ''
                fi
                git fetch --all >/dev/null
                ExitStatus=$?
                git reset --hard origin/master >/dev/null
            fi
        }

        ## 全部更新
        function UpdateNormal() {
            local UserNum FormatPin CookieTmp LogFile
            ## 生成 pt_pin 数组
            local pt_pin_array=(
                $(jq '.[] | {pt_pin:.pt_pin,}' $FileAccountConf | grep -F "\"pt_pin\":" | grep -v "ptpin的值" | awk -F '\"' '{print$4}' | grep -v '^$')
            )

            if [[ ${#pt_pin_array[@]} -ge 1 ]]; then
                LogFile="${LogPath}/$(date "+%Y-%m-%d-%H-%M-%S").log"
                echo -e "\n$WORKING 检测到 ${BLUE}${#pt_pin_array[@]}${PLAIN} 个账号，开始更新...\n"
                ## 记录执行开始时间
                echo -e "[$(date "${TIME_FORMAT}" | cut -c1-23)] 执行开始\n" >>${LogFile}
                for ((i = 1; i <= ${#pt_pin_array[@]}; i++)); do
                    UserNum=$((i - 1))
                    ## 声明变量
                    export JD_PT_PIN=${pt_pin_array[$UserNum]}
                    ## 执行脚本
                    if [[ ${EnableGlobalProxy} == true ]]; then
                        node -r 'global-agent/bootstrap' ${FileUpdateCookie##*/} &>>${LogFile} &
                    else
                        node ${FileUpdateCookie##*/} &>>${LogFile} &
                    fi
                    wait
                    ## 判断结果并写入至推送通知
                    FormatPin=$(echo ${pt_pin_array[$UserNum]} | perl -pe '{s|[\.\/\[\]\!\@\#\$\%\^\&\*\(\)]|\\$&|g;}')
                    if [[ $(grep "Cookie => \[${FormatPin}\]" ${LogFile}) ]]; then
                        grep "Cookie => \[${FormatPin}\]" ${LogFile} | perl -pe "s|${FormatPin}|$(printf $(echo "${FormatPin}" | perl -pe "s|%|\\\x|g;"))|g;" | tee -a $FileSendMark
                    else
                        echo "Cookie => [${pt_pin_array[$UserNum]}]  更新异常" | tee -a $FileSendMark
                    fi
                done
                ## 优化日志排版
                sed -i '/更新Cookies,.*\!/d; /^$/d; s/===.*//g' ${LogFile}
                ## 记录执行结束时间
                echo -e "\n[$(date "${TIME_FORMAT}" | cut -c1-23)] 执行结束" >>${LogFile}
                echo "" >>$FileSendMark
                ## 更新后检测 Cookie 是否有效
                if [[ $(grep "Cookie =>" ${LogFile}) ]]; then
                    echo -e "\n$WORKING 更新后 Cookie 检测：\n"
                    for ((i = 1; i <= ${#pt_pin_array[@]}; i++)); do
                        sleep 1 ## 降低频率减少出现因查询太快导致API请求失败的情况
                        UserNum=$((i - 1))
                        FormatPin=$(echo ${pt_pin_array[$UserNum]} | perl -pe '{s|[\.\/\[\]\!\@\#\$\%\^\&\*\(\)]|\\$&|g;}')
                        EscapePin=$(printf $(echo ${pt_pin_array[$UserNum]} | perl -pe "s|%|\\\x|g;"))
                        CookieTmp="$(grep "^Cookie.*pt_pin=${FormatPin}" $FileConfUser | awk -F "[\"\']" '{print$2}')"
                        [ $(grep "Cookie => \[${FormatPin}\]" ${LogFile} | awk -F ' ' '{print$NF}') != "更新成功" ] && continue
                        if [[ $(grep "^Cookie.*pt_pin=${FormatPin}" $FileConfUser) ]]; then
                            if [ "$(curl -I -s --connect-timeout 5 ${INTERFACE_URL} -w %{http_code} | tail -n1)" -eq "302" ]; then
                                if [[ $(curl -s --noproxy "*" "${INTERFACE_URL}" -H "cookie: ${CookieTmp}") ]]; then
                                    echo -e "${EscapePin} 有效 ${GREEN}${TRUE_ICON}${PLAIN}"
                                    echo -e "${EscapePin} 更新后的 Cookie 有效 ${TRUE_ICON}" >>$FileSendMark
                                else
                                    echo -e "${EscapePin} 无效 ${RED}${FALSE_ICON}${PLAIN}"
                                    echo -e "${EscapePin} 更新后的 Cookie 无效 ${FALSE_ICON}" >>$FileSendMark
                                fi
                            else
                                echo -e "${EscapePin} 检测出错 ${RED}[ API 请求失败 ]${PLAIN}"
                                echo -e "${EscapePin} 更新后检测出错 [ API 请求失败 ]" >>$FileSendMark
                            fi
                        else
                            echo -e "${EscapePin} 的 Cookie 不存在 ${RED}${FALSE_ICON}${PLAIN}"
                            echo -e "${EscapePin} 更新后的 Cookie 不存在 ${FALSE_ICON}" >>$FileSendMark
                        fi
                        ## 打印 Cookie
                        # echo -e "Cookie：$(grep "^Cookie.*pt_pin=${FormatPin}" $FileConfUser | awk -F "[\"\']" '{print$2}')\n"
                    done
                    echo -e "\n$COMPLETE 更新完成\n"
                else
                    echo -e "\n$ERROR 更新异常，请检查当前网络环境并查看运行日志！\n"
                fi
            else
                echo -e "\n$ERROR 请先在 $FileAccountConf 中配置好您的 pt_pin ！\n"
            fi
        }

        ## 指定账号更新
        function UpdateDesignated() {
            local UserNum=$1
            local Pt_Pin FormatPin EscapePin CookieTmp LogFile
            local COOKIE_TMP=Cookie$UserNum
            ExistenceJudgment $UserNum
            Pt_Pin=$(echo ${!COOKIE_TMP} | grep -o "pt_pin.*;" | perl -pe '{s|pt_pin=||g; s|pt_pin=||g; s|;||g;}')
            FormatPin="$(echo ${Pt_Pin} | perl -pe '{s|[\.\/\[\]\!\@\#\$\%\^\&\*\(\)]|\\$&|g;}')"
            ## 判定该 pt_pin 对应 Cookie 是否存在
            grep ${FormatPin} -q $FileAccountConf
            if [ $? -eq 0 ]; then
                LogFile="${LogPath}/$(date "+%Y-%m-%d-%H-%M-%S")_$UserNum.log"
                echo -e "\n$WORKING 开始更新账号 ${BLUE}$UserNum${PLAIN} ...\n"
                ## 声明变量
                export JD_PT_PIN=${Pt_Pin}
                ## 记录执行开始时间
                echo -e "[$(date "${TIME_FORMAT}" | cut -c1-23)] 执行开始\n" >>${LogFile}
                ## 执行脚本
                if [[ ${EnableGlobalProxy} == true ]]; then
                    node -r 'global-agent/bootstrap' ${FileUpdateCookie##*/} &>>${LogFile} &
                else
                    node ${FileUpdateCookie##*/} &>>${LogFile} &
                fi
                wait
                ## 优化日志排版
                sed -i '/更新Cookies,.*\!/d; /^$/d; s/===.*//g' ${LogFile}
                ## 记录执行结束时间
                echo -e "\n[$(date "${TIME_FORMAT}" | cut -c1-23)] 执行结束" >>${LogFile}
                ## 判断结果并写入至推送通知
                if [[ $(grep "Cookie => \[${FormatPin}\]" ${LogFile}) ]]; then
                    grep "Cookie => \[${FormatPin}\]" ${LogFile} | perl -pe "s|${FormatPin}|$(printf $(echo "${FormatPin}" | perl -pe "s|%|\\\x|g;"))|g;" | tee -a $FileSendMark
                else
                    echo "Cookie => [${Pt_Pin}]  更新异常" | tee -a $FileSendMark
                fi
                ## 更新后检测 Cookie 是否有效
                if [[ $(grep "Cookie =>" ${LogFile}) ]]; then
                    CookieTmp="$(grep "^Cookie.*pt_pin=${FormatPin}" $FileConfUser | awk -F "[\"\']" '{print$2}')"
                    EscapePin=$(printf $(echo ${JD_PT_PIN} | perl -pe "s|%|\\\x|g;"))
                    if [ $(grep "Cookie => \[${FormatPin}\]" ${LogFile} | awk -F ' ' '{print$NF}') = "更新成功" ]; then
                        echo -e "\n$WORKING 更新后 Cookie 检测：\n"
                        if [[ $(grep "^Cookie.*pt_pin=${FormatPin}" $FileConfUser) ]]; then
                            if [ "$(curl -I -s --connect-timeout 5 ${INTERFACE_URL} -w %{http_code} | tail -n1)" -eq "302" ]; then
                                if [[ $(curl -s --noproxy "*" "${INTERFACE_URL}" -H "cookie: ${CookieTmp}") ]]; then
                                    echo -e "${EscapePin} 有效 ${GREEN}${TRUE_ICON}${PLAIN}"
                                    echo -e "${EscapePin} 更新后的 Cookie 有效 ${TRUE_ICON}" >>$FileSendMark
                                else
                                    echo -e "${EscapePin} 无效 ${RED}${FALSE_ICON}${PLAIN}"
                                    echo -e "${EscapePin} 更新后的 Cookie 无效 ${FALSE_ICON}" >>$FileSendMark
                                fi
                            else
                                echo -e "${EscapePin} 检测出错 ${RED}[ API 请求失败 ]${PLAIN}"
                                echo -e "${EscapePin} 更新后检测出错 [ API 请求失败 ]" >>$FileSendMark
                            fi
                        else
                            echo -e "${EscapePin} 的 Cookie 不存在 ${RED}${FALSE_ICON}${PLAIN}"
                            echo -e "${EscapePin} 更新后的 Cookie 不存在 ${FALSE_ICON}" >>$FileSendMark
                        fi
                    ## 打印 Cookie
                    # echo -e "Cookie：$(grep "^Cookie.*pt_pin=${FormatPin}" $FileConfUser | awk -F "[\"\']" '{print$2}')\n"
                    fi
                    echo -e "\n$COMPLETE 更新完成\n"
                else
                    echo -e "\n$ERROR 更新异常，请检查当前网络环境并查看运行日志！\n"
                fi
            else
                echo -e "\n$ERROR 请先在 $FileAccountConf 中配置好该账号的 pt_pin ！\n"
            fi
        }

        ## 汇总
        if [ -f $FileUpdateCookie ]; then
            if [[ $(jq '.[] | {ws_key:.ws_key,}' $FileAccountConf | grep -F "\"ws_key\"" | grep -v "wskey的值" | awk -F '\"' '{print$4}' | grep -v '^$') ]]; then
                UpdateSign
                if [[ $ExitStatus -eq 0 ]]; then
                    LogPath="$LogDir/UpdateCookies"
                    Make_Dir ${LogPath}
                    cd $UtilsDir
                    case $# in
                    1)
                        UpdateNormal
                        ;;
                    2)
                        UpdateDesignated $2
                        ;;
                    esac
                    ## 推送通知
                    [ -f $FileSendMark ] && sed -i "/未设置ws_key不更新/d" $FileSendMark
                    if [ -s $FileSendMark ]; then
                        [[ ${EnableCookieUpdateNotify} == true ]] && Notify "账号更新结果通知" "$(cat $FileSendMark)"
                    fi
                    [ -f $FileSendMark ] && rm -rf $FileSendMark
                else
                    echo -e "\n$ERROR 签名更新失败，请检查网络环境后重试！\n"
                fi
            else
                echo -e "\n$ERROR 请先在 $FileAccountConf 中配置好您的 ws_key ！\n"
            fi
        else
            echo -e "\n$ERROR 账号更新脚本不存在，请确认是否移动！\n"
        fi
        ;;
    esac
}

## 被你发现了嘿嘿，等有空了再写~
## 添加 own 仓库功能
function Add_Repos() {
    case $# in
    0) ;;

    1) ;;

    esac
}

## 添加 Raw 脚本功能
function Add_Raws() {
    case $# in
    0) ;;

    1) ;;

    esac
}

## 管理全局环境变量功能
function Manage_Env() {
    local Variable Value Remarks FullContent Input1 Input2 Keys

    ## 控制变量启用与禁用
    function ControlEnv() {
        local VariableTmp Mod OldContent NewContent InputA InputB
        case $# in
        1)
            VariableTmp=$1
            ;;
        2)
            Mod=$1
            VariableTmp=$2
            ;;
        *)
            Output_Command_Error 1
            exit ## 终止退出
            ;;
        esac
        OldContent=$(grep ".*export ${VariableTmp}=" $FileConfUser | head -1)
        ## 判断变量是否被注释
        grep "[# ]export ${VariableTmp}=" -q $FileConfUser
        local ExitStatus=$?
        case $# in
        1)
            if [[ $ExitStatus -eq 0 ]]; then
                while true; do
                    read -p "$(echo -e "\n${BOLD}└ 检测到该变量已禁用，是否启用 [ Y/n ]：${PLAIN}")" InputA
                    [ -z ${InputA} ] && InputA=Y
                    case ${InputA} in
                    [Yy] | [Yy][Ee][Ss])
                        sed -i "s/.*export ${VariableTmp}=/export ${VariableTmp}=/g" $FileConfUser
                        break
                        ;;
                    [Nn] | [Nn][Oo])
                        break
                        ;;
                    *)
                        echo -e "\n${YELLOW}----- 输入错误 -----${PLAIN}"
                        ;;
                    esac
                done
            else
                while true; do
                    read -p "$(echo -e "\n${BOLD}└ 检测到该变量已启用，是否禁用 [ Y/n ]：${PLAIN}")" InputB
                    [ -z ${InputB} ] && InputB=Y
                    case ${InputB} in
                    [Yy] | [Yy][Ee][Ss])
                        sed -i "s/.*export ${VariableTmp}=/# export ${VariableTmp}=/g" $FileConfUser
                        break
                        ;;
                    [Nn] | [Nn][Oo])
                        break
                        ;;
                    *)
                        echo -e "\n${YELLOW}----- 输入错误 -----${PLAIN}"
                        ;;
                    esac
                done
            fi
            ;;
        2)
            if [[ $ExitStatus -eq 0 ]]; then
                case ${Mod} in
                enable)
                    sed -i "s/.*export ${VariableTmp}=/export ${VariableTmp}=/g" $FileConfUser
                    ;;
                disable)
                    echo -e "\n$ERROR 该变量已经禁用，无需任何操作！\n"
                    exit ## 终止退出
                    ;;
                *)
                    Output_Command_Error 1
                    exit ## 终止退出
                    ;;
                esac
            else
                case ${Mod} in
                enable)
                    echo -e "\n$ERROR 该变量已经启用，无需任何操作！\n"
                    exit ## 终止退出
                    ;;
                disable)
                    sed -i "s/.*export ${VariableTmp}=/# export ${VariableTmp}=/g" $FileConfUser
                    ;;
                *)
                    Output_Command_Error 1
                    exit ## 终止退出
                    ;;
                esac
            fi
            ;;
        esac

        ## 前后对比
        NewContent=$(grep ".*export ${VariableTmp}=" $FileConfUser | head -1)
        echo -e "\n\033[41;37m${OldContent}${PLAIN} ${RED}-${PLAIN}\n\033[42m${NewContent}${PLAIN} ${GREEN}+${PLAIN}"
        ## 结果判定
        if [[ ${OldContent} = ${NewContent} ]]; then
            echo -e "\n$ERROR 修改失败\n"
        else
            echo -e "\n$COMPLETE 修改完毕\n"
        fi
    }

    ## 修改变量
    function ModifyValue() {
        local VariableTmp=$1
        local OldContent NewContent Remarks InputA InputB InputC
        OldContent=$(grep ".*export ${VariableTmp}=" $FileConfUser | head -1)
        Remarks=$(grep ".*export ${VariableTmp}=" $FileConfUser | head -n 1 | awk -F "[\"\']" '{print$NF}')
        case $# in
        1)
            read -p "$(echo -e "\n${BOLD}└ 请输入环境变量 ${BLUE}${VariableTmp}${PLAIN} ${BOLD}新的值：${PLAIN}")" InputA
            local ValueTmp=$(echo ${InputA} | perl -pe '{s|[\.\/\[\]\!\@\#\$\%\^\&\*\(\)]|\\$&|g;}')
            ## 判断变量备注内容
            if [[ ${Remarks} != "" ]]; then
                while true; do
                    read -p "$(echo -e "\n${BOLD}└ 检测到该变量存在备注内容，是否修改 [ Y/n ]：${PLAIN}")" InputB
                    [ -z ${InputB} ] && InputB=B
                    case ${InputB} in
                    [Yy] | [Yy][Ee][Ss])
                        read -p "$(echo -e "\n${BOLD}└ 请输入环境变量 ${BLUE}${Variable}${PLAIN} ${BOLD}新的备注内容：${PLAIN}")" InputC
                        Remarks=" # ${InputC}"
                        break
                        ;;
                    [Nn] | [Nn][Oo])
                        break
                        ;;
                    *)
                        echo -e "\n${YELLOW}----- 输入错误 -----${PLAIN}"
                        ;;
                    esac
                done
            fi
            ;;
        2)
            local ValueTmp=$(echo $2 | perl -pe '{s|[\.\/\[\]\!\@\#\$\%\^\&\*\(\)]|\\$&|g;}')
            ;;
        *)
            Output_Command_Error 1
            exit ## 终止退出
            ;;
        esac

        ## 修改
        sed -i "s/\(export ${VariableTmp}=\).*/\1\"${ValueTmp}\"${Remarks}/" $FileConfUser
        ## 前后对比
        NewContent=$(grep ".*export ${VariableTmp}=" $FileConfUser | head -1)
        echo -e "\n\033[41;37m${OldContent}${PLAIN} ${RED}-${PLAIN}\n\033[42m${NewContent}${PLAIN} ${GREEN}+${PLAIN}"
        ## 结果判定
        grep ".*export ${VariableTmp}=\"${ValueTmp}\"${Remarks}" -q $FileConfUser
        local ExitStatus=$?
        if [[ $ExitStatus -eq 0 ]]; then
            echo -e "\n$COMPLETE 修改完毕\n"
        else
            echo -e "\n$ERROR 修改失败\n"
        fi
    }

    case $1 in
    ## 新增变量
    add)
        case $# in
        1)
            read -p "$(echo -e "\n${BOLD}└ 请输入需要添加的环境变量名称：${PLAIN}")" Variable
            ## 检测是否已存在该变量
            grep ".*export ${Variable}=" -q $FileConfUser
            local ExitStatus=$?
            if [[ $ExitStatus -eq 0 ]]; then
                echo -e "\n${BLUE}检测到已存在该环境变量：${PLAIN}\n$(grep -n "^export ${Variable}=" $FileConfUser | perl -pe '{s|^|第|g; s|:|行：|g;}')"
                while true; do
                    read -p "$(echo -e "\n${BOLD}└ 是否继续修改 [ Y/n ]：${PLAIN}")" Input1
                    [ -z ${Input1} ] && Input1=Y
                    case ${Input1} in
                    [Yy] | [Yy][Ee][Ss])
                        ModifyValue "${Variable}"
                        break
                        ;;
                    [Nn] | [Nn][Oo])
                        echo -e "\n$COMPLETE 结束，未做任何更改\n"
                        break
                        ;;
                    *)
                        echo -e "\n${YELLOW}----- 输入错误 -----${PLAIN}"
                        ;;
                    esac
                done
            else
                read -p "$(echo -e "\n${BOLD}└ 请输入环境变量 ${BLUE}${Variable}${PLAIN} ${BOLD}的值：${PLAIN}")" Value
                ## 插入备注
                while true; do
                    read -p "$(echo -e "\n${BOLD}└ 是否添加备注 [ Y/n ]：${PLAIN}")" Input2
                    [ -z ${Input2} ] && Input2=Y
                    case ${Input2} in
                    [Yy] | [Yy][Ee][Ss])
                        read -p "$(echo -e "\n${BOLD}└ 请输入环境变量 ${BLUE}${Variable}${PLAIN} ${BOLD}的备注内容：${PLAIN}")" Remarks
                        FullContent="export ${Variable}=\"${Value}\" # ${Remarks}"
                        break
                        ;;
                    [Nn] | [Nn][Oo])
                        FullContent="export ${Variable}=\"${Value}\""
                        break
                        ;;
                    *)
                        echo -e "\n${YELLOW}----- 输入错误 -----${PLAIN}"
                        ;;
                    esac
                done
                sed -i "9 i ${FullContent}" $FileConfUser
                echo -e "\n\033[42m${FullContent}${PLAIN} ${GREEN}+${PLAIN}"
                echo -e "\n$COMPLETE 已添加\n"
            fi
            ;;
        3)
            Variable=$2
            Value=$3
            ## 检测是否已存在该变量
            grep ".*export ${Variable}=" -q $FileConfUser
            local ExitStatus=$?
            if [[ $ExitStatus -eq 0 ]]; then
                echo -e "\n${BLUE}检测到已存在该环境变量：${PLAIN}\n$(grep -n "^export ${Variable}=" $FileConfUser | perl -pe '{s|^|第|g; s|:|行：|g;}')"
                echo -e "\n$ERROR 该变量已经存在，无需任何操作！\n"
                exit ## 终止退出
            else
                FullContent="export ${Variable}=\"${Value}\""
                sed -i "9 i ${FullContent}" $FileConfUser
                echo -e "\n\033[42m${FullContent}${PLAIN} ${GREEN}+${PLAIN}"
                echo -e "\n$COMPLETE 已添加\n"
            fi
            ;;
        esac
        ;;
    ## 删除变量
    del)
        case $# in
        1)
            read -p "$(echo -e "\n${BOLD}└ 请输入需要删除的环境变量名称：${PLAIN}")" Variable
            VariableNums=$(grep -c ".*export ${Variable}=" $FileConfUser | head -n 1)
            local VariableTmp=$(grep -n ".*export ${Variable}=" $FileConfUser | perl -pe '{s|^|第|g; s|:|行: |g;}')
            if [[ ${VariableNums} -ne "0" ]]; then
                if [[ ${VariableNums} -gt "1" ]]; then
                    echo -e "\n${BLUE}检测到多个环境变量：${PLAIN}\n${VariableTmp}"
                elif [[ ${VariableNums} -eq "1" ]]; then
                    echo -e "\n${BLUE}检测到环境变量：${PLAIN}\n${VariableTmp}"
                fi
                while true; do
                    read -p "$(echo -e "\n${BOLD}└ 是否确认删除 [ Y/n ]：${PLAIN}")" Input1
                    [ -z ${Input1} ] && Input1=Y
                    case ${Input1} in
                    [Yy] | [Yy][Ee][Ss])
                        FullContent="$(grep ".*export ${Variable}=" $FileConfUser)"
                        sed -i "/export ${Variable}=/d" $FileConfUser
                        if [[ ${VariableNums} -gt "1" ]]; then
                            echo -e "\n$(echo -e "${FullContent}" | perl -pe '{s|^|\033[41;37m|g; s|$|\033[0m|g;}' | sed '$d')"
                        elif [[ ${VariableNums} -eq "1" ]]; then
                            echo -e "\n\033[41;37m${FullContent}${PLAIN} ${RED}-${PLAIN}"
                        fi
                        echo -e "\n$COMPLETE 已删除\n"
                        break
                        ;;
                    [Nn] | [Nn][Oo])
                        echo -e "\n$COMPLETE 结束，未做任何更改\n"
                        break
                        ;;
                    *)
                        echo -e "\n${YELLOW}----- 输入错误 -----${PLAIN}"
                        ;;
                    esac
                done
            else
                echo -e "\n$ERROR 在配置文件中未检测到 ${BLUE}${Variable}${PLAIN} 环境变量，请确认是否存在！\n"
            fi
            ;;
        2)
            Variable=$2
            ## 检测是否已存在该变量
            VariableNums=$(grep -c ".*export ${Variable}=" $FileConfUser | head -n 1)
            if [[ ${VariableNums} -ne "0" ]]; then
                FullContent="$(grep ".*export ${Variable}=" $FileConfUser)"
                sed -i "/export ${Variable}=/d" $FileConfUser
                if [[ ${VariableNums} -gt "1" ]]; then
                    echo -e "\n$(echo -e "${FullContent}" | perl -pe '{s|^|\033[41;37m|g; s|$|\033[0m|g;}' | sed '$d')"
                elif [[ ${VariableNums} -eq "1" ]]; then
                    echo -e "\n\033[41;37m${FullContent}${PLAIN} ${RED}-${PLAIN}"
                fi
                echo -e "\n$COMPLETE 已删除\n"
            else
                echo -e "\n$ERROR 在配置文件中未检测到 ${BLUE}${Variable}${PLAIN} 环境变量，请确认是否存在！\n"
            fi

            ;;
        esac
        ;;
    ## 修改变量
    edit)
        case $# in
        1)
            read -p "$(echo -e "\n${BOLD}└ 请输入需要修改的环境变量名称：${PLAIN}")" Variable
            ## 检测是否存在该变量
            grep ".*export.*=" $FileConfUser | grep ".*export ${Variable}=" -q
            local ExitStatus=$?
            if [[ $ExitStatus -eq 0 ]]; then
                echo -e "\n${BLUE}当前环境变量：${PLAIN}\n$(grep -n ".*export ${Variable}=" $FileConfUser | perl -pe '{s|^|第|g; s|:|行：|g;}')\n"
                echo -e '1)   启用或禁用'
                echo -e '2)   修改变量的值'
                while true; do
                    read -p "$(echo -e "\n${BOLD}└ 请选择操作模式 [ 1-2 ]：${PLAIN}")" Input1
                    case ${Input1} in
                    1)
                        ControlEnv "${Variable}"
                        break
                        ;;
                    2)
                        ModifyValue "${Variable}"
                        break
                        ;;
                    esac
                    echo -e "\n$ERROR 输入错误！"
                done
            else
                echo -e "\n$ERROR 在配置文件中未检测到 ${BLUE}${Variable}${PLAIN} 环境变量，请确认是否存在！\n"
            fi
            ;;
        3)
            case $2 in
            enable | disable)
                Variable=$3
                ;;
            *)
                Variable=$2
                ;;
            esac
            grep ".*export.*=" $FileConfUser | grep ".*export ${Variable}=" -q
            local ExitStatus=$?
            if [[ $ExitStatus -eq 0 ]]; then
                case $2 in
                enable | disable)
                    ControlEnv "$2" "$3"
                    ;;
                *)
                    ModifyValue "$2" "$3"
                    ;;
                esac
            else
                echo -e "\n$ERROR 在配置文件中未检测到 ${BLUE}${Variable}${PLAIN} 环境变量，请确认是否存在！\n"
            fi
            ;;
        esac
        ;;
    ## 查询变量
    search)
        case $# in
        1)
            read -p "$(echo -e "\n${BOLD}└ 请输入需要查询的关键词：${PLAIN}")" Keys
            ;;
        2)
            Keys=$2
            ;;
        esac
        ## 检测搜索结果是否为空
        grep ".*export.*=" $FileConfUser | grep "${Keys}" -q
        local ExitStatus=$?
        if [[ $ExitStatus -eq 0 ]]; then
            echo -e "\n${BLUE}检测到的环境变量：${PLAIN}"
            grep -n ".*export.*=" $FileConfUser | grep "${Keys}" | perl -pe "{s|^|第|g; s|:|行：|g; s|${Keys}|${RED}${Keys}${PLAIN}|g;}"
            echo -e "\n$COMPLETE 查询完毕\n"
        else
            echo -e "\n$ERROR 未查询到包含 ${Keys} 的相关环境变量！\n"
        fi
        ;;
    esac
}

## 推送通知功能
function SendNotify() {
    Import_Config_Not_Check
    Notify $1 $2
}

## 切换分支功能
function SwitchBranch() {
    local CurrentBranch=$(git status | head -n 1 | awk -F ' ' '{print$NF}')
    if [[ ${CurrentBranch} == "master" ]]; then
        echo ''
        git reset --hard
        git checkout dev
        echo -e "\n$COMPLETE 已为您切换至开发分支，感谢参与测试\n"
    elif [[ ${CurrentBranch} == "dev" ]]; then
        echo ''
        git reset --hard
        git checkout master
        echo -e "\n$COMPLETE 已切换回用户分支\n"
    fi
}

## 删除日志功能
function Remove_LogFiles() {
    local LogFileList LogDate DiffTime Stmp DateDelLog LineEndGitPull LineEndBotRun RmDays
    case $# in
    0)
        Import_Config_Not_Check
        RmDays=${RmLogDaysAgo}
        ;;
    1)
        RmDays=$1
        ;;
    esac
    function Rm_JsLog() {
        LogFileList=$(ls -l $LogDir/*/*.log | awk '{print $9}' | grep -v "log/bot")
        for log in ${LogFileList}; do
            ## 文件名比文件属性获得的日期要可靠
            LogDate=$(echo ${log} | awk -F '/' '{print $NF}' | grep -Eo "20[2-9][0-9]-[0-1][0-9]-[0-3][0-9]")
            [[ -z ${LogDate} ]] && continue
            DiffTime=$(($(date +%s) - $(date +%s -d "${LogDate}")))
            [ ${DiffTime} -gt $((${RmDays} * 86400)) ] && rm -vf ${log}
        done
    }
    ## 删除 update 的运行日志
    function Rm_UpdateLog() {
        if [ -f $LogDir/update.log ]; then
            Stmp=$(($(date "+%s") - 86400 * ${RmDays}))
            DateDelLog=$(date -d "@${Stmp}" "+%Y-%m-%d")
            LineEndGitPull=$(($(cat $LogDir/update.log | grep -n "${DateDelLog}" | head -1 | awk -F ":" '{print $1}') - 3))
            [ ${LineEndGitPull} -gt 0 ] && perl -i -ne "{print unless 1 .. ${LineEndGitPull} }" $LogDir/update.log
        fi
    }
    ## 删除 Bot 的运行日志
    function Rm_BotLog() {
        if [ -f $BotLogDir/run.log ]; then
            Stmp=$(($(date "+%s") - 86400 * ${RmDays}))
            DateDelLog=$(date -d "@${Stmp}" "+%Y-%m-%d")
            LineEndBotRun=$(($(cat $BotLogDir/run.log | grep -n "${DateDelLog}" | tail -n 1 | awk -F ":" '{print $1}') - 3))
            [ ${LineEndBotRun} -gt 0 ] && perl -i -ne "{print unless 1 .. ${LineEndBotRun} }" $BotLogDir/run.log
        fi
    }
    ## 删除空文件夹
    function Rm_EmptyDir() {
        cd $LogDir
        for dir in $(ls); do
            if [ -d ${dir} ] && [[ $(ls ${dir}) == "" ]]; then
                rm -rf ${dir}
            fi
        done
    }
    ## 汇总
    if [ -n "${RmDays}" ]; then
        echo -e "\n$WORKING 开始检索并删除超过 ${BLUE}${RmDays}${PLAIN} 天的日志文件...\n"
        Rm_JsLog
        Rm_UpdateLog
        Rm_BotLog
        Rm_EmptyDir
        echo -e "\n$COMPLETE 运行结束\n"
    fi
}

## 进程监控功能
function Process_Monitor() {
    local MemoryTotal MemoryUsed MemoryFree MemoryAvailable MemoryUsage CPUUsage MemoryUsedNew MemoryAvailableNew MemoryUsageNew LogFilesSpace
    MemoryTotal=$(free -m | grep Mem | awk -F ' ' '{print$2}')
    MemoryUsed=$(free -m | grep Mem | awk -F ' ' '{print$3}')
    MemoryFree=$(free -m | grep Mem | awk -F ' ' '{print$4}')
    MemoryAvailable=$(free -m | grep Mem | awk -F ' ' '{print$7}')
    MemoryUsage=$(awk 'BEGIN{printf "%.1f%%\n",('$MemoryUsed'/'$MemoryTotal')*100}')
    CPUUsage=$(busybox top -n 1 | grep CPU | head -1 | awk -F ' ' '{print$2}')
    ConfigSpaceUsage=$(du -sm $ConfigDir | awk -F ' ' '{print$1}')
    LogFilesSpaceUsage=$(du -sm $LogDir | awk -F ' ' '{print$1}')
    ScriptsRepoSpaceUsage=$(du -sm $ScriptsDir | awk -F ' ' '{print$1}')
    OwnReposSpaceUsage=$(du -sm $OwnDir | awk -F ' ' '{print$1}')
    ReposSpaceUsage=$((${ScriptsRepoSpaceUsage} + ${OwnReposSpaceUsage}))
    echo -e "\n❖  处理器使用率：${YELLOW}${CPUUsage}${PLAIN}   内存使用率：${YELLOW}${MemoryUsage}${PLAIN}   可用内存：${YELLOW}${MemoryAvailable}MB${PLAIN}   空闲内存：${YELLOW}${MemoryFree}MB${PLAIN}   \n\n❖  配置文件占用空间：${YELLOW}${ConfigSpaceUsage}MB${PLAIN}    日志占用空间：${YELLOW}${LogFilesSpaceUsage}MB${PLAIN}    脚本占用空间：${YELLOW}${ReposSpaceUsage}MB${PLAIN}"
    ## 检测占用过高后释放内存
    if [[ $(echo ${MemoryUsage} | awk -F '.' '{print$1}') -gt "89" ]]; then
        sync >/dev/null 2>&1
        echo 3 >/proc/sys/vm/drop_caches >/dev/null 2>&1
        MemoryUsedNew=$(free -m | grep Mem | awk -F ' ' '{print$3}')
        MemoryAvailableNew=$(free -m | grep Mem | awk -F ' ' '{print$4}')
        MemoryUsageNew=$(awk 'BEGIN{printf "%.1f%%\n",('$MemoryUsedNew'/'$MemoryTotal')*100}')
        echo -e "\n$WORKING 检测到内存占用过高，开始尝试释放内存..."
        echo -e "${BLUE}[释放后]${PLAIN}  内存占用：${YELLOW}${MemoryUsageNew}${PLAIN}   可用内存：${YELLOW}${MemoryAvailableNew}MB${PLAIN}"
    fi
    ## 列出进程
    echo -e "\n${BLUE}[运行时长]  [CPU]    [内存]    [脚本名称]${PLAIN}"
    ps -axo user,time,pcpu,user,pmem,user,command --sort -pmem | less | egrep "\.js\b|\.py\b|\.ts\b" | egrep -v "\/jd\/web\/server\.js|pm2 |egrep |perl |sed |bash |wget |\<defunct\>" |
        perl -pe '{s| root     |% |g; s|\/usr\/bin\/ts-node-transpile-only ||g; s|\/usr\/bin\/ts-node ||g; s|\/usr\/bin\/python3 ||g; s|python3 -u ||g; s|\/usr\/bin\/python ||g; s|\/usr\/bin\/node ||g; s|node -r global-agent/bootstrap |(代理)|g; s|node ||g;  s|root     |#|g; s|#[0-9][0-9]:|#|g;  s|  | |g; s| |     |g; s|#|•  |g; s|/jd/scripts/jd_cfd_loop\.js|jd_cfd_loop\.js|g; s|\./utils/||g;}'
    echo ''
}

## 列出本地脚本清单功能
function List_Local_Scripts() {
    local ScriptType Tmp1 Tmp2
    case ${ARCH} in
    armv7l | armv6l)
        ScriptType="\.js\b"
        ;;
    *)
        if [ -x /usr/bin/python3 ]; then
            Tmp1="|\.py\b"
        else
            Tmp1=""
        fi
        if [ -x /usr/bin/ts-node ]; then
            Tmp2="|\.ts\b"
        else
            Tmp2=""
        fi
        ScriptType="\.js\b${Tmp1}${Tmp2}"
        ;;
    esac

    ## 列出 Scripts 仓库中的脚本
    function List_Scripts() {
        local Name
        cd $ScriptsDir
        local ListFiles=($(
            git ls-files | grep -E "${ScriptType}" | grep -E "j[drx]_" | grep -Ev "/|${ShieldingKeywords}"
        ))
        echo -e "\n❖ Scripts 仓库的脚本："
        for ((i = 0; i < ${#ListFiles[*]}; i++)); do
            Query_Name ${ListFiles[i]}
            echo -e "[$(($i + 1))] ${ScriptName} - ${ListFiles[i]}"
        done
    }

    ## 列出本地其它仓库中的脚本
    function List_Own() {
        local Name FileName WhichDir Tmp1 Tmp2 Tmp3 repo_num
        Import_Config_Not_Check

        if [[ ${OwnRepoUrl1} ]]; then
            for ((i = 1; i <= 0x64; i++)); do
                Tmp1=OwnRepoUrl$i
                Tmp2=${!Tmp1}
                [[ $Tmp2 ]] && OwnRepoSum=$i || break
            done

            if [[ $OwnRepoSum -ge 1 ]]; then
                for ((i = 1; i <= $OwnRepoSum; i++)); do
                    repo_num=$((i - 1))
                    Tmp1=OwnRepoUrl$i
                    array_own_repo_url[$repo_num]=${!Tmp1}
                    array_own_repo_dir[$repo_num]=$(echo ${array_own_repo_url[$repo_num]} | perl -pe "s|\.git||" | awk -F "/|:" '{print $((NF - 1)) "_" $NF}')
                    Tmp3=OwnRepoPath$i
                    if [[ -z ${!Tmp3} ]]; then
                        array_own_repo_path[$repo_num]="$OwnDir/${array_own_repo_dir[$repo_num]}"
                    else
                        array_own_repo_path[$repo_num]="$OwnDir/${array_own_repo_dir[$repo_num]}/${!Tmp3}"
                    fi
                done
            fi

            local ListFiles=($(
                for ((i = 1; i <= $OwnRepoSum; i++)); do
                    repo_num=$((i - 1))
                    ls ${array_own_repo_path[repo_num]} | grep -E "${ScriptType}" | grep -Ev "/|${ShieldingKeywords}" | perl -pe "{s|^|${array_own_repo_path[repo_num]}/|g;}"
                done
                if [[ ${#OwnRawFile[*]} -ge 1 ]]; then
                    ls $RawDir | grep -E "${ScriptType}" | grep -Ev "/|${ShieldingKeywords}" | perl -pe "{s|^|$RawDir/|g;}"
                fi
            ))

            echo -e "\n❖ Own 仓库的脚本："
            for ((i = 0; i < ${#ListFiles[*]}; i++)); do
                FileName=${ListFiles[i]##*/}
                WhichDir=$(echo ${ListFiles[i]} | awk -F "$FileName" '{print$1}')
                cd $WhichDir
                Query_Name $FileName
                echo -e "[$(($i + 1))] ${ScriptName} - ${ListFiles[i]}"
            done
        fi
    }

    ## 列出 scripts 目录下的第三方脚本
    function List_Other() {
        local Name
        cd $ScriptsDir
        local ListFiles=($(
            ls | grep -E "${ScriptType}" | grep -Ev "$(git ls-files)|${ShieldingKeywords}"
        ))
        if [ ${#ListFiles[*]} != 0 ]; then
            echo -e "\n❖ 第三方脚本："
            for ((i = 0; i < ${#ListFiles[*]}; i++)); do
                Query_Name ${ListFiles[i]}
                echo -e "[$(($i + 1))] ${ScriptName} - ${ListFiles[i]}"
            done
        fi
    }

    echo -e "#################################### 本  地  脚  本  清  单 ####################################"
    echo -e "自行导入的脚本不会随更新而自动删除，Python 和 TypeScript 类型的脚本只有在安装了相关环境后才会列出"
    case ${ARCH} in
    armv7l | armv6l) ;;
    *)
        echo -e "TypeScript 脚本如遇报错可使用 tsc 命令转换成 js 脚本后执行，转换命令格式：tsc <含有路径的脚本名>"
        ;;
    esac

    List_Scripts
    List_Own
    List_Other
    echo ''
}

## 判断传入命令
case $# in
0)
    Help
    ;;
1)
    case $1 in
    ps)
        Process_Monitor
        ;;
    list)
        List_Local_Scripts
        ;;
    exsc)
        bash $FileCode
        ;;
    rmlog)
        Remove_LogFiles
        ;;
    cleanup)
        Process_CleanUp
        ;;
    debug)
        SwitchBranch
        ;;
    *)
        RUN_DELAY="true"
        RUN_MODE=normal
        Run_Normal $1
        ;;
    esac
    ;;

## 2个参数
2)
    case $2 in
    now)
        RUN_MODE=normal
        Run_Normal $1
        ;;
    conc)
        RUN_MODE=concurrent
        Run_Concurrent $1
        ;;
    [1-9] | [1-9][0-9] | [1-9][0-9][0-9])
        case $1 in
        rmlog)
            Remove_LogFiles $2
            ;;
        cleanup)
            Process_CleanUp $2
            ;;
        *)
            Output_Command_Error 1
            ;;
        esac
        ;;
    pkill)
        Process_Kill $1
        ;;
    update | check)
        case $1 in
        cookie)
            Cookies_Control $2
            ;;
        *)
            Output_Command_Error 1
            ;;
        esac
        ;;
    add | del | edit | search)
        case $1 in
        env)
            Manage_Env $2
            ;;
        *)
            Output_Command_Error 1
            ;;
        esac
        ;;
    *)
        case $1 in
        list | ps | exsc)
            Output_Command_Error 2
            ;;
        *)
            Output_Command_Error 1
            ;;
        esac
        ;;
    esac
    ;;

## 3个参数
3)
    RUN_TARGET=$1
    case $2 in
    now)
        while [ $# -gt 2 ]; do
            case $3 in
            -b | --background)
                RUN_BACKGROUND="true"
                ;;
            -p | --proxy)
                echo ${RUN_TARGET} | grep -Eq "http.*:"
                if [ $? -eq 0 ]; then
                    DOWNLOAD_PROXY="true"
                else
                    Help
                    echo -e "$ERROR 检测到无效参数 ${BLUE}$3${PLAIN} ，该参数仅适用于执行位于远程仓库的脚本，请确认后重新输入！\n"
                    exit ## 终止退出
                fi
                ;;
            -r | --rapid)
                RUN_RAPID="true"
                ;;
            -d | --delay)
                RUN_DELAY="true"
                ;;
            -c | --cookie)
                Help
                echo -e "$ERROR 检测到无效参数 ${BLUE}$3${PLAIN} ，请在该参数后指定运行账号！\n"
                exit ## 终止退出
                ;;
            *)
                Help
                echo -e "$ERROR 检测到无效参数 ${BLUE}$3${PLAIN} ，请确认后重新输入！\n"
                exit ## 终止退出
                ;;
            esac
            shift
        done
        RUN_MODE=normal
        Run_Normal ${RUN_TARGET}
        ;;
    conc)
        while [ $# -gt 2 ]; do
            case $3 in
            -b | --background)
                Help
                echo -e "$ERROR 检测到无效参数 ${BLUE}$3${PLAIN} ，该参数仅适用于普通执行！\n"
                exit ## 终止退出
                ;;
            -p | --proxy)
                echo ${RUN_TARGET} | grep -Eq "http.*:"
                if [ $? -eq 0 ]; then
                    DOWNLOAD_PROXY="true"
                else
                    Help
                    echo -e "$ERROR 检测到无效参数 ${BLUE}$3${PLAIN} ，该参数仅适用于执行位于远程仓库的脚本，请确认后重新输入！\n"
                    exit ## 终止退出
                fi
                ;;
            -r | --rapid)
                RUN_RAPID="true"
                ;;
            -d | --delay)
                RUN_DELAY="true"
                ;;
            -c | --cookie)
                Help
                echo -e "$ERROR 检测到无效参数 ${BLUE}$3${PLAIN} ，请在该参数后指定运行账号！\n"
                exit ## 终止退出
                ;;
            *)
                Help
                echo -e "$ERROR 检测到无效参数 ${BLUE}$3${PLAIN} ，请确认后重新输入！\n"
                exit ## 终止退出
                ;;
            esac
            shift
        done
        RUN_MODE=concurrent
        Run_Concurrent ${RUN_TARGET}
        ;;
    update)
        case $1 in
        cookie)
            case $3 in
            [1-9] | [1-9][0-9] | [1-9][0-9][0-9])
                Cookies_Control $2 $3
                ;;
            *)
                Output_Command_Error 1
                ;;
            esac
            ;;
        *)
            Output_Command_Error 1
            ;;
        esac
        ;;
    del | search)
        case $1 in
        env)
            Manage_Env $2 $3
            ;;
        *)
            Output_Command_Error 1
            ;;
        esac
        ;;
    enable | disable)
        case $1 in
        env)
            Manage_Env edit $2 $3
            ;;
        *)
            Output_Command_Error 1
            ;;
        esac
        ;;
    *)
        case $1 in
        notify)
            SendNotify $2 $3
            ;;
        *)
            Output_Command_Error 1
            ;;
        esac
        ;;
    esac
    ;;

## 很多个参数
4 | 5 | 6 | 7)
    RUN_TARGET=$1
    case $2 in
    now)
        while [ $# -gt 2 ]; do
            case $3 in
            -b | --background)
                RUN_BACKGROUND="true"
                ;;
            -p | --proxy)
                echo ${RUN_TARGET} | grep -Eq "http.*:"
                if [ $? -eq 0 ]; then
                    DOWNLOAD_PROXY="true"
                else
                    Help
                    echo -e "$ERROR 检测到无效参数 ${BLUE}$3${PLAIN} ，该参数仅适用于执行位于远程仓库的脚本，请确认后重新输入！\n"
                    exit ## 终止退出
                fi
                ;;
            -r | --rapid)
                RUN_RAPID="true"
                ;;
            -d | --delay)
                RUN_DELAY="true"
                ;;
            -c | --cookie)
                echo "$4" | grep -Eq "[a-zA-Z./\!@#$%^&*|]|\(|\)|\[|\]|\{|\}"
                if [ $? -eq 0 ]; then
                    Help
                    echo -e "$ERROR 检测到无效参数值 ${BLUE}$4${PLAIN} ，语法有误请确认后重新输入！\n"
                    exit ## 终止退出
                else
                    RUN_DESIGNATED="true"
                    DESIGNATED_NUMS="$4"
                    shift
                fi
                ;;
            *)
                Help
                echo -e "$ERROR 检测到无效参数 ${BLUE}$3${PLAIN} ，请确认后重新输入！\n"
                exit ## 终止退出
                ;;
            esac
            shift
        done
        RUN_MODE=normal
        Run_Normal ${RUN_TARGET}
        ;;
    conc)
        while [ $# -gt 2 ]; do
            case $3 in
            -b | --background)
                Help
                echo -e "$ERROR 检测到无效参数 ${BLUE}$3${PLAIN} ，该参数仅适用于普通执行！\n"
                exit ## 终止退出
                ;;
            -p | --proxy)
                echo ${RUN_TARGET} | grep -Eq "http.*:"
                if [ $? -eq 0 ]; then
                    DOWNLOAD_PROXY="true"
                else
                    Help
                    echo -e "$ERROR 检测到无效参数 ${BLUE}$3${PLAIN} ，该参数仅适用于执行位于远程仓库的脚本，请确认后重新输入！\n"
                    exit ## 终止退出
                fi
                ;;
            -r | --rapid)
                RUN_RAPID="true"
                ;;
            -d | --delay)
                RUN_DELAY="true"
                ;;
            -c | --cookie)
                echo "$4" | grep -Eq "[a-zA-Z./\!@#$%^&*|]|\(|\)|\[|\]|\{|\}"
                if [ $? -eq 0 ]; then
                    Help
                    echo -e "$ERROR 检测到无效参数值 ${BLUE}$4${PLAIN} ，语法有误请确认后重新输入！\n"
                    exit ## 终止退出
                else
                    RUN_DESIGNATED="true"
                    DESIGNATED_NUMS="$4"
                    shift
                fi
                ;;
            *)
                Help
                echo -e "$ERROR 检测到无效参数 ${BLUE}$3${PLAIN} ，请确认后重新输入！\n"
                exit ## 终止退出
                ;;
            esac
            shift
        done
        RUN_MODE=concurrent
        Run_Concurrent ${RUN_TARGET}
        ;;
    add | edit)
        if [ $# -eq 4 ]; then
            case $1 in
            env)
                Manage_Env $2 $3 "$4"
                ;;
            *)
                Output_Command_Error 1
                ;;
            esac
        else
            Output_Command_Error 2
        fi
        ;;
    *)
        Output_Command_Error 1
        ;;
    esac
    ;;
*)
    Output_Command_Error 2
    ;;
esac
