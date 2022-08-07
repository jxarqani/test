#!/bin/bash
## Author: SuperManito
## Modified: 2022-02-21

ShellDir=${WORK_DIR}/shell
. $ShellDir/share.sh
Make_Dir $CodeDir

if [[ "$(ls -A $CodeDir)" != "" ]]; then
    FileCodeLatestLog=$CodeDir/$(ls -r $CodeDir | head -1)
fi

## 生成 pt_pin 数组
function Gen_pt_pin_Array() {
    Import_Config
    Count_UserSum
    local Tmp1 Tmp2 i pt_pin_temp
    if [[ $UserSum -le 55 ]]; then
        local Num=$UserSum
    elif [[ $UserSum -gt 55 ]]; then
        local Num=55
    fi
    for ((user_num = 1; user_num <= $Num; user_num++)); do
        Tmp1=Cookie$user_num
        Tmp2=${!Tmp1}
        i=$(($user_num - 1))
        pt_pin_temp=$(echo $Tmp2 | perl -pe "{s|.*pt_pin=([^; ]+)(?=;?).*|\1|; s|%|\\\x|g}")
        [[ $pt_pin_temp == *\\x* ]] && pt_pin[i]=$(printf $pt_pin_temp) || pt_pin[i]=$pt_pin_temp
    done
}

