#!/bin/bash
## Author: SuperManito
## Modified: 2021-11-16

ShellDir=${WORK_DIR}/shell
. $ShellDir/share.sh

## 定义 Scripts 仓库
ScriptsBranch="jd_scripts"
ScriptsUrl="${GithubProxy}https://github.com/Aaron-lv/sync.git"

## 创建日志文件夹
Make_Dir $LogDir
## 导入配置文件（不检查）
Import_Config_Not_Check

## 更新crontab，gitee服务器同一时间限制5个链接，因此每个人更新代码必须错开时间，每次执行git_pull随机生成。
## 每天次数随机，更新时间随机，更新秒数随机，至少4次，至多6次，大部分为5次，符合正态分布。
function Random_Update_Cron() {
    local RanMin RanSleep RanHourArray RanHour Tmp
    if [[ $(date "+%-H") -le 2 ]] && [ -f ${ListCrontabUser} ]; then
        RanMin=$((${RANDOM} % 60))
        RanSleep=$((${RANDOM} % 56))
        RanHourArray[0]=$((${RANDOM} % 3))
        RanHour=${RanHourArray[0]}
        for ((i = 1; i < 14; i++)); do
            j=$(($i - 1))
            Tmp=$((${RANDOM} % 3 + ${RanHourArray[j]} + 2))
            [[ ${Tmp} -lt 24 ]] && RanHourArray[i]=${Tmp} || break
        done
        for ((i = 1; i < ${#RanHourArray[*]}; i++)); do
            RanHour="${RanHour},${RanHourArray[i]}"
        done
        perl -i -pe "s|.+(update.+update.+log.*)|${RanMin} ${RanHour} \* \* \* sleep ${RanSleep} && \1|" ${ListCrontabUser}
        crontab ${ListCrontabUser}
    fi
}

## 克隆仓库，$1：仓库地址，$2：仓库保存路径，$3：分支（可省略）
function Git_Clone() {
    local Url=$1
    local Dir=$2
    local Branch=$3
    [[ $Branch ]] && local Command="-b $Branch "
    echo -e "\n$WORKING 开始克隆仓库 $Url 到 $Dir\n"
    git clone $Command $Url $Dir
    ExitStatus=$?
}

## 更新仓库，$1：仓库保存路径
function Git_Pull() {
    local CurrentDir=$(pwd)
    local WorkDir=$1
    local Branch=$2
    cd $WorkDir
    echo -e "\n$WORKING 开始更新仓库：$WorkDir\n"
    git fetch --all
    ExitStatus=$?
    git pull
    git reset --hard origin/$Branch
    cd $CurrentDir
}

## 重置仓库remote url，docker专用，$1：要重置的目录，$2：要重置为的网址
function Reset_Romote_Url() {
    local CurrentDir=$(pwd)
    local WorkDir=$1
    local Url=$2
    local Branch=$3
    if [ -d "$WorkDir/.git" ]; then
        cd $WorkDir
        git remote set-url origin $Url >/dev/null 2>&1
        git fetch --all >/dev/null 2>&1
        git reset --hard origin/$Branch >/dev/null 2>&1
        cd $CurrentDir
    fi
}

## 统计 own 仓库数量
function Count_OwnRepoSum() {
    if [[ -z ${OwnRepoUrl1} ]]; then
        OwnRepoSum=0
    else
        for ((i = 1; i <= 0x64; i++)); do
            local Tmp1=OwnRepoUrl$i
            local Tmp2=${!Tmp1}
            [[ $Tmp2 ]] && OwnRepoSum=$i || break
        done
    fi
}

## 形成 own 仓库的文件夹名清单，依赖于 Import_Conf 或 Import_Config_Not_Check
## array_own_repo_path：repo存放的绝对路径组成的数组；array_own_scripts_path：所有要使用的脚本所在的绝对路径组成的数组
function Gen_Own_Dir_And_Path() {
    local scripts_path_num="-1"
    local repo_num Tmp1 Tmp2 Tmp3 Tmp4 Tmp5 dir

    if [[ $OwnRepoSum -ge 1 ]]; then
        for ((i = 1; i <= $OwnRepoSum; i++)); do
            repo_num=$((i - 1))

            Tmp1=OwnRepoUrl$i
            array_own_repo_url[$repo_num]=${!Tmp1}

            Tmp2=OwnRepoBranch$i
            array_own_repo_branch[$repo_num]=${!Tmp2}

            array_own_repo_dir[$repo_num]=$(echo ${array_own_repo_url[$repo_num]} | perl -pe "s|\.git||" | awk -F "/|:" '{print $((NF - 1)) "_" $NF}')
            array_own_repo_path[$repo_num]=$OwnDir/${array_own_repo_dir[$repo_num]}
            Tmp3=OwnRepoPath$i
            if [[ ${!Tmp3} ]]; then
                for dir in ${!Tmp3}; do
                    let scripts_path_num++
                    Tmp4="${array_own_repo_dir[repo_num]}/$dir"
                    Tmp5=$(echo $Tmp4 | perl -pe "{s|//|/|g; s|/$||}") # 去掉多余的/
                    array_own_scripts_path[$scripts_path_num]="$OwnDir/$Tmp5"
                done
            else
                let scripts_path_num++
                array_own_scripts_path[$scripts_path_num]="${array_own_repo_path[$repo_num]}"
            fi
        done
    fi
    if [[ ${#OwnRawFile[*]} -ge 1 ]]; then
        let scripts_path_num++
        array_own_scripts_path[$scripts_path_num]=$RawDir
    fi
}

## 生成 Scripts仓库 task 清单，仅有去掉后缀的文件名
function Gen_ListTask() {
    Make_Dir $LogTmpDir
    grep -E "node.+j[drx]_\w+\.js" $ListCronScripts | perl -pe "s|.+(j[drx]_\w+)\.js.+|\1|" | sort -u >$ListTaskScripts
    grep -E " $TaskCmd j[drx]_\w+" $ListCrontabUser | perl -pe "s|.*$TaskCmd (j[drx]_\w+).*|\1|" | sort -u >$ListTaskUser
}

## 生成 own 脚本的绝对路径清单
function Gen_ListOwn() {
    local CurrentDir=$(pwd)
    local Own_Scripts_Tmp
    ## 导入用户的定时
    local ListCrontabOwnTmp=$LogTmpDir/crontab_own.list
    grep -vwf $ListOwnScripts $ListCrontabUser | grep -Eq " $TaskCmd $OwnDir"
    local ExitStatus=$?
    [[ $ExitStatus -eq 0 ]] && grep -vwf $ListOwnScripts $ListCrontabUser | grep -E " $TaskCmd $OwnDir" | perl -pe "s|.*$TaskCmd ([^\s]+)( .+\|$)|\1|" | sort -u >$ListCrontabOwnTmp
    rm -rf $LogTmpDir/own*.list
    for ((i = 0; i < ${#array_own_scripts_path[*]}; i++)); do
        cd ${array_own_scripts_path[i]}
        if [ ${array_own_scripts_path[i]} = $RawDir ]; then
            if [[ $(ls | egrep ".js\b|.py\b|.ts\b" | egrep -v "jdCookie.js|USER_AGENTS.js|sendNotify.js" 2>/dev/null) ]]; then
                for file in $(ls | egrep ".js\b|.py\b|.ts\b" | egrep -v "jdCookie.js|USER_AGENTS.js|sendNotify.js"); do
                    if [ -f $file ]; then
                        echo "$RawDir/$file" >>$ListOwnScripts
                    fi
                done
            fi
        else
            if [[ -z $OwnRepoCronShielding ]]; then
                local Matching=$(ls *.js)
            else
                local ShieldTmp=$(echo $OwnRepoCronShielding | perl -pe '{s|\" |\"|g; s| \"|\"|g; s# #|#g;}')
                local Matching=$(ls *.js | egrep -v ${ShieldTmp})
            fi
            if [[ $(ls *.js 2>/dev/null) ]]; then
                ls | grep "\.js\b" -q
                if [ $? -eq 0 ]; then
                    for file in $Matching; do
                        if [ -f $file ]; then
                            perl -ne "print if /.*([\d\*]*[\*-\/,\d]*[\d\*] ){4}[\d\*]*[\*-\/,\d]*[\d\*]( |,|\").*\/?$file/" $file |
                                perl -pe "s|.*(([\d\*]*[\*-\/,\d]*[\d\*] ){4}[\d\*]*[\*-\/,\d]*[\d\*])( \|,\|\").*/?$file.*|${array_own_scripts_path[i]}/$file|g" |
                                sort -u | head -1 >>$ListOwnScripts
                        fi
                    done
                fi
            fi
        fi
    done
    ## 汇总去重
    Own_Scripts_Tmp=$(sort -u $ListOwnScripts)
    echo "$Own_Scripts_Tmp" >$ListOwnScripts
    ## 导入用户的定时
    cat $ListOwnScripts >$ListOwnAll
    [[ $ExitStatus -eq 0 ]] && cat $ListCrontabOwnTmp >>$ListOwnAll

    if [[ $ExitStatus -eq 0 ]]; then
        grep -E " $TaskCmd $OwnDir" $ListCrontabUser | egrep -v "$(cat $ListCrontabOwnTmp)" | perl -pe "s|.*$TaskCmd ([^\s]+)( .+\|$)|\1|" | sort -u >$ListOwnUser
        cat $ListCrontabOwnTmp >>$ListOwnUser
    else
        grep -E " $TaskCmd $OwnDir" $ListCrontabUser | perl -pe "s|.*$TaskCmd ([^\s]+)( .+\|$)|\1|" | sort -u >$ListOwnUser
    fi
    [ -f $ListCrontabOwnTmp ] && rm -f $ListCrontabOwnTmp
    cd $CurrentDir
}

## 检测cron的差异，$1：脚本清单文件路径，$2：cron任务清单文件路径，$3：增加任务清单文件路径，$4：删除任务清单文件路径
function Diff_Cron() {
    Make_Dir $LogTmpDir
    local ListScripts="$1"
    local ListTask="$2"
    local ListAdd="$3"
    local ListDrop="$4"
    if [ -s $ListTask ] && [ -s $ListScripts ]; then
        diff $ListScripts $ListTask | grep "<" | awk '{print $2}' >$ListAdd
        diff $ListScripts $ListTask | grep ">" | awk '{print $2}' >$ListDrop
    elif [ ! -s $ListTask ] && [ -s $ListScripts ]; then
        cp -f $ListScripts $ListAdd
    elif [ -s $ListTask ] && [ ! -s $ListScripts ]; then
        cp -f $ListTask $ListDrop
    fi
}

## 检测配置文件版本
function Detect_Config_Version() {
    ## 识别出两个文件的版本号
    VerConfSample=$(grep " Version: " $FileConfSample | perl -pe "s|.+v((\d+\.?){3})|\1|")
    [ -f $FileConfUser ] && VerConfUser=$(grep " Version: " $FileConfUser | perl -pe "s|.+v((\d+\.?){3})|\1|")
    ## 删除旧的发送记录文件
    [ -f $FileSendMark ] && [[ $(cat $FileSendMark) != $VerConfSample ]] && rm -f $FileSendMark
    ## 识别出更新日期和更新内容
    UpdateDate=$(grep " Date: " $FileConfSample | awk -F ": " '{print $2}')
    UpdateContent=$(grep " Update Content: " $FileConfSample | awk -F ": " '{print $2}')
    ## 如果是今天，并且版本号不一致，则发送通知
    if [ -f $FileConfUser ] && [[ $VerConfUser != $VerConfSample ]] && [[ $UpdateDate == $(date "+%Y-%m-%d") ]]; then
        if [ ! -f $FileSendMark ]; then
            local NotifyTitle="配置文件更新通知"
            local NotifyContent="更新日期: $UpdateDate\n当前版本: $VerConfUser\n新的版本: $VerConfSample\n更新内容: $UpdateContent\n"
            echo -e $NotifyContent
            Notify "$NotifyTitle" "$NotifyContent"
            [ $? -eq 0 ] && echo $VerConfSample >$FileSendMark
        fi
    else
        [ -f $FileSendMark ] && rm -f $FileSendMark
    fi
}

## npm install 安装脚本依赖模块，$1：package.json 文件所在路径
function Npm_Install_Standard() {
    local CurrentDir=$(pwd)
    local WorkDir=$1
    cd $WorkDir
    echo -e "\n$WORKING 开始执行 npm install ...\n"
    npm install
    [ $? -ne 0 ] && echo -e "\n$ERROR 检测到脚本所需的依赖模块安装失败，请进入 $WorkDir 目录后手动执行 npm install ...\n"
    cd $CurrentDir
}
function Npm_Install_Upgrade() {
    local CurrentDir=$(pwd)
    local WorkDir=$1
    cd $WorkDir
    echo -e "\n$WORKING 检测到 $WorkDir 目录脚本所需的依赖模块有所变动，执行 npm install ...\n"
    npm install
    [ $? -ne 0 ] && echo -e "\n$ERROR 检测到模块安装失败，再次尝试一遍...\n" && Npm_Install_Standard $WorkDir
    cd $CurrentDir
}

## 输出是否有新的或失效的定时任务，$1：新的或失效的任务清单文件路径，$2：新/失效
function Output_List_Add_Drop() {
    local List=$1
    local Type=$2
    if [ -s $List ]; then
        echo -e "\n检测到有$Type的定时任务：\n"
        cat $List
        echo
    fi
}

## 自动删除失效的脚本与定时任务，需要：1.AutoDelCron/AutoDelOwnRepoCron/AutoDelOwnRawCron 设置为 true；2.正常更新脚本，没有报错；3.存在失效任务；4.crontab.list存在并且不为空
## $1：失效任务清单文件路径，$2：task
function Del_Cron() {
    local ListDrop=$1
    local Type=$2
    local Detail Detail2
    if [ -s $ListDrop ] && [ -s $ListCrontabUser ]; then
        Detail=$(cat $ListDrop)
        echo -e "$WORKING 开始删除定时任务...\n"
        for cron in $Detail; do
            local Tmp=$(echo $cron | perl -pe "s|/|\.|g")
            perl -i -ne "{print unless / $Type $Tmp( |$)/}" $ListCrontabUser
        done
        crontab $ListCrontabUser
        Detail2=$(echo $Detail | perl -pe "s| |\\\n|g")
        echo -e "$SUCCESS 成功删除失效的定时任务\n"
        Notify "失效定时任务通知" "已删除以下失效的定时任务：\n\n$Detail2"
    fi
}

## 自动增加 Scripts 仓库新的定时任务，需要：1.AutoAddCron 设置为 true；2.正常更新脚本，没有报错；3.存在新任务；4.crontab.list存在并且不为空
## $1：新任务清单文件路径
function Add_Cron_Scripts() {
    local ListAdd=$1
    if [[ ${AutoAddCron} == true ]] && [ -s $ListAdd ] && [ -s $ListCrontabUser ]; then
        echo -e "$WORKING 开始尝试自动添加 Scipts 仓库的定时任务...\n"
        local Detail=$(cat $ListAdd)
        for cron in $Detail; do
            if [[ $cron == jd_bean_sign ]]; then
                echo "4 0,9 * * * $TaskCmd $cron" >>$ListCrontabUser
            else
                cat $ListCronScripts | grep -E "\/$cron\." | perl -pe "s|(^.+)node */scripts/(j[drx]_\w+)\.js.+|\1$TaskCmd \2|" >>$ListCrontabUser
            fi
        done
        ExitStatus=$?
    fi
}

## 自动增加自己额外的脚本的定时任务，需要：1.AutoAddOwnRepoCron/AutoAddOwnRawCron 设置为 true；2.正常更新脚本，没有报错；3.存在新任务；4.crontab.list存在并且不为空
## $1：新任务清单文件路径
function Add_Cron_Own() {
    local ListAdd=$1
    local ListCrontabOwnTmp=$LogTmpDir/crontab_own.list
    [ -f $ListCrontabOwnTmp ] && rm -f $ListCrontabOwnTmp
    if [ -s $ListAdd ] && [ -s $ListCrontabUser ]; then
        echo -e "$WORKING 开始添加 own 脚本的定时任务...\n"
        local Detail=$(cat $ListAdd)
        for FilePath in $Detail; do
            local FileName=$(echo $FilePath | awk -F "/" '{print $NF}')
            if [ -f $FilePath ]; then
                if [ $FilePath = "$RawDir/$FileName" ]; then
                    ## 判断表达式所在行
                    local Tmp1=$(grep -E "cron|script-path|tag|\* \*|$FileName" $FilePath | head -1 | perl -pe '{s|[a-zA-Z\"\.\=\:\:\_]||g;}')
                    ## 判断开头
                    local Tmp2=$(echo "${Tmp1}" | awk -F '[0-9]' '{print$1}' | sed 's/\*/\\*/g; s/\./\\./g')
                    ## 判断表达式的第一个数字（分钟）
                    local Tmp3=$(echo "${Tmp1}" | grep -Eo "[0-9]" | head -1)
                    ## 判定开头是否为空值
                    if [[ $(echo "${Tmp2}" | perl -pe '{s| ||g;}') = "" ]]; then
                        cron=$(echo "${Tmp1}" | awk '{if($1~/^[0-9]{1,2}/) print $1,$2,$3,$4,$5; else if ($1~/^[*]/) print $2,$3,$4,$5,$6}')
                    else
                        cron=$(echo "${Tmp1}" | perl -pe "{s|${Tmp2}${Tmp3}|${Tmp3}|g;}" | awk '{if($1~/^[0-9]{1,2}/) print $1,$2,$3,$4,$5; else if ($1~/^[*]/) print $2,$3,$4,$5,$6}')
                    fi
                    echo "$cron $TaskCmd $FilePath" | sort -u | head -1 >>$ListCrontabOwnTmp
                else
                    perl -ne "print if /.*([\d\*]*[\*-\/,\d]*[\d\*] ){4}[\d\*]*[\*-\/,\d]*[\d\*]( |,|\").*$FileName/" $FilePath |
                        perl -pe "{s|[^\d\*]*(([\d\*]*[\*-\/,\d]*[\d\*] ){4,5}[\d\*]*[\*-\/,\d]*[\d\*])( \|,\|\").*/?$FileName.*|\1 $TaskCmd $FilePath|g;s|  | |g; s|^[^ ]+ (([^ ]+ ){5}$TaskCmd $FilePath)|\1|;}" |
                        sort -u | grep -Ev "^\*|^ \*" | head -1 >>$ListCrontabOwnTmp
                fi
            fi
        done
        Crontab_Tmp="$(cat $ListCrontabOwnTmp)"
        perl -i -pe "s|(# 自用own任务结束.+)|$Crontab_Tmp\n\1|" $ListCrontabUser
        ExitStatus=$?
    fi
    [ -f $ListCrontabOwnTmp ] && rm -f $ListCrontabOwnTmp
}

## 向系统添加定时任务以及通知，$1：写入crontab.list时的exit状态，$2：新增清单文件路径，$3：Scripts仓库脚本/own脚本
function Add_Cron_Notify() {
    local Status_Code=$1
    local ListAdd=$2
    local Tmp=$(echo $(cat $ListAdd))
    local Detail=$(echo $Tmp | perl -pe "s| |\\\n|g")
    local Type=$3
    if [[ $Status_Code -eq 0 ]]; then
        crontab $ListCrontabUser
        echo -e "$SUCCESS 成功添加新的定时任务\n"
        Notify "新增定时任务通知" "已添加新的定时任务（$Type）：\n\n$Detail"
    else
        echo -e "添加新的定时任务出错，请手动添加...\n"
        Notify "新任务添加失败通知" "尝试自动添加以下新的定时任务出错，请尝试手动添加（$Type）：\n\n$Detail"
    fi
}

## 更新所有 Own 仓库
function Update_OwnRepo() {
    for ((i = 0; i < ${#array_own_repo_url[*]}; i++)); do
        if [ -d ${array_own_repo_path[i]}/.git ]; then
            Reset_Romote_Url ${array_own_repo_path[i]} ${array_own_repo_url[i]} ${array_own_repo_branch[i]}
            Git_Pull ${array_own_repo_path[i]} ${array_own_repo_branch[i]}
        else
            Git_Clone ${array_own_repo_url[i]} ${array_own_repo_path[i]} ${array_own_repo_branch[i]}
        fi
        if [[ $ExitStatus -eq 0 ]]; then
            echo -e "\n$COMPLETE ${array_own_repo_dir[i]} 仓库更新完成"
        else
            echo -e "\n$ERROR ${array_own_repo_dir[i]} 仓库更新失败，请检查原因..."
        fi
    done
}

## 更新所有 Raw 脚本
function Update_OwnRaw() {
    local rm_mark format_url repository_platform repository_branch reformat_url repository_url repository_url_tmp
    for ((i = 0; i < ${#OwnRawFile[*]}; i++)); do
        raw_file_name[$i]=$(echo ${OwnRawFile[i]} | awk -F "/" '{print $NF}')
        ## 判断脚本来源仓库
        repository_url_tmp=$(echo ${OwnRawFile[i]} | perl -pe "{s|${raw_file_name[$i]}||g;}")
        format_url=$(echo $repository_url_tmp | awk -F '.com' '{print$NF}' | sed 's/.$//')
        case $(echo $repository_url_tmp | egrep -o "github|gitee") in
        github)
            repository_platform="https://github.com"
            repository_branch=$(echo $format_url | awk -F '/' '{print$4}')
            reformat_url=$(echo $format_url | sed "s|$repository_branch|tree/$repository_branch|g")
            ;;
        gitee)
            repository_platform="https://gitee.com"
            reformat_url=$(echo $format_url | sed "s|/raw/|/tree/|g")
            ;;
        esac
        repository_url="$repository_platform$reformat_url"
        echo -e "\n$WORKING 开始从仓库 $repository_url 下载 ${raw_file_name[$i]} 脚本"
        wget -q --no-check-certificate -O "$RawDir/${raw_file_name[$i]}.new" ${OwnRawFile[i]} -T 10
        if [ $? -eq 0 ]; then
            mv -f "$RawDir/${raw_file_name[$i]}.new" "$RawDir/${raw_file_name[$i]}"
            echo -e "$COMPLETE ${raw_file_name[$i]} 下载完成，脚本保存路径：$RawDir/${raw_file_name[$i]}"
        else
            echo -e "$ERROR 下载 ${raw_file_name[$i]} 失败，保留之前正常下载的版本...\n"
            [ -f "$RawDir/${raw_file_name[$i]}.new" ] && rm -f "$RawDir/${raw_file_name[$i]}.new"
        fi
    done
    for file in $(ls $RawDir | egrep -v "jdCookie\.js|USER_AGENTS|sendNotify\.js|node_modules|\.json\b"); do
        rm_mark="yes"
        for ((i = 0; i < ${#raw_file_name[*]}; i++)); do
            if [[ $file == ${raw_file_name[$i]} ]]; then
                rm_mark="no"
                break
            fi
        done
        [[ $rm_mark == yes ]] && rm -f $RawDir/$file 2>/dev/null
    done
}

## 更新项目源码
function Update_Shell() {
    echo -e "-------------------------------------------------------------"
    ## 更新前先存储package.json
    [ -f $PanelDir/package.json ] && local PanelDependOld=$(cat $PanelDir/package.json)
    ## 随机更新任务的定时
    Random_Update_Cron
    ## 更新仓库
    cd $RootDir
    echo -e "\n$WORKING 开始更新源码：/jd\n"
    git fetch --all
    git pull
    git reset --hard origin/$(git status | head -n 1 | awk -F ' ' '{print$NF}')
    if [[ $ExitStatus -eq 0 ]]; then
        echo -e "\n$COMPLETE 源码更新完成\n"
    else
        echo -e "\n$ERROR 源码更新失败，请检查原因...\n"
    fi
    ## 检测面板模块变动
    [ -f $PanelDir/package.json ] && local PanelDependNew=$(cat $PanelDir/package.json)
    if [[ "$PanelDependOld" != "$PanelDependNew" ]]; then
        if [[ $ENABLE_WEB_PANEL = true ]]; then
            pm2 delete server >/dev/null 2>&1
            $ContrlCmd panel on
        else
            Npm_Install_Upgrade $PanelDir
        fi
    fi
    ## 检测配置文件版本
    Detect_Config_Version
}

## 更新 Scripts 仓库
function Update_Scripts() {
    echo -e "-------------------------------------------------------------"
    ## 更新前先存储package.json
    [ -f $ScriptsDir/package.json ] && local ScriptsDependOld=$(cat $ScriptsDir/package.json)
    ## 更新仓库
    if [ -d $ScriptsDir/.git ]; then
        Git_Pull $ScriptsDir $ScriptsBranch
    else
        Git_Clone $ScriptsUrl $ScriptsDir $ScriptsBranch
    fi
    if [[ $ExitStatus -eq 0 ]]; then
        ## 安装模块
        [ ! -d $ScriptsDir/node_modules ] && Npm_Install_Standard $ScriptsDir
        [ -f $ScriptsDir/package.json ] && local ScriptsDependNew=$(cat $ScriptsDir/package.json)
        [[ "$ScriptsDependOld" != "$ScriptsDependNew" ]] && Npm_Install_Upgrade $ScriptsDir
        ## 检测定时清单
        if [[ ! -f $ScriptsDir/docker/crontab_list.sh ]]; then
            cp -rf $UtilsDir/crontab_list_public.sh $ScriptsDir/docker
        fi
        ## 更换 sendNotify
        [ -f $FileSendNotify ] && cp -rf $FileSendNotify $ScriptsDir
        ## 比较定时任务
        Gen_ListTask
        Diff_Cron $ListTaskScripts $ListTaskUser $ListTaskAdd $ListTaskDrop
        ## 删除定时任务 & 通知
        if [ -s $ListTaskDrop ]; then
            Output_List_Add_Drop $ListTaskDrop "失效"
            [[ ${AutoDelCron} == true ]] && Del_Cron $ListTaskDrop $TaskCmd
        fi
        ## 新增定时任务 & 通知
        if [ -s $ListTaskAdd ]; then
            Output_List_Add_Drop $ListTaskAdd "新"
            Add_Cron_Scripts $ListTaskAdd
            [[ ${AutoAddCron} == true ]] && Add_Cron_Notify $ExitStatus $ListTaskAdd " Scripts 仓库脚本"
        fi
        echo -e "\n$COMPLETE Scripts 仓库更新完成\n"
    else
        echo -e "\n$ERROR Scripts 仓库更新失败，请检查原因...\n"
    fi
}

## 更新 Own 仓库和 Raw 脚本
function Update_Own() {
    Count_OwnRepoSum
    Gen_Own_Dir_And_Path
    Make_Dir $RawDir
    local EnableRepoUpdate EnableRawUpdate
    case $1 in
    all)
        EnableRepoUpdate="true"
        EnableRawUpdate="true"
        ;;
    repo)
        EnableRepoUpdate="true"
        EnableRawUpdate="false"
        if [[ $OwnRepoSum -eq 0 ]]; then
            Fix_Crontab
            Notice
            exit
        fi
        ;;
    raw)
        EnableRepoUpdate="false"
        EnableRawUpdate="true"
        if [[ ${#OwnRawFile[*]} -eq 0 ]]; then
            clear
            echo -e "\n$ERROR 请先在 $FileConfUser 中配置好您的 Raw 脚本！"
            Help
            exit
        fi
        ;;
    esac
    if [[ ${#array_own_scripts_path[*]} -gt 0 ]]; then
        echo -e "-------------------------------------------------------------"
        ## 更新仓库
        if [[ ${EnableRepoUpdate} == true ]]; then
            Update_OwnRepo
        fi
        if [[ ${EnableRawUpdate} == true ]]; then
            Update_OwnRaw
        fi
        ## 比较定时任务
        Gen_ListOwn
        Diff_Cron $ListOwnAll $ListOwnUser $ListOwnAdd $ListOwnDrop
        ## Own Repo 仓库
        if [[ ${EnableRepoUpdate} == true ]]; then
            ## 比对清单
            grep -v "$RawDir/" $ListOwnAdd >$ListOwnRepoAdd
            grep -v "$RawDir/" $ListOwnDrop >$ListOwnRepoDrop
            ## 删除定时任务 & 通知
            if [[ ${AutoDelOwnRepoCron} == true ]] && [ -s $ListOwnRepoDrop ]; then
                Output_List_Add_Drop $ListOwnRepoDrop "失效"
                Del_Cron $ListOwnRepoDrop $TaskCmd
            fi
            ## 新增定时任务 & 通知
            if [[ ${AutoAddOwnRepoCron} == true ]] && [ -s $ListOwnRepoAdd ]; then
                Output_List_Add_Drop $ListOwnRepoAdd "新"
                Add_Cron_Own $ListOwnRepoAdd
                Add_Cron_Notify $ExitStatus $ListOwnRepoAdd " Own 仓库脚本"
            fi
        fi
        ## Own Raw 脚本
        if [[ ${EnableRawUpdate} == true ]]; then
            ## 比对清单
            grep "$RawDir/" $ListOwnAdd >$ListOwnRawAdd
            grep "$RawDir/" $ListOwnDrop >$ListOwnRawDrop
            ## 删除定时任务 & 通知
            if [[ ${AutoDelOwnRawCron} == true ]] && [ -s $ListOwnRawDrop ]; then
                Output_List_Add_Drop $ListOwnRawDrop "失效"
                Del_Cron $ListOwnRawDrop $TaskCmd
            fi
            ## 新增定时任务 & 通知
            if [[ ${AutoAddOwnRawCron} == true ]] && [ -s $ListOwnRawAdd ]; then
                Output_List_Add_Drop $ListOwnRawAdd "新"
                Add_Cron_Own $ListOwnRawAdd
                Add_Cron_Notify $ExitStatus $ListOwnRawAdd " Raw 脚本"
            fi
        fi
        echo ''
    else
        perl -i -ne "{print unless / $TaskCmd \/jd\/own/}" $ListCrontabUser
    fi
}

## 自定义脚本
function ExtraShell() {
    if [[ ${EnableExtraShell} = true || ${EnableExtraShellSync} = true ]]; then
        echo -e "-------------------------------------------------------------\n"
    fi
    ## 同步用户的 extra.sh
    if [[ $EnableExtraShellSync == true ]] && [[ $ExtraShellSyncUrl ]]; then
        echo -e "$WORKING 开始同步自定义脚本：$ExtraShellSyncUrl\n"
        wget -q --no-check-certificate $ExtraShellSyncUrl -O $FileExtra.new -T 10
        if [ $? -eq 0 ]; then
            mv -f "$FileExtra.new" "$FileExtra"
            echo -e "$COMPLETE 自定义脚本同步完成\n"
            sleep 1s
        else
            if [ -f $FileExtra ]; then
                echo -e "$ERROR 自定义脚本同步失败，保留之前的版本...\n"
            else
                echo -e "$ERROR 自定义脚本同步失败，请检查原因...\n"
            fi
            sleep 2s
        fi
        [ -f "$FileExtra.new" ] && rm -rf "$FileExtra.new"
    fi
    ## 执行用户的 extra.sh
    if [[ $EnableExtraShell == true ]]; then
        ## 执行
        if [ -f $FileExtra ]; then
            echo -e "$WORKING 开始执行自定义脚本：$FileExtra\n"
            . $FileExtra
            echo -e "\n$COMPLETE 自定义脚本执行完毕\n"
        else
            echo -e "$ERROR 自定义脚本不存在，跳过执行...\n"
        fi
    fi
}

## 更新指定路径下的仓库
function Update_Specify() {
    local input=${1%*/}
    local AbsolutePath PwdTmp
    ## 判定输入的是绝对路径还是相对路径
    echo $input | grep $RootDir -q
    if [ $? -eq 0 ]; then
        AbsolutePath=$input
    else
        echo $input | grep "\.\./" -q
        if [ $? -eq 0 ]; then
            PwdTmp=$(pwd | perl -pe "{s|/$(pwd | awk -F '/' '{printf$NF}')||g;}")
            AbsolutePath=$(echo "$input" | perl -pe "{s|\.\./|${PwdTmp}/|;}")
        else
            if [[ $(pwd) == "/root" ]]; then
                AbsolutePath=$(echo "$input" | perl -pe "{s|\./||; s|^*|$RootDir/|;}")
            else
                AbsolutePath=$(echo "$input" | perl -pe "{s|\./||; s|^*|$(pwd)/|;}")
            fi
        fi
    fi
    if [ -d ${AbsolutePath}/.git ]; then
        Title "specify"
        case ${AbsolutePath} in
        /jd)
            Update_Shell
            ;;
        /jd/scripts)
            Update_Scripts
            ;;
        *)
            echo -e "-------------------------------------------------------------"
            Git_Pull ${AbsolutePath} $(grep "branch" ${AbsolutePath}/.git/config | awk -F '\"' '{print$2}')
            if [[ $ExitStatus -eq 0 ]]; then
                echo -e "\n$COMPLETE ${AbsolutePath} 仓库更新完成\n"
                echo -e "注意：此模式下不会附带更新定时任务等\n"
            else
                echo -e "\n$ERROR ${AbsolutePath} 仓库更新失败，请检查原因...\n"
            fi
            ;;
        esac
    else
        echo -e "\n$ERROR 未检测到 ${AbsolutePath} 路径下存在仓库，请重新确认！\n"
        exit
    fi
}

## 修复crontab
function Fix_Crontab() {
    if [[ $WORK_DIR ]]; then
        perl -i -pe "s|( ?&>/dev/null)+||g" $ListCrontabUser
        Update_Crontab
    fi
}

function Title() {
    local p=$1
    local Mod
    case $1 in
    all)
        Mod="    全 部    "
        ;;
    shell)
        Mod="    源 码    "
        ;;
    scripts)
        Mod=" Scripts 仓库"
        ;;
    own)
        Mod=" 仅 Own 仓库 "
        ;;
    repo)
        Mod=" 所 有 仓 库 "
        ;;
    raw)
        Mod=" 仅 Raw 脚本 "
        ;;
    extra)
        Mod="仅 Extra 脚本"
        ;;
    specify)
        Mod=" 指 定 仓 库 "
        ;;
    esac
    echo -e "\n+----------------- 开 始 执 行 更 新 脚 本 -----------------+"
    echo -e ''
    echo -e "                系统时间：$(date "+%Y-%m-%d %T")"
    echo -e ''
    echo -e "         更新模式：$Mod     脚本根目录：$RootDir"
    echo -e ''
    echo -e "    Scripts仓库目录：$ScriptsDir     Own仓库目录：$OwnDir"
    echo -e ''
}
function Notice() {
    echo -e "+----------------------- 郑 重 提 醒 -----------------------+"
    echo -e ""
    echo -e "  本项目为非营利性的公益闭源项目，脚本免费使用仅供用于学习！"
    echo -e ""
    echo -e "  圈内资源禁止以任何形式发布到咸鱼等国内平台，否则后果自负！"
    echo -e ""
    echo -e "  我们始终致力于打击使用本项目进行违法贩卖行为的个人或组织！"
    echo -e ""
    echo -e "  我们不会放纵某些行为，不保证不采取非常手段，请勿挑战底线！"
    echo -e ""
    echo -e "+-----------------------------------------------------------+\n"
}

## 组合函数
function Combin_Function() {
    case $# in
    0)
        Title "all"
        Update_Shell
        Update_Scripts
        Update_Own "all"
        ExtraShell
        Fix_Crontab
        Notice
        exit 0
        ;;
    1)
        case $1 in
        all)
            Title $1
            Update_Shell
            Update_Scripts
            Update_Own "all"
            ExtraShell
            ;;
        shell)
            Title $1
            Update_Shell
            ;;
        scripts)
            Title $1
            Update_Scripts
            ;;
        own)
            Title $1
            Update_Own "all"
            ;;
        repo)
            Title $1
            Update_Scripts
            Update_Own "repo"
            ;;
        raw)
            Title $1
            Update_Own "raw"
            ;;
        extra)
            if [[ $EnableExtraShellSync == true ]] || [[ $EnableExtraShell == true ]]; then
                Title $1
                ExtraShell
            else
                echo -e "\n$ERROR 请先在 $FileConfUser 中启用关于 Extra 自定义脚本的相关变量！"
                Help
            fi
            ;;
        *)
            echo $1 | grep "/" -q
            if [ $? -eq 0 ]; then
                Update_Specify $1
            else
                Output_Command_Error 1
                exit
            fi
            ;;
        esac
        Fix_Crontab
        Notice
        exit 0
        ;;
    *)
        Output_Command_Error 2
        ;;
    esac
}
Combin_Function "$@"
