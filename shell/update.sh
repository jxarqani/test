#!/bin/bash
## Author: SuperManito
## Modified: 2022-01-24

ShellDir=${WORK_DIR}/shell
. $ShellDir/share.sh

## 定义 Scripts 仓库
ScriptsBranch=${ScriptsRepoBranch}
if [[ ${ENABLE_SCRIPTS_PROXY} == false ]]; then
    ScriptsUrl=${ScriptsRepoUrl}
else
    ScriptsUrl=$(echo ${ScriptsRepoUrl} | perl -pe '{s|github\.com|github\.com\.cnpmjs\.org|g}')
fi

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

## 克隆仓库
## 注释  $1：仓库地址，$2：仓库保存路径，$3：分支（可省略）
function Git_Clone() {
    local Url=$1
    local Dir=$2
    local Branch=$3
    [[ $Branch ]] && local Command="-b $Branch "
    echo -e "\n$WORKING 开始克隆仓库 ${BLUE}$Url${PLAIN} 到 ${BLUE}$Dir${PLAIN}\n"
    git clone $Command $Url $Dir
    ExitStatus=$?
}

## 更新仓库
## 注释  $1：仓库保存路径
function Git_Pull() {
    local CurrentDir=$(pwd)
    local WorkDir=$1
    local Branch=$2
    cd $WorkDir
    echo -e "\n$WORKING 开始更新仓库：${BLUE}$WorkDir${PLAIN}\n"
    git fetch --all
    ExitStatus=$?
    git pull
    git reset --hard origin/$Branch
    cd $CurrentDir
}

## 重置仓库远程链接 remote url
## 注释  $1：要重置的目录，$2：要重置为的网址
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

