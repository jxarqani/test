#!/bin/bash
## Author: SuperManito
## Modified: 2022-05-27

ShellDir=${WORK_DIR}/shell
. $ShellDir/share.sh

## 选择执行模式
function ChooseRunMod() {
    local Input1 Input2 Input3 Input4 UserNum TmpParam1 TmpParam2 TmpParam3

    ## 判定账号是否存在
    function ExistenceJudgment() {
        local Num=$1
        local Tmp=Cookie$Num
        if [[ -z ${!Tmp} ]]; then
            echo -e "\n$ERROR 账号 ${BLUE}$Num${PLAIN} 不存在，请重新确认！\n"
            exit ## 终止退出
        fi
    }
    ## 指定账号参数
    while true; do
        read -p "$(echo -e "\n${BOLD}└ 是否指定账号? [Y/n] ${PLAIN}")" Input1
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
                                Help
                                echo -e "$ERROR 检测到无效参数值 ${BLUE}${UserNum}${PLAIN} ，账号区间语法有误，请重新输入！\n"
                                exit ## 终止退出
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
    ## 迅速模式（组合互助码）参数
    while true; do
        read -p "$(echo -e "\n${BOLD}└ 是否组合互助码? [Y/n] ${PLAIN}")" Input3
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
    ## 静默推送通知参数
    while true; do
        read -p "$(echo -e "\n${BOLD}└ 是否推送通知消息? [Y/n] ${PLAIN}")" Input4
        [ -z ${Input4} ] && Input4=Y
        case $Input4 in
        [Yy] | [Yy][Ee][Ss])
            TmpParam3=""
            break
            ;;
        [Nn] | [Nn][Oo])
            TmpParam3=" --mute"
            break
            ;;
        esac
        echo -e "\n$ERROR 输入错误，请重新执行！\n"
    done
    ## 组合命令
    RunMode="now${TmpParam1}${TmpParam2}${TmpParam3}"
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

    echo -e "\n❖ ${BOLD}RunAll${PLAIN}\n"
    echo -e '1)   Scripts 主要仓库的脚本'
    echo -e '2)   Scripts 目录下的所有脚本'
    echo -e '3)   Scripts 目录下的第三方脚本'
    echo -e '4)   指定路径下的所有脚本（非递归）'
    while true; do
        read -p "$(echo -e "\n${BOLD}└ 请选择执行脚本范围 [ 1-4 ]：${PLAIN}")" Input3
        case $Input3 in
        1)
            local WorkDir=$ScriptsDir
            [ -d "$ScriptsDir/.git" ] && cd $ScriptsDir && git ls-files | egrep "${ScriptType}" | grep -E "j[drx]_" | grep -Ev "/|${ShieldingKeywords}" >$RunFile
            cd $CurrentDir
            break
            ;;
        2)
            local WorkDir=$ScriptsDir
            ls $ScriptsDir | egrep "${ScriptType}" | grep -Ev "/|${ShieldingKeywords}" | sort -u >$RunFile
            break
            ;;
        3)
            local WorkDir=$ScriptsDir
            cd $ScriptsDir
            ls | egrep "${ScriptType}" | grep -Ev "$(git ls-files)|/|${ShieldingKeywords}" | sort -u >$RunFile
            cd $CurrentDir
            break
            ;;
        4)
            Import_Config_Not_Check
            echo -e "\n❖ 检测到的仓库："
            if [[ ${OwnRepoUrl1} ]]; then
                ls $OwnDir | egrep -v "node_modules|package|raw" | perl -pe "{s|^|$OwnDir/|g}"
            fi
            echo -e "\n${GREEN}Tips${PLAIN}：可以指定任何一个目录并非仅限于上方检测到的仓库"
            while true; do
                read -p "$(echo -e "\n${BOLD}└ 请输入绝对路径：${PLAIN}")" Input4
                local AbsolutePath=$(echo "$Input4" | perl -pe "{s|/jd/||; s|^*|$RootDir/|;}")
                if [[ $Input4 ]] && [ -d ${AbsolutePath} ]; then
                    break
                else
                    echo -e "\n$ERROR 目录不存在或输入有误！"
                fi
            done
            ls ${AbsolutePath} | egrep "${ScriptType}" | grep -Ev "/|${ShieldingKeywords}" | perl -pe "{s|^|${AbsolutePath}/|g; s|//|/|;}" | sort -u >$RunFile
            local WorkDir=${AbsolutePath}
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
        ## 列出选中脚本清单
        cd $WorkDir
        local ListFiles=($(
            cat $RunFile | perl -pe '{s|^.*/||g;}'
        ))
        echo -e "\n❖ 当前选择的脚本："
        for ((i = 0; i < ${#ListFiles[*]}; i++)); do
            Query_ScriptName ${ListFiles[i]}
            echo -e "$(($i + 1)).${ScriptName}：${ListFiles[i]}"
        done
        cd $CurrentDir
        read -p "$(echo -e "\n${BOLD}└ 请确认是否继续? [Y/n] ${PLAIN}")" Input5
        [ -z ${Input5} ] && Input5=Y
        case $Input5 in
        [Yy] | [Yy][Ee][Ss])
            ChooseRunMod
            ## 补全命令
            sed -i "s/^/$TaskCmd &/g" $RunFile
            sed -i "s/$/& ${RunMode}/g" $RunFile
            sed -i '1i\#!/bin/env bash' $RunFile
            ## 执行前提示
            echo -e "\n$TIPS ${BLUE}Ctrl + Z${PLAIN} 跳过执行当前脚本（若中途卡住可尝试跳过），${BLUE}Ctrl + C${PLAIN} 终止执行全部任务\n"
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
