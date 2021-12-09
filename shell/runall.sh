#!/bin/bash
## Author: SuperManito
## Modified: 2021-11-26

ShellDir=${WORK_DIR}/shell
. $ShellDir/share.sh

## 选择执行模式
function ChooseRunMod() {
    local Input1 Input2 Input3 UserNum TmpParam1 TmpParam2

    ## 判定账号是否存在
    function ExistenceJudgment() {
        local Num=$1
        local Tmp=Cookie$Num
        if [[ -z ${!Tmp} ]]; then
            echo -e "\n$ERROR 账号 ${BLUE}$Num${PLAIN} 不存在，请重新确认！"
            Help && exit ## 终止退出
        fi
    }

    while true; do
        read -p "$(echo -e "\n${BOLD}└ 是否指定账号 [ Y/n ]：${PLAIN}")" Input1
        [ -z ${Input1} ] && Input1=Y
        case $Input1 in
        [Yy] | [Yy][Ee][Ss])
            ## 导入配置文件
            Import_Config ${FileName}
            while true; do
                read -p "$(echo -e "\n${BOLD}  └ 请输入账号对应的序号（多个号用逗号隔开，支持区间）：${PLAIN}")" Input2
                echo "${Input2}" | grep -Eq "[a-zA-Z./\!@#$%^&*|]|\(|\)|\[|\]|\{|\}"
                if [ $? -eq 0 ]; then
                    echo -e "\n$COMMAND_ERROR 无效参数 ，请确认后重新输入！"
                else
                    local Accounts=$(echo ${Input2} | perl -pe '{s|,| |g}')
                    for UserNum in ${Accounts}; do
                        echo ${UserNum} | grep "-" -q
                        if [ $? -eq 0 ]; then
                            if [[ ${UserNum%-*} -lt ${UserNum##*-} ]]; then
                                for ((i = ${UserNum%-*}; i <= ${UserNum##*-}; i++)); do
                                    ExistenceJudgment $i
                                done
                            else
                                echo -e "\n$ERROR 检测到无效参数，${BLUE}${UserNum}${PLAIN} 不是有效的账号区间，请重新确认！"
                                Help && exit ## 终止退出
                            fi
                        else
                            ExistenceJudgment $UserNum
                        fi
                    done
                    break
                fi
            done
            TmpParam1=" --cookie ${Input2}"
            break
            ;;
        [Nn] | [Nn][Oo])
            TmpParam1=""
            break
            ;;
        esac
        echo -e "\n$ERROR 输入错误，请重新执行！\n"
    done
    while true; do
        read -p "$(echo -e "\n${BOLD}└ 是否组合互助码 [ Y/n ]：${PLAIN}")" Input3
        [ -z ${Input3} ] && Input3=Y
        case $Input3 in
        [Yy] | [Yy][Ee][Ss])
            TmpParam2=""
            break
            ;;
        [Nn] | [Nn][Oo])
            TmpParam2=" --rapid"
            break
            ;;
        esac
        echo -e "\n$ERROR 输入错误，请重新执行！\n"
    done
    RunMode="now${TmpParam1}${TmpParam2}"
}

function Main() {
    local CurrentDir=$(pwd)
    local Input3 Input4 Input5 ScriptType Tmp1 Tmp2
    local RunFile=$RootDir/.runall_tmp.sh
    [ -f $RunFile ] && rm -rf $RunFile
    case ${ARCH} in
    armv7l | armv6l)
        ScriptType=".js\b"
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

    echo -e ''
    echo -e '1)   Scripts 仓库的脚本'
    echo -e '2)   Scripts 目录下的所有脚本'
    echo -e '3)   指定路径下的所有脚本（非递归）'
    while true; do
        read -p "$(echo -e "\n${BOLD}└ 请选择需要执行的脚本范围 [ 1-3 ]：${PLAIN}")" Input3
        case $Input3 in
        1)
            [ -d "$ScriptsDir/.git" ] && cd $ScriptsDir && git ls-files | egrep "${ScriptType}" | grep -E "j[drx]_" | grep -Ev "/|${ShieldingKeywords}" >$RunFile
            local WorkDir=$ScriptsDir
            cd $CurrentDir
            break
            ;;
        2)
            ls $ScriptsDir | egrep "${ScriptType}" | grep -Ev "/|${ShieldingKeywords}" | sort -u >$RunFile
            local WorkDir=$ScriptsDir
            break
            ;;
        3)
            Import_Config_Not_Check
            echo -e "\n❖ 检测到的仓库："
            echo -e "$ScriptsDir"
            if [[ ${OwnRepoUrl1} ]]; then
                ls $OwnDir | egrep -v "node_modules|package|raw" | perl -pe "{s|^|$OwnDir/|g}"
            fi
            echo -e "\nTips：可以指定任何一个目录并非仅限于上方检测到的仓库。"
            while true; do
                read -p "$(echo -e "\n${BOLD}└ 请输入绝对路径：${PLAIN}")" Input4
                local AbsolutePath=$(echo "$Input4" | perl -pe "{s|/jd/||; s|^*|$RootDir/|;}")
                if [[ $Input4 ]] && [ -d $AbsolutePath ]; then
                    break
                else
                    echo -e "\n$ERROR 目录不存在或输入有误！"
                fi
            done
            ls $AbsolutePath | egrep "${ScriptType}" | grep -Ev "/|${ShieldingKeywords}" | perl -pe "{s|^|$AbsolutePath/|g; s|//|/|;}" | sort -u >$RunFile
            local WorkDir=$AbsolutePath
            break
            ;;
        esac
        echo -e "\n$ERROR 输入错误！"
    done
    if [ -s $RunFile ]; then
        ## 去除不适合在此执行的活动脚本
        local ExcludeScripts="bean_change joy_reward blueCoin jd_delCoupon jd_family jd_crazy_joy jd_try jd_cfdtx"
        for del in ${ExcludeScripts}; do
            sed -i "/$del/d" $RunFile
        done
        ## 输出脚本清单
        cd $WorkDir
        local ListFiles=($(
            cat $RunFile | perl -pe '{s|^.*/||g;}'
        ))
        echo -e "\n❖ 当前选择的脚本："
        for ((i = 0; i < ${#ListFiles[*]}; i++)); do
            Query_Name ${ListFiles[i]}
            echo -e "$(($i + 1)).${Name}：${ListFiles[i]}"
        done
        cd $CurrentDir
        read -p "$(echo -e "\n${BOLD}└ 请确认是否继续 [ Y/n ]：${PLAIN}")" Input5
        [ -z ${Input5} ] && Input5=Y
        case $Input5 in
        [Yy] | [Yy][Ee][Ss])
            ChooseRunMod
            ## 补全命令
            sed -i "s/^/$TaskCmd &/g" $RunFile
            sed -i "s/$/& ${RunMode}/g" $RunFile
            sed -i '1i\#!/bin/env bash' $RunFile
            ## 执行前提示
            echo -e "\n\033[32mTips${PLAIN}: ${BLUE}Ctrl + Z${PLAIN} 跳过执行当前脚本（若中途卡住可尝试跳过），${BLUE}Ctrl + C${PLAIN} 终止执行全部任务\n"
            ## 等待动画
            local spin=('.   ' '..  ' '... ' '....')
            local n=0
            while (true); do
                ((n++))
                echo -en "\033[?25l$WORKING 倒计时 3 秒后开始${spin[$((n % 4))]}${PLAIN}" "\r"
                sleep 0.3
                [ $n = 10 ] && echo -e "\033[?25h\n${PLAIN}" && break
            done
            ## 开始执行
            echo -e "[$(date "+%Y-%m-%d %H:%M:%S")] 全部执行开始\n"
            . $RunFile
            echo -e "\n[$(date "+%Y-%m-%d %H:%M:%S")] 全部执行结束\n"
            ;;
        [Nn] | [Nn][Oo])
            echo -e "\n$ERROR 中途退出！\n"
            ;;
        *)
            echo -e "\n$ERROR 输入错误，请重新执行！\n"
            ;;
        esac
    else
        echo -e "\n$ERROR 该路径下未检测到任何脚本，请检查原因后重试！\n"
    fi
    rm -rf $RunFile
}

Main
