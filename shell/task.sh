#!/bin/bash
## Author: SuperManito
## Modified: 2022-02-14

ShellDir=${WORK_DIR}/shell
. $ShellDir/share.sh

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

        ## 判定变量是否存在否则报错终止退出
        if [ -n "${FileName}" ] && [ -n "${FileDir}" ]; then
            ## 添加依赖文件
            [[ ${FileFormat} == "JavaScript" ]] && Check_Moudules $FileDir
            ## 定义日志路径
            if [[ $(echo ${AbsolutePath} | awk -F '/' '{print$3}') == "own" ]]; then
                LogPath="$LogDir/$(echo ${AbsolutePath} | awk -F '/' '{print$4}')_${FileName}"
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
    Make_Dir $LogTmpDir
    [ ! -f $ListOwnScripts ] && touch $ListOwnScripts
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
    [ ! -f $ListOwnScripts ] && touch $ListOwnScripts
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
        [ ! -f $ListAdd ] && touch $ListAdd
        [ ! -f $ListDrop ] && touch $ListDrop
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
                        local Cron=$(echo "${Tmp1}" | awk '{if($1~/^[0-9]{1,2}/) print $1,$2,$3,$4,$5; else if ($1~/^[*]/) print $2,$3,$4,$5,$6}')
                    else
                        local Cron=$(echo "${Tmp1}" | perl -pe "{s|${Tmp2}${Tmp3}|${Tmp3}|g;}" | awk '{if($1~/^[0-9]{1,2}/) print $1,$2,$3,$4,$5; else if ($1~/^[*]/) print $2,$3,$4,$5,$6}')
                    fi
                    ## 如果未检测出定时则随机一个
                    if [ -z "${Cron}" ]; then
                        echo "$((${RANDOM} % 60)) $((${RANDOM} % 24)) * * * $TaskCmd ${FilePath}" | sort -u | head -1 >>$ListCrontabOwnTmp
                    else
                        echo "$Cron $TaskCmd ${FilePath}" | sort -u | head -1 >>$ListCrontabOwnTmp
                    fi
                else
                    local Cron=$(perl -ne "print if /.*([\d\*]*[\*-\/,\d]*[\d\*] ){4}[\d\*]*[\*-\/,\d]*[\d\*]( |,|\").*${FileName}/" ${FilePath} | perl -pe "{s|[^\d\*]*(([\d\*]*[\*-\/,\d]*[\d\*] ){4,5}[\d\*]*[\*-\/,\d]*[\d\*])( \|,\|\").*/?${FileName}.*|\1 $TaskCmd ${FilePath}|g;s|  | |g; s|^[^ ]+ (([^ ]+ ){5}$TaskCmd ${FilePath})|\1|;}" | sort -u | grep -Ev "^\*|^ \*" | head -1)

                    ## 新增定时任务自动禁用
                    if [[ ${DisableNewOwnRepoCron} == true ]]; then
                        echo "${Cron}" | perl -pe '{s|^|# |}' >>$ListCrontabOwnTmp
                    else
                        grep -E " $TaskCmd $OwnDir/" $ListCrontabUser | grep -Ev "^#" | awk -F '/' '{print$NF}' | grep "${FileName}" -q
                        if [ $? -eq 0 ]; then
                            ## 重复定时任务自动禁用
                            if [[ ${DisableDuplicateOwnRepoCron} == true ]]; then
                                echo "${Cron}" | perl -pe '{s|^|# |}' >>$ListCrontabOwnTmp
                            else
                                echo "${Cron}" >>$ListCrontabOwnTmp
                            fi
                        else
                            echo "${Cron}" >>$ListCrontabOwnTmp
                        fi
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
    ## 更新仓库
    if [ -d $ScriptsDir/.git ]; then
        echo -e "-------------------------------------------------------------"
        ## 更新前先存储 package.json
        [ -f $ScriptsDir/package.json ] && ScriptsDependOld=$(cat $ScriptsDir/package.json)
        ## 更新仓库
        local CurrentDir=$(pwd)
        cd $ScriptsDir
        echo -e "\n$WORKING 开始更新主要仓库：${BLUE}$ScriptsDir${PLAIN}\n"
        git fetch --all
        ExitStatus=$?
        git pull
        git reset --hard origin/$(git status | head -n 1 | awk -F ' ' '{print$NF}')
        cd $CurrentDir
        ## 推送通知
        Apply_SendNotify $ScriptsDir
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
                cp -rf $SampleDir/crontab_list_public.sh $ScriptsDir/docker/crontab_list.sh
                echo -e "\n$WARN 为检测到定时清单，已启用内置模版\n"
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
    fi
}