## 导出互助码的通用程序，$1：去掉后缀的脚本名称，$2：config.sh中的后缀，$3：活动中文名称
function Export_Codes_Sub() {
    local task_name=$1
    local config_name=$2
    local chinese_name=$3
    local config_name_my=My$config_name
    local config_name_for_other=ForOther$config_name
    local i j k m n pt_pin_in_log code tmp_grep tmp_my_code tmp_for_other user_num random_num_list previous_value
    if cd $LogDir/$task_name &>/dev/null && [[ $(ls) ]]; then
        ## 寻找所有互助码以及对应的pt_pin
        i=0
        pt_pin_in_log=()
        code=()
        pt_pin_and_code=$(ls -r *.log | xargs awk -F '（|）|】' -v var="的${chinese_name}好友互助码" '$3~var {print $2"&"$4}')
        for line in $pt_pin_and_code; do
            pt_pin_in_log[i]=$(echo $line | awk -F "&" '{print $1}')
            code[i]=$(echo $line | awk -F "&" '{print $2}')
            let i++
        done

        ## 输出My系列变量
        if [[ ${#code[*]} -gt 0 ]]; then
            for ((m = 0; m < ${#pt_pin[*]}; m++)); do
                tmp_my_code=""
                previous_value=""
                j=$((m + 1))
                for ((n = 0; n < ${#code[*]}; n++)); do
                    if [[ ${pt_pin[m]} == ${pt_pin_in_log[n]} ]]; then
                        tmp_my_code=${code[n]}
                        break
                    fi
                done
                if [[ -z $tmp_my_code ]] && [[ ! -z $FileCodeLatestLog ]]; then
                    previous_value=$(grep "${config_name_my}${j}" $FileCodeLatestLog | head -1 | awk -F "\'" '{print$2}')
                    echo "$config_name_my$j='${previous_value}'"
                else
                    echo "$config_name_my$j='$tmp_my_code'"
                fi
            done
        else
            echo "## 检测到已运行过该脚本，但未从日志中未找到任何互助码，跳过..."
        fi

        ## 输出ForOther系列变量
        if [[ ${#code[*]} -gt 0 ]]; then
            echo
            case $HelpType in
            0) ## 按编号优先
                for ((m = 0; m < ${#pt_pin[*]}; m++)); do
                    tmp_for_other=""
                    j=$((m + 1))
                    for ((n = 0; n < ${#pt_pin[*]}; n++)); do
                        [[ $m -eq $n ]] && continue
                        k=$((n + 1))
                        tmp_for_other="$tmp_for_other@\${$config_name_my$k}"
                    done
                    echo "$config_name_for_other$j=\"$tmp_for_other\"" | perl -pe "s|($config_name_for_other\d+=\")@|\1|"
                done
                ;;

            1) ## 全部一致
                tmp_for_other=""
                for ((m = 0; m < ${#pt_pin[*]}; m++)); do
                    j=$((m + 1))
                    tmp_for_other="$tmp_for_other@\${$config_name_my$j}"
                done
                echo "${config_name_for_other}1=\"$tmp_for_other\"" | perl -pe "s|($config_name_for_other\d+=\")@|\1|"
                for ((m = 1; m < ${#pt_pin[*]}; m++)); do
                    j=$((m + 1))
                    echo "$config_name_for_other$j=\"\${${config_name_for_other}1}\""
                done
                ;;

            2) ## 均等助力
                for ((m = 0; m < ${#pt_pin[*]}; m++)); do
                    tmp_for_other=""
                    j=$((m + 1))
                    for ((n = $m; n < $((${UserSum} + $m)); n++)); do
                        [[ $m -eq $n ]] && continue
                        if [[ $((n + 1)) -le ${UserSum} ]]; then
                            k=$((n + 1))
                        else
                            k=$((n + 1 - ${UserSum}))
                        fi
                        tmp_for_other="$tmp_for_other@\${$config_name_my$k}"
                    done
                    echo "$config_name_for_other$j=\"$tmp_for_other\"" | perl -pe "s|($config_name_for_other\d+=\")@|\1|"
                done
                ;;

            3) ## 本套脚本内账号间随机顺序助力
                for ((m = 0; m < ${#pt_pin[*]}; m++)); do
                    tmp_for_other=""
                    random_num_list=$(seq ${UserSum} | sort -R)
                    j=$((m + 1))
                    for n in $random_num_list; do
                        [[ $j -eq $n ]] && continue
                        tmp_for_other="$tmp_for_other@\${$config_name_my$n}"
                    done
                    echo "$config_name_for_other$j=\"$tmp_for_other\"" | perl -pe "s|($config_name_for_other\d+=\")@|\1|"
                done
                ;;

            *) ## 按编号优先
                for ((m = 0; m < ${#pt_pin[*]}; m++)); do
                    tmp_for_other=""
                    j=$((m + 1))
                    for ((n = 0; n < ${#pt_pin[*]}; n++)); do
                        [[ $m -eq $n ]] && continue
                        k=$((n + 1))
                        tmp_for_other="$tmp_for_other@\${$config_name_my$k}"
                    done
                    echo "$config_name_for_other$j=\"$tmp_for_other\"" | perl -pe "s|($config_name_for_other\d+=\")@|\1|"
                done
                ;;
            esac
        fi
    else
        echo "## 未运行过 $task_name.js 脚本，没有找到相关日志，跳过..."
    fi
}

## 输出用于提交到 Bot 的助力码格式
function Export_Bot_Submit_Format() {
    local CombinAll Tmp1 Tmp2
    if [[ -d $CodeDir ]]; then
        if [[ $(ls $CodeDir) ]]; then
            local LatestLog=$(ls -r $CodeDir | head -1)
            . $CodeDir/$LatestLog
        fi
    fi
    echo -e "\n\n## 下面是用于 Bot 提交的助力码格式："
    for ((i = 1; i <= ${#name_config[@]}; i++)); do
        local j=$((i - 1))
        CombinAll=""
        for ((m = 1; m <= ${#BotSubmit[@]}; m++)); do
            local n=$(($m - 1))
            Tmp1="My${name_config[j]}${BotSubmit[n]}"
            Tmp2=${!Tmp1}
            CombinAll="${CombinAll}&${Tmp2}"
        done
        echo -e "\n## ${name_chinese[j]}：\n# /${bot_command[j]} $(echo $CombinAll | perl -pe "{s|^&||; s|&&&&|&&&|; s|&&&|&&|; s|&&|&|; s|&$||; s|京东种豆|种豆|;}")"
    done
    echo ''
}

## 汇总输出
function Export_Codes_All() {
    echo -e "\n## 从每个活动脚本的日志中提取互助码，如果 MyXxx变量 的值为空说明对应日志中的对应账号没有输出互助码，原因包括账号失效、不满足活动条件、脚本报错等。"
    echo -e "\n## 每个变量的编号和配置文件中 Cookie编号 完全对应，即使某个 MyXxx变量 未被赋值，也可以将其变量名填在 ForOtherXxx变量 中，脚本会自动过滤空值。"
    echo -e "\n## 如果启用了 \"自动互助\" 功能那么当检测到 MyXxx变量 为空时会从上一个日志中读取，您还可以通过修改日志解决一直无法获取到互助码的问题。\n"
    echo -n "## 当前导出账号数量："
    if [[ $UserSum -le 45 ]]; then
        echo -e "[ $UserSum ]\n"
    elif [[ $UserSum -gt 45 ]]; then
        echo -e "检测到本地实际存在 $UserSum 个账号，由于相关命令不支持处理过多的字符因此已限制导出互助码变量的账号数量为 [ 45 ]\n"
    fi
    echo -n "## 您选择的互助类型为："
    case $HelpType in
    0)
        echo "[ 按账号编号优先 ]"
        ;;
    1)
        echo "[ 所有账号助力码一致 ]"
        ;;
    2)
        echo "[ 所有账号助力机会均等 ]"
        ;;
    3)
        echo "[ 账号间随机顺序助力 ]"
        ;;
    *)
        echo "[ 按账号编号优先 ]"
        ;;
    esac
    for ((i = 0; i < ${#name_script[*]}; i++)); do
        echo -e "\n## ${name_chinese[i]}："
        Export_Codes_Sub "${name_script[i]}" "${name_config[i]}" "${name_chinese[i]}"
    done
}

## 生成 pt_pin 数组
Gen_pt_pin_Array
## 执行并写入日志
LogTime=$(date "+%Y-%m-%d-%H-%M-%S")
LogPath="$CodeDir/${LogTime}.log"
Export_Codes_All | perl -pe "{s|京东种豆|种豆|;}" | tee ${LogPath}
Export_Bot_Submit_Format | tee -a ${LogPath}