## 生成 own 仓库信息的数组，组依赖于 Import_Conf 或 Import_Config_Not_Check
## array_own_repo_path：repo存放的绝对路径组成的数组；array_own_scripts_path：所有要使用的脚本所在的绝对路径组成的数组
function Gen_Own_Dir_And_Path() {
    local scripts_path_num="-1"
    local repo_num Tmp1 Tmp2 Tmp3 Tmp4 Tmp5 dir

    if [[ $OwnRepoSum -ge 1 ]]; then
        for ((i = 1; i <= $OwnRepoSum; i++)); do
            repo_num=$((i - 1))
            ## 仓库地址
            Tmp1=OwnRepoUrl$i
            array_own_repo_url[$repo_num]=${!Tmp1}
            ## 仓库分支
            Tmp2=OwnRepoBranch$i
            array_own_repo_branch[$repo_num]=${!Tmp2}
            ## 仓库文件夹名（作者_仓库名）
            array_own_repo_dir[$repo_num]=$(echo ${array_own_repo_url[$repo_num]} | perl -pe "s|\.git||" | awk -F "/|:" '{print $((NF - 1)) "_" $NF}')
            ## 仓库路径
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

## 生成 Scripts仓库的定时任务清单，内容为去掉后缀的脚本名
function Gen_ListTask() {
    Make_Dir $LogTmpDir
    grep -E "node.+j[drx]_\w+\.js" $ListCronScripts | perl -pe "s|.+(j[drx]_\w+)\.js.+|\1|" | sort -u >$ListTaskScripts
    grep -E " $TaskCmd j[drx]_\w+" $ListCrontabUser | perl -pe "s|.*$TaskCmd (j[drx]_\w+).*|\1|" | sort -u >$ListTaskUser
}

## 生成 own 脚本的绝对路径清单
function Gen_ListOwn() {
    local CurrentDir=$(pwd)
    ## 导入用户的定时
    local ListCrontabOwnTmp=$LogTmpDir/crontab_own.list
    [ ! -f $ListOwnScripts ] && Make_Dir $LogTmpDir && touch $ListOwnScripts
    grep -vwf $ListOwnScripts $ListCrontabUser | grep -Eq " $TaskCmd $OwnDir"
    local ExitStatus=$?
    [[ $ExitStatus -eq 0 ]] && grep -vwf $ListOwnScripts $ListCrontabUser | grep -E " $TaskCmd $OwnDir" | perl -pe "s|.*$TaskCmd ([^\s]+)( .+\|$)|\1|" | sort -u >$ListCrontabOwnTmp
    rm -rf $LogTmpDir/own*.list
    for ((i = 0; i < ${#array_own_scripts_path[*]}; i++)); do
        cd ${array_own_scripts_path[i]}
        if [ ${array_own_scripts_path[i]} = $RawDir ]; then
            if [[ $(ls | grep -E "\.js\b|\.py\b|\.ts\b" | grep -Ev "${RawDirUtils}" 2>/dev/null) ]]; then
                for file in $(ls | grep -E "\.js\b|\.py\b|\.ts\b" | grep -Ev "${RawDirUtils}"); do
                    if [ -f $file ]; then
                        echo "$RawDir/$file" >>$ListOwnScripts
                    fi
                done
            fi
        else
            ## Own仓库脚本定时屏蔽
            if [[ -z ${OwnRepoCronShielding} ]]; then
                local Matching=$(ls *.js 2>/dev/null)
            else
                local ShieldTmp=$(echo ${OwnRepoCronShielding} | perl -pe '{s|\" |\"|g; s| \"|\"|g; s# #\|#g;}')
                local Matching=$(ls *.js 2>/dev/null | grep -Ev ${ShieldTmp})
            fi
            if [[ $(ls *.js 2>/dev/null) ]]; then
                ls | grep "\.js\b" -q
                if [ $? -eq 0 ]; then
                    for file in ${Matching}; do
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
    echo "$(sort -u $ListOwnScripts)" >$ListOwnScripts
    ## 导入用户的定时
    cat $ListOwnScripts >$ListOwnAll
    [[ $ExitStatus -eq 0 ]] && cat $ListCrontabOwnTmp >>$ListOwnAll

    if [[ $ExitStatus -eq 0 ]]; then
        grep -E " $TaskCmd $OwnDir" $ListCrontabUser | grep -Ev "$(cat $ListCrontabOwnTmp)" | perl -pe "s|.*$TaskCmd ([^\s]+)( .+\|$)|\1|" | sort -u >$ListOwnUser
        cat $ListCrontabOwnTmp >>$ListOwnUser
    else
        grep -E " $TaskCmd $OwnDir" $ListCrontabUser | perl -pe "s|.*$TaskCmd ([^\s]+)( .+\|$)|\1|" | sort -u >$ListOwnUser
    fi
    [ -f $ListCrontabOwnTmp ] && rm -f $ListCrontabOwnTmp
    cd $CurrentDir
}

## 检测cron的差异
## 注释  $1：脚本清单文件路径，$2：cron任务清单文件路径，$3：增加任务清单文件路径，$4：删除任务清单文件路径
function Diff_Cron() {
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
    UpdateContent=$(grep " Update Content: " $FileConfSample | awk -F ": " '{print $2}' | sed "s/[0-9]\./\\\n&/g")
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

## npm install 安装脚本依赖模块
## 注释  $1：package.json 文件所在路径
function Npm_Install_Standard() {
    local CurrentDir=$(pwd)
    local WorkDir=$1
    cd $WorkDir
    echo -e "\n$WORKING 开始执行 npm install ...\n"
    npm install
    [ $? -ne 0 ] && echo -e "\n$FAIL 检测到脚本所需的依赖模块安装失败，请进入 $WorkDir 目录后手动执行 npm install ...\n"
    cd $CurrentDir
}
function Npm_Install_Upgrade() {
    local CurrentDir=$(pwd)
    local WorkDir=$1
    cd $WorkDir
    echo -e "\n$WORKING 检测到 $WorkDir 目录脚本所需的依赖模块有所变动，执行 npm install ...\n"
    npm install
    [ $? -ne 0 ] && echo -e "\n$FAIL 检测到模块安装失败，再次尝试一遍...\n" && Npm_Install_Standard $WorkDir
    cd $CurrentDir
}

## 输出是否有新的或失效的定时任务
## 注释  $1：新的或失效的任务清单文件路径，$2：新/失效
function Output_List_Add_Drop() {
    local List=$1
    local Type=$2
    if [ -s $List ]; then
        echo -e "\n检测到有$Type的定时任务：\n"
        cat $List
        echo ''
    fi
}

## 自动删除失效的脚本与定时任务
## 需要：
##      1.AutoDelCron/AutoDelOwnRepoCron/AutoDelOwnRawCron 设置为 true；
##      2.正常更新脚本，没有报错；
##      3.存在失效任务；
##      4.crontab.list存在并且不为空
## 注释  $1：失效任务清单文件路径，$2：task
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

## 自动增加 Scripts 仓库新的定时任务
## 需要：
##      1.AutoAddCron 设置为 true；
##      2.正常更新脚本，没有报错；
##      3.存在新任务；
##      4.crontab.list存在并且不为空
## 注释  $1：新任务清单文件路径
function Add_Cron_Scripts() {
    local ListAdd=$1
    if [[ ${AutoAddCron} == true ]] && [ -s $ListAdd ] && [ -s $ListCrontabUser ]; then
        echo -e "$WORKING 开始尝试自动添加 Scipts 仓库的定时任务...\n"
        local Detail=$(cat $ListAdd)
        for cron in $Detail; do
            ## 新增定时任务自动禁用
            if [[ $cron == jd_bean_sign ]]; then
                if [[ ${DisableNewCron} == true ]]; then
                    echo "# 4 0,9 * * * $TaskCmd $cron" >>$ListCrontabUser
                else
                    echo "4 0,9 * * * $TaskCmd $cron" >>$ListCrontabUser
                fi
            else
                if [[ ${DisableNewCron} == true ]]; then
                    cat $ListCronScripts | grep -E "\/$cron\." | perl -pe "s|(^.+)node */scripts/(j[drx]_\w+)\.js.+|\1$TaskCmd \2|; s|^|# |" >>$ListCrontabUser
                else
                    cat $ListCronScripts | grep -E "\/$cron\." | perl -pe "s|(^.+)node */scripts/(j[drx]_\w+)\.js.+|\1$TaskCmd \2|" >>$ListCrontabUser
                fi
            fi
        done
        ExitStatus=$?
    fi
}

## 自动增加自己额外的脚本的定时任务
## 需要：
##      1.AutoAddOwnRepoCron/AutoAddOwnRawCron 设置为 true；
##      2.正常更新脚本，没有报错；
##      3.存在新任务；
##      4.crontab.list存在并且不为空
## 注释  $1：新任务清单文件路径
function Add_Cron_Own() {
    local ListAdd=$1
    local ListCrontabOwnTmp=$LogTmpDir/crontab_own.list
    [ -f $ListCrontabOwnTmp ] && rm -f $ListCrontabOwnTmp
    if [ -s $ListAdd ] && [ -s $ListCrontabUser ]; then
        echo -e "$WORKING 开始添加 own 脚本的定时任务...\n"
        local Detail=$(cat $ListAdd)
        for FilePath in $Detail; do
            local FileName=$(echo ${FilePath} | awk -F "/" '{print $NF}')
            if [ -f ${FilePath} ]; then
                if [ ${FilePath} = "$RawDir/${FileName}" ]; then
                    ## 判断表达式所在行
                    local Tmp1=$(grep -E "cron|script-path|tag|\* \*|${FileName}" ${FilePath} | grep -Ev "^http.*:|^function " | head -1 | perl -pe '{s|[a-zA-Z\"\.\=\:\_]||g;}')
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
                    ## 如果未检测出定时则随机一个
                    if [ -z "${cron}" ]; then
                        echo "$((${RANDOM} % 60)) $((${RANDOM} % 24)) * * * $TaskCmd ${FilePath}" | sort -u | head -1 >>$ListCrontabOwnTmp
                    else
                        echo "$cron $TaskCmd ${FilePath}" | sort -u | head -1 >>$ListCrontabOwnTmp
                    fi
                else
                    ## 新增定时任务自动禁用
                    if [[ ${DisableNewOwnRepoCron} == true ]]; then
                        perl -ne "print if /.*([\d\*]*[\*-\/,\d]*[\d\*] ){4}[\d\*]*[\*-\/,\d]*[\d\*]( |,|\").*${FileName}/" ${FilePath} |
                            perl -pe "{s|[^\d\*]*(([\d\*]*[\*-\/,\d]*[\d\*] ){4,5}[\d\*]*[\*-\/,\d]*[\d\*])( \|,\|\").*/?${FileName}.*|\1 $TaskCmd ${FilePath}|g;s|  | |g; s|^[^ ]+ (([^ ]+ ){5}$TaskCmd ${FilePath})|\1|;}" |
                            sort -u | grep -Ev "^\*|^ \*" | head -1 | perl -pe '{s|^|# |}' >>$ListCrontabOwnTmp
                    else
                        perl -ne "print if /.*([\d\*]*[\*-\/,\d]*[\d\*] ){4}[\d\*]*[\*-\/,\d]*[\d\*]( |,|\").*${FileName}/" ${FilePath} |
                            perl -pe "{s|[^\d\*]*(([\d\*]*[\*-\/,\d]*[\d\*] ){4,5}[\d\*]*[\*-\/,\d]*[\d\*])( \|,\|\").*/?${FileName}.*|\1 $TaskCmd ${FilePath}|g;s|  | |g; s|^[^ ]+ (([^ ]+ ){5}$TaskCmd ${FilePath})|\1|;}" |
                            sort -u | grep -Ev "^\*|^ \*" | head -1 >>$ListCrontabOwnTmp
                    fi
                fi
            fi
        done
        perl -i -pe "s|(# 自用own任务结束.+)|$(cat $ListCrontabOwnTmp)\n\1|" $ListCrontabUser
        ExitStatus=$?
    fi
    [ -f $ListCrontabOwnTmp ] && rm -f $ListCrontabOwnTmp
}

## 向系统添加定时任务以及通知
## 注释  $1：写入crontab.list时的exit状态，$2：新增清单文件路径，$3：Scripts仓库脚本/Own仓库脚本/Raw脚本
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
            if [[ $ExitStatus -eq 0 ]]; then
                echo -e "\n$COMPLETE ${BLUE}${array_own_repo_dir[i]}${PLAIN} 仓库更新完成"
            else
                echo -e "\n$FAIL ${BLUE}${array_own_repo_dir[i]}${PLAIN} 仓库更新失败，请检查原因..."
            fi
        else
            Git_Clone ${array_own_repo_url[i]} ${array_own_repo_path[i]} ${array_own_repo_branch[i]}
            if [[ $ExitStatus -eq 0 ]]; then
                echo -e "\n$SUCCESS ${BLUE}${array_own_repo_dir[i]}${PLAIN} 克隆仓库成功"
            else
                echo -e "\n$FAIL ${BLUE}${array_own_repo_dir[i]}${PLAIN} 克隆仓库失败，请检查原因..."
            fi
        fi
    done
}

## 更新所有 Raw 脚本
function Update_RawFile() {
    local RawFileName RemoveMark FormatUrl ReformatUrl RepoBranch RepoUrl RepoPlatformUrl DownloadUrl
    for ((i = 0; i < ${#OwnRawFile[*]}; i++)); do
        ## 定义脚本名称
        RawFileName[$i]=$(echo ${OwnRawFile[i]} | awk -F "/" '{print $NF}')

        ## 判断脚本来源（ 托管仓库 or 普通网站 ）
        echo ${OwnRawFile[i]} | grep -Eq "github|gitee|gitlab"
        if [ $? -eq 0 ]; then
            ## 纠正链接地址（将传入的链接地址转换为对应代码托管仓库的raw原始文件链接地址）
            echo ${OwnRawFile[i]} | grep "\.com\/.*\/blob\/.*" -q
            if [ $? -eq 0 ]; then
                ## 纠正链接
                case $(echo ${OwnRawFile[i]} | grep -Eo "github|gitee|gitlab") in
                github)
                    echo ${OwnRawFile[i]} | grep "github\.com\/.*\/blob\/.*" -q
                    if [ $? -eq 0 ]; then
                        DownloadUrl=$(echo ${OwnRawFile[i]} | perl -pe "{s|github\.com/|raw\.githubusercontent\.com/|g; s|\/blob\/|\/|g}")
                    else
                        DownloadUrl=${OwnRawFile[i]}
                    fi
                    ;;
                gitee)
                    DownloadUrl=$(echo ${OwnRawFile[i]} | sed "s/\/blob\//\/raw\//g")
                    ;;
                gitlab)
                    DownloadUrl=${OwnRawFile[i]}
                    ;;
                esac
            else
                ## 原始链接
                DownloadUrl=${OwnRawFile[i]}
            fi

            ## 处理仓库地址
            FormatUrl=$(echo ${DownloadUrl} | perl -pe "{s|${RawFileName[$i]}||g;}" | awk -F '.com' '{print$NF}' | sed 's/.$//')
            ## 判断仓库平台
            case $(echo ${DownloadUrl} | grep -Eo "github|gitee|gitlab") in
            github)
                RepoPlatformUrl="https://github.com"
                RepoBranch=$(echo $FormatUrl | awk -F '/' '{print$4}')
                ReformatUrl=$(echo $FormatUrl | sed "s|$RepoBranch|tree/$RepoBranch|g")
                ## 定义脚本来源仓库地址链接
                RepoUrl="${RepoPlatformUrl}${ReformatUrl}"
                ;;
            gitee)
                RepoPlatformUrl="https://gitee.com"
                ReformatUrl=$(echo $FormatUrl | sed "s|/raw/|/tree/|g")
                ## 定义脚本来源仓库地址链接
                RepoUrl="${RepoPlatformUrl}${ReformatUrl}"
                ;;
            gitlab)
                ## 定义脚本来源仓库地址链接
                RepoUrl=${DownloadUrl}
                ;;
            esac
            ## 拉取脚本
            echo -e "\n$WORKING 开始从仓库 ${BLUE}${RepoUrl}${PLAIN} 下载 ${BLUE}${RawFileName[$i]}${PLAIN} 脚本..."
            wget -q --no-check-certificate -O "$RawDir/${RawFileName[$i]}.new" ${DownloadUrl} -T 20
        else
            ## 拉取脚本
            DownloadUrl=${OwnRawFile[i]}
            echo -e "\n$WORKING 开始从网站 ${BLUE}$(echo ${OwnRawFile[i]} | perl -pe "{s|\/${RawFileName[$i]}||g;}")${PLAIN} 下载 ${BLUE}${RawFileName[$i]}${PLAIN} 脚本..."
            wget -q --no-check-certificate -O "$RawDir/${RawFileName[$i]}.new" ${DownloadUrl} -T 20
        fi
        if [ $? -eq 0 ]; then
            mv -f "$RawDir/${RawFileName[$i]}.new" "$RawDir/${RawFileName[$i]}"
            echo -e "$COMPLETE ${RawFileName[$i]} 下载完成，脚本保存路径：$RawDir/${RawFileName[$i]}"
        else
            echo -e "$FAIL 下载 ${RawFileName[$i]} 失败，保留之前正常下载的版本...\n"
            [ -f "$RawDir/${RawFileName[$i]}.new" ] && rm -f "$RawDir/${RawFileName[$i]}.new"
        fi
    done
    for file in $(ls $RawDir | grep -Ev "${RawDirUtils}"); do
        RemoveMark="yes"
        for ((i = 0; i < ${#RawFileName[*]}; i++)); do
            if [[ $file == ${RawFileName[$i]} ]]; then
                RemoveMark="no"
                break
            fi
        done
        [[ $RemoveMark == yes ]] && rm -f $RawDir/$file 2>/dev/null
    done
}

## 更新项目源码
function Update_Shell() {
    local PanelDependOld PanelDependNew
    echo -e "-------------------------------------------------------------"
    ## 更新前先存储 package.json
    [ -f $PanelDir/package.json ] && PanelDependOld=$(cat $PanelDir/package.json)
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
        echo -e "\n$FAIL 源码更新失败，请检查原因...\n"
    fi
    ## 检测面板模块变动
    [ -f $PanelDir/package.json ] && PanelDependNew=$(cat $PanelDir/package.json)
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
    local ScriptsDependOld ScriptsDependNew
    echo -e "-------------------------------------------------------------"
    ## 更新前先存储 package.json
    [ -f $ScriptsDir/package.json ] && ScriptsDependOld=$(cat $ScriptsDir/package.json)
    ## 更新仓库
    if [ -d $ScriptsDir/.git ]; then
        Git_Pull $ScriptsDir $ScriptsBranch
    else
        Git_Clone $ScriptsUrl $ScriptsDir $ScriptsBranch
    fi
    ## 文件替换
    for file in ${ScriptsDirReplaceFiles}; do
        [ -f "$UtilsDir/$file" ] && cp -rf "$UtilsDir/$file" $ScriptsDir
    done
    if [[ $ExitStatus -eq 0 ]]; then
        ## 安装模块
        [ ! -d $ScriptsDir/node_modules ] && Npm_Install_Standard $ScriptsDir
        [ -f $ScriptsDir/package.json ] && ScriptsDependNew=$(cat $ScriptsDir/package.json)
        [[ "$ScriptsDependOld" != "$ScriptsDependNew" ]] && Npm_Install_Upgrade $ScriptsDir
        ## 检测定时清单
        if [[ ! -f $ScriptsDir/docker/crontab_list.sh ]]; then
            cp -rf $UtilsDir/crontab_list_public.sh $ScriptsDir/docker
        fi
        ## 比较定时任务
        Gen_ListTask
        Diff_Cron $ListTaskScripts $ListTaskUser $ListTaskAdd $ListTaskDrop

        ## 删除定时任务 & 通知
        if [[ ${AutoDelCron} == true ]] && [ -s $ListTaskDrop ]; then
            Output_List_Add_Drop $ListTaskDrop "失效"
            Del_Cron $ListTaskDrop $TaskCmd
        fi
        ## 新增定时任务 & 通知
        if [[ ${AutoAddCron} == true ]] && [ -s $ListTaskAdd ]; then
            Output_List_Add_Drop $ListTaskAdd "新"
            Add_Cron_Scripts $ListTaskAdd
            Add_Cron_Notify $ExitStatus $ListTaskAdd " Scripts 仓库脚本"
        fi

        echo -e "\n$COMPLETE Scripts 仓库更新完成\n"
    else
        echo -e "\n$FAIL Scripts 仓库更新失败，请检查原因...\n"
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
            Handle_Crontab
            Notice
            exit ## 终止退出
        fi
        ;;
    raw)
        EnableRepoUpdate="false"
        EnableRawUpdate="true"
        if [[ ${#OwnRawFile[*]} -eq 0 ]]; then
            echo -e "\n$ERROR 请先在 $FileConfUser 中配置好您的 Raw 脚本！\n"
            exit ## 终止退出
        fi
        Title $1
        ;;
    esac
    if [[ ${#array_own_scripts_path[*]} -gt 0 ]]; then
        echo -e "-------------------------------------------------------------"
        ## 更新仓库
        if [[ ${EnableRepoUpdate} == true ]]; then
            Update_OwnRepo
        fi
        if [[ ${EnableRawUpdate} == true ]]; then
            Update_RawFile
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
        wget -q --no-check-certificate $ExtraShellSyncUrl -O $FileExtra.new -T 20
        if [ $? -eq 0 ]; then
            mv -f "$FileExtra.new" "$FileExtra"
            echo -e "$COMPLETE 自定义脚本同步完成\n"
            sleep 1s
        else
            if [ -f $FileExtra ]; then
                echo -e "$FAIL 自定义脚本同步失败，保留之前的版本...\n"
            else
                echo -e "$FAIL 自定义脚本同步失败，请检查原因...\n"
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
function Update_Designated() {
    local InputContent=${1%*/}
    local AbsolutePath PwdTmp
    ## 判定输入的是绝对路径还是相对路径
    echo ${InputContent} | grep "^$RootDir/" -q
    if [ $? -eq 0 ]; then
        AbsolutePath=${InputContent}
    else
        echo ${InputContent} | grep "\.\./" -q
        if [ $? -eq 0 ]; then
            PwdTmp=$(pwd | perl -pe "{s|/$(pwd | awk -F '/' '{printf$NF}')||g;}")
            AbsolutePath=$(echo "${InputContent}" | perl -pe "{s|\.\./|${PwdTmp}/|;}")
        else
            if [[ $(pwd) == "/root" ]]; then
                AbsolutePath=$(echo "${InputContent}" | perl -pe "{s|\.\/||; s|^*|$RootDir/|;}")
            else
                AbsolutePath=$(echo "${InputContent}" | perl -pe "{s|\.\/||; s|^*|$(pwd)/|;}")
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
                echo -e "${YELLOW}注意：此更新模式下不会附带更新定时任务${PLAIN}\n"
            else
                echo -e "\n$FAIL ${AbsolutePath} 仓库更新失败，请检查原因...\n"
            fi
            ;;
        esac
    else
        echo -e "\n$ERROR 未检测到 ${BLUE}${AbsolutePath}${PLAIN} 路径下存在仓库，请重新确认！\n"
        exit ## 终止退出
    fi
}

## 处理 Crontab
function Handle_Crontab() {
    ## 规范 crontab.list 中的命令
    perl -i -pe "s|( ?&>/dev/null)+||g" $ListCrontabUser
    ## 同步定时清单
    Synchronize_Crontab
}

function Title() {
    local p=$1
    local RunMod
    case $1 in
    all)
        RunMod="    全 部    "
        ;;
    shell)
        RunMod="    源 码    "
        ;;
    scripts)
        RunMod=" Scripts 仓库"
        ;;
    own)
        RunMod=" 仅 Own 仓库 "
        ;;
    repo)
        RunMod=" 所 有 仓 库 "
        ;;
    raw)
        RunMod=" 仅 Raw 脚本 "
        ;;
    extra)
        RunMod="仅 Extra 脚本"
        ;;
    specify)
        RunMod=" 指 定 仓 库 "
        ;;
    esac
    echo -e "\n+----------------- 开 始 执 行 更 新 脚 本 -----------------+"
    echo -e ''
    echo -e "                系统时间：${BLUE}$(date "+%Y-%m-%d %T")${PLAIN}"
    echo -e ''
    echo -e "         更新模式：${BLUE}${RunMod}${PLAIN}     脚本根目录：${BLUE}$RootDir${PLAIN}"
    echo -e ''
    echo -e "    Scripts仓库目录：${BLUE}$ScriptsDir${PLAIN}     Own仓库目录：${BLUE}$OwnDir${PLAIN}"
    echo -e ''
}
function Notice() {
    echo -e "+----------------------- 郑 重 提 醒 -----------------------+

  本项目为非营利性的公益闭源项目，脚本免费使用仅供用于学习！

  项目资源禁止以任何形式发布到咸鱼等国内平台，否则后果自负！

  我们始终致力于打击使用本项目进行非法贩售行为的个人或组织！

  我们不会放纵某些行为，不保证不采取非常手段，请勿挑战底线！

+--------------- 请遵循本项目宗旨 - 低调使用 ---------------+\n"
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
        Handle_Crontab
        Notice
        exit ## 终止退出
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
            Update_Own "raw"
            ;;
        extra)
            if [[ $EnableExtraShellSync == true ]] || [[ $EnableExtraShell == true ]]; then
                Title $1
                ExtraShell
            else
                echo -e "\n$ERROR 请先在 $FileConfUser 中启用关于 Extra 自定义脚本的相关变量！\n"
            fi
            ;;
        *)
            echo $1 | grep "/" -q
            if [ $? -eq 0 ]; then
                Update_Designated $1
            else
                Output_Command_Error 1 ## 命令错误
                exit                   ## 终止退出
            fi
            ;;
        esac
        Handle_Crontab
        Notice
        exit ## 终止退出
        ;;
    *)
        Output_Command_Error 2 ## 命令过多
        ;;
    esac
}
Combin_Function "$@"