## 更新 Own Repo 仓库和 Own RawFile 脚本
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
            echo -e "\n$ERROR 请先在 $FileConfUser 中配置好您的 Own RawFile 脚本！\n"
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
            grep -v "$RawDir/" $ListOwnAdd 2>/dev/null >$ListOwnRepoAdd
            grep -v "$RawDir/" $ListOwnDrop 2>/dev/null >$ListOwnRepoDrop

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
            grep "$RawDir/" $ListOwnAdd 2>/dev/null >$ListOwnRawAdd
            grep "$RawDir/" $ListOwnDrop 2>/dev/null >$ListOwnRawDrop

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
            Output_Command_Error 1 ## 命令错误
            exit                   ## 终止退出
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
                    read -p "$(echo -e "\n${BOLD}└ 检测到该变量已禁用，是否启用? [Y/n] ${PLAIN}")" InputA
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
                    read -p "$(echo -e "\n${BOLD}└ 检测到该变量已启用，是否禁用? [Y/n] ${PLAIN}")" InputB
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
                    echo -e "\n$COMPLETE 该环境变量已经禁用，不执行任何操作\n"
                    exit ## 终止退出
                    ;;
                *)
                    Output_Command_Error 1 ## 命令错误
                    exit                   ## 终止退出
                    ;;
                esac
            else
                case ${Mod} in
                enable)
                    echo -e "\n$COMPLETE 该环境变量已经启用，不执行任何操作\n"
                    exit ## 终止退出
                    ;;
                disable)
                    sed -i "s/.*export ${VariableTmp}=/# export ${VariableTmp}=/g" $FileConfUser
                    ;;
                *)
                    Output_Command_Error 1 ## 命令错误
                    exit                   ## 终止退出
                    ;;
                esac
            fi
            ;;
        esac

        ## 前后对比
        NewContent=$(grep ".*export ${VariableTmp}=" $FileConfUser | head -1)
        echo -e "\n${RED}-${PLAIN} \033[41;37m${OldContent}${PLAIN}\n${GREEN}+${PLAIN} \033[42;30m${NewContent}${PLAIN}"
        ## 结果判定
        if [[ ${OldContent} = ${NewContent} ]]; then
            echo -e "\n$FAIL 环境变量修改失败\n"
        else
            case ${Mod} in
            enable)
                echo -e "\n$COMPLETE 环境变量已启用\n"
                ;;
            disable)
                echo -e "\n$COMPLETE 环境变量已禁用\n"
                ;;
            esac
        fi
    }

    ## 修改变量
    function ModifyEnv() {
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
                    read -p "$(echo -e "\n${BOLD}└ 检测到该变量存在备注内容，是否修改? [Y/n] ${PLAIN}")" InputB
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
        3)
            local ValueTmp=$(echo $2 | perl -pe '{s|[\.\/\[\]\!\@\#\$\%\^\&\*\(\)]|\\$&|g;}')
            Remarks=" # $3"
            ;;
        *)
            Output_Command_Error 1 ## 命令错误
            exit                   ## 终止退出
            ;;
        esac

        ## 修改
        sed -i "s/\(export ${VariableTmp}=\).*/\1\"${ValueTmp}\"${Remarks}/" $FileConfUser

        ## 前后对比
        NewContent=$(grep ".*export ${VariableTmp}=" $FileConfUser | head -1)
        echo -e "\n${RED}-${PLAIN} \033[41;37m${OldContent}${PLAIN}\n${GREEN}+${PLAIN} \033[42;30m${NewContent}${PLAIN}"
        ## 结果判定
        grep ".*export ${VariableTmp}=\"${ValueTmp}\"${Remarks}" -q $FileConfUser
        local ExitStatus=$?
        if [[ $ExitStatus -eq 0 ]]; then
            echo -e "\n$COMPLETE 环境变量修改完毕\n"
        else
            echo -e "\n$FAIL 环境变量修改失败\n"
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
                echo -e "\n${BLUE}检测到已存在该环境变量：${PLAIN}\n$(grep -n ".*export ${Variable}=" $FileConfUser | perl -pe '{s|^|第|g; s|:|行：|g;}')"
                while true; do
                    read -p "$(echo -e "\n${BOLD}└ 是否继续修改? [Y/n] ${PLAIN}")" Input1
                    [ -z ${Input1} ] && Input1=Y
                    case ${Input1} in
                    [Yy] | [Yy][Ee][Ss])
                        ModifyEnv "${Variable}"
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
                    read -p "$(echo -e "\n${BOLD}└ 是否添加备注? [Y/n] ${PLAIN}")" Input2
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
                echo -e "\n${GREEN}+${PLAIN} \033[42;30m${FullContent}${PLAIN}"
                echo -e "\n$COMPLETE 环境变量已添加\n"
            fi
            ;;
        3 | 4)
            Variable=$2
            Value=$3
            ## 检测是否已存在该变量
            grep ".*export ${Variable}=" -q $FileConfUser
            local ExitStatus=$?
            if [[ $ExitStatus -eq 0 ]]; then
                echo -e "\n${BLUE}检测到已存在该环境变量：${PLAIN}\n$(grep -n ".*export ${Variable}=" $FileConfUser | perl -pe '{s|^|第|g; s|:|行：|g;}')"
                echo -e "\n$ERROR 环境变量 ${BLUE}${Variable}${PLAIN} 已经存在，请直接修改！"
                case $# in
                3)
                    echo -e "\n$EXAMPLE ${BLUE}$TaskCmd env edit ${Variable} \"${Value}\"${PLAIN}\n"
                    ;;
                4)
                    echo -e "\n$EXAMPLE ${BLUE}$TaskCmd env edit ${Variable} \"${Value}\" \"$4\"${PLAIN}\n"
                    ;;
                esac
            else
                case $# in
                3)
                    FullContent="export ${Variable}=\"${Value}\""
                    ;;
                4)
                    FullContent="export ${Variable}=\"${Value}\" # $4"
                    ;;
                esac
                sed -i "9 i ${FullContent}" $FileConfUser
                echo -e "\n${GREEN}+${PLAIN} \033[42;30m${FullContent}${PLAIN}"
                echo -e "\n$COMPLETE 环境变量已添加\n"
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
                    read -p "$(echo -e "\n${BOLD}└ 是否确认删除? [Y/n] ${PLAIN}")" Input1
                    [ -z ${Input1} ] && Input1=Y
                    case ${Input1} in
                    [Yy] | [Yy][Ee][Ss])
                        FullContent="$(grep ".*export ${Variable}=" $FileConfUser)"
                        sed -i "/export ${Variable}=/d" $FileConfUser
                        if [[ ${VariableNums} -gt "1" ]]; then
                            echo -e "\n$(echo -e "${FullContent}" | perl -pe '{s|^|\033[41;37m|g; s|$|\033[0m|g;}' | sed '$d')"
                        elif [[ ${VariableNums} -eq "1" ]]; then
                            echo -e "\n${RED}-${PLAIN} \033[41;37m${FullContent}${PLAIN}"
                        fi
                        echo -e "\n$COMPLETE 环境变量已删除\n"
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
                echo -e "\n$ERROR 在配置文件中未检测到 ${BLUE}${Variable}${PLAIN} 环境变量，请重新确认！\n"
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
                    echo -e "\n${RED}-${PLAIN} \033[41;37m${FullContent}${PLAIN}"
                fi
                echo -e "\n$COMPLETE 环境变量 ${BLUE}${Variable}${PLAIN} 已删除\n"
            else
                echo -e "\n$ERROR 在配置文件中未检测到 ${BLUE}${Variable}${PLAIN} 环境变量，请重新确认！\n"
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
                        ModifyEnv "${Variable}"
                        break
                        ;;
                    esac
                    echo -e "\n$ERROR 输入错误！"
                done
            else
                echo -e "\n$ERROR 在配置文件中未检测到 ${BLUE}${Variable}${PLAIN} 环境变量，请重新确认！\n"
            fi
            ;;
        3 | 4)
            case $2 in
            enable | disable)
                Variable=$3
                ;;
            *)
                Variable=$2
                Value=$3
                ;;
            esac
            grep ".*export.*=" $FileConfUser | grep ".*export ${Variable}=" -q
            local ExitStatus=$?
            if [[ $ExitStatus -eq 0 ]]; then
                case $2 in
                enable | disable)
                    ControlEnv "$2" "${Variable}"
                    ;;
                *)
                    case $# in
                    3)
                        ModifyEnv "${Variable}" "${Value}"
                        ;;
                    4)
                        ModifyEnv "${Variable}" "${Value}" "$4"
                        ;;
                    esac
                    ;;
                esac
            else
                case $2 in
                enable | disable)
                    echo -e "\n$ERROR 在配置文件中未检测到 ${BLUE}${Variable}${PLAIN} 环境变量，请重新确认！\n"
                    ;;
                *)
                    echo -e "\n$ERROR 在配置文件中未检测到 ${BLUE}${Variable}${PLAIN} 环境变量，请先添加！"
                    case $# in
                    3)
                        echo -e "\n$EXAMPLE ${BLUE}$TaskCmd env add ${Variable} \"${Value}\"${PLAIN}\n"
                        ;;
                    4)
                        echo -e "\n$EXAMPLE ${BLUE}$TaskCmd env add ${Variable} \"${Value}\" \"$4\"${PLAIN}\n"
                        ;;
                    esac
                    ;;
                esac
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
            if [ -d $ScriptsDir/.git ]; then
                Title $1
                Update_Scripts
            else
                echo -e "\n$ERROR 请先配置 Sciprts 主要仓库！\n"
            fi
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
