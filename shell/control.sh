#!/bin/bash
## Author: SuperManito
## Modified: 2022-01-20

ShellDir=${WORK_DIR}/shell
. $ShellDir/share.sh

## 生成 pm2 list 日志清单，以此判断各服务状态
function PM2_List_All_Services() {
    pm2 list | sed "/─/d" | perl -pe "{s| ||g; s#│#|#g}" | sed "1d" >$FilePm2List
}

## 更新源码
function Update_Shell() {
    local CurrentDir=$(pwd)
    cd $RootDir
    git fetch --all >/dev/null 2>&1
    git pull >/dev/null 2>&1
    git reset --hard origin/$(git status | head -n 1 | awk -F ' ' '{print$NF}') >/dev/null 2>&1
    cd $CurrentDir
}

## 后台挂机功能
function Hang_Control() {
    local HangUpScripts=""
    local ScriptFiles ServiceName ScriptFormt LastRunTime ExitStatus
    [[ -z ${HangUpScripts} ]] && echo -e "\n目前没有挂机类的活动脚本哦~\n" && exit 0
    case $1 in
    ## 开启/重启服务
    up)
        for ScriptFiles in ${HangUpScripts}; do
            ServiceName=$(echo $ScriptFiles | perl -pe "{s|\.js||; s|\.py||; s|\.ts||}")
            ScriptFormt=$(echo $ScriptFiles | awk -F '\.' '{print$NF}')
            Import_Config $ServiceName
            Count_UserSum
            Combin_All
            PM2_List_All_Services
            cat $FilePm2List | awk -F '|' '{print$3}' | grep $ServiceName -wq
            ExitStatus=$?
            cd $ScriptsDir
            ## 判断脚本是否存在
            if [ ! -f "$ScriptsDir/$ScriptFiles" ]; then
                echo -e "\n$ERROR $ScriptFiles 脚本不存在！\n"
                exit ## 终止退出
            fi
            ## 删除原有
            pm2 stop $ServiceName >/dev/null 2>&1
            pm2 flush >/dev/null 2>&1
            pm2 delete $ScriptFiles >/dev/null 2>&1
            ## 启用
            case $ScriptFormt in
            js)
                pm2 start -a $ScriptFiles --watch "$ScriptFiles" --name="$ServiceName"
                ;;
            ts)
                pm2 start -a $ScriptFiles --interpreter /usr/bin/ts-node --watch "$ScriptFiles" --name="$ServiceName"
                ;;
            esac
            if [[ $ExitStatus -eq 0 ]]; then
                echo -e "\n$COMPLETE $ServiceName 已重启\n"
            else
                echo -e "\n$SUCCESS $ServiceName 启动成功\n"
            fi
        done
        ## 删除 PM2 进程日志清单
        [ -f $FilePm2List ] && rm -rf $FilePm2List
        ;;
    ## 关闭服务
    down)
        for ScriptFiles in ${HangUpScripts}; do
            ServiceName=$(echo $ScriptFiles | perl -pe "{s|\.js||; s|\.py||; s|\.ts||}")
            PM2_List_All_Services
            cat $FilePm2List | awk -F '|' '{print$3}' | grep $ServiceName -wq
            ExitStatus=$?
            if [[ $ExitStatus -eq 0 ]]; then
                pm2 stop $ServiceName
                LastRunTime=$(date --date "$(pm2 describe $ServiceName | grep "created at" | awk '{print $5}')")
                echo -e "\n$COMPLETE $ServiceName 已终止\n${BLUE}[上次启动]${PLAIN}: ${LastRunTime}\n"
            else
                echo -e "\n$ERROR $ServiceName 不存在！\n"
            fi
        done
        ## 删除 PM2 进程日志清单
        [ -f $FilePm2List ] && rm -rf $FilePm2List
        ;;
    ## 查看日志
    logs)
        echo -e "\n$TIPS 默认查看日志倒数 50 行的内容，日志会持续输出，Ctrl + C 退出查看，若想查看更多请执行 pm2 logs jd_cfd_loop --lines <行数> \n" && sleep 2
        pm2 logs jd_cfd_loop --lines 50
        ;;
    esac
}

## 控制面板和网页终端功能
function Panel_Control() {

    ## 安装网页终端
    function Install_TTYD() {
        [ ! -x /usr/bin/ttyd ] && apk --no-cache add -f ttyd
        ## 增加环境变量
        export PS1="\u@\h:\w# "
        pm2 start ttyd --name="ttyd" -- -p 7685 -t 'theme={"background": "#292A2B"}' -t cursorBlink=true -t lineHeight=1.3 -t fontSize=16 -t disableLeaveAlert=true bash
    }

    local ServiceStatus
    PM2_List_All_Services
    cat $FilePm2List | awk -F '|' '{print$3}' | grep "server" -wq
    local ExitStatusSERVER=$?
    cat $FilePm2List | awk -F '|' '{print$3}' | grep "ttyd" -wq
    local ExitStatusTTYD=$?
    case $1 in
    ## 开启/重启服务
    on)
        if [[ ${ExitStatusSERVER} -eq 0 ]]; then
            local ServiceStatus=$(cat $FilePm2List | grep "server" -w | awk -F '|' '{print$10}')
            case ${ServiceStatus} in
            online)
                pm2 restart server
                echo -e "\n$COMPLETE 控制面板已重启\n"
                ;;
            stopped)
                pm2 start server
                echo -e "\n$COMPLETE 控制面板已重新启动\n"
                ;;
            errored)
                echo -e "\n$WARN 检测到服务状态异常，开始尝试修复...\n"
                pm2 delete server
                Update_Shell
                cd $PanelDir
                npm install
                pm2 start ecosystem.config.js && sleep 3
                PM2_List_All_Services
                local ServiceNewStatus=$(cat $FilePm2List | grep "server" -w | awk -F '|' '{print$10}')
                if [[ ${ServiceNewStatus} == "online" ]]; then
                    echo -e "\n$SUCCESS 修复成功！\n"
                else
                    echo -e "\n$ERROR 修复失败，请检查原因后重试！\n"
                fi
                ;;
            esac
        else
            Update_Shell
            cd $PanelDir
            npm install
            pm2 start ecosystem.config.js && sleep 1
            PM2_List_All_Services
            local ServiceStatus=$(cat $FilePm2List | grep "server" -w | awk -F '|' '{print$10}')
            if [[ ${ServiceStatus} == "online" ]]; then
                echo -e "\n$SUCCESS 控制面板启动成功\n"
            else
                echo -e "\n$ERROR 控制面板启动失败，请检查原因后重试！\n"
            fi
        fi
        if [[ ${ExitStatusTTYD} -eq 0 ]]; then
            ServiceStatus=$(pm2 describe ttyd | grep status | awk '{print $4}')
            case ${ServiceStatus} in
            online)
                pm2 restart ttyd
                echo -e "\n$COMPLETE 网页终端已重启\n"
                ;;
            stopped)
                pm2 start ttyd
                echo -e "\n$COMPLETE 网页终端已重新启动\n"
                ;;
            errored)
                echo -e "\n$WARN 检测到服务状态异常，开始尝试修复...\n"
                pm2 delete ttyd
                Update_Shell
                cd $RootDir
                Install_TTYD && sleep 3
                PM2_List_All_Services
                local ServiceNewStatus=$(cat $FilePm2List | grep "ttyd" -w | awk -F '|' '{print$10}')
                if [[ ${ServiceNewStatus} == "online" ]]; then
                    echo -e "\n$SUCCESS 修复成功！\n"
                else
                    echo -e "\n$ERROR 修复失败，请检查原因后重试！\n"
                fi
                ;;
            esac
        else
            Update_Shell
            cd $RootDir
            Install_TTYD && sleep 1
            PM2_List_All_Services
            local ServiceStatus=$(cat $FilePm2List | grep "ttyd" -w | awk -F '|' '{print$10}')
            if [[ ${ServiceStatus} == "online" ]]; then
                echo -e "\n$SUCCESS 网页终端启动成功\n"
            else
                echo -e "\n$ERROR 网页终端启动失败，请检查原因后重试！\n"
            fi
        fi
        ;;
    ## 关闭服务
    off)
        if [[ ${ExitStatusSERVER} -eq 0 ]]; then
            pm2 stop server >/dev/null 2>&1
            if [[ ${ExitStatusTTYD} -eq 0 ]]; then
                pm2 stop ttyd >/dev/null 2>&1
            fi
            pm2 list
            echo -e "\n$COMPLETE 控制面板和网页终端已关闭\n"
        else
            echo -e "\n$ERROR 服务不存在！\n"
        fi
        ;;
    ## 登录信息
    info)
        if [ ! -f $FileAuth ]; then
            cp -f $FileAuthSample $FileAuth
        fi
        echo ''
        jq '.' $FileAuth | perl -pe '{s|\"user\"|[用户名]|g; s|\"password\"|[密码]|g; s|\"openApiToken\"|[openApiToken]|g; s|\"lastLoginInfo\"|\n    最后一次登录信息|g; s|\"loginIp\"|[ IP 地址]|g; s|\"loginAddress\"|[地理位置]|g; s|\"loginTime\"|[登录时间]|g; s|\"authErrorCount\"|[认证失败次数]|g; s|[{},"]||g;}'
        echo -e '\n'
        ;;
    ## 重置密码
    respwd)
        cp -f $FileAuthSample $FileAuth
        echo -e "\n$COMPLETE 已重置控制面板的用户名和登录密码\n\n[用户名]： useradmin\n[密  码]： supermanito\n"
        ;;
    esac
    ## 删除 PM2 进程日志清单
    [ -f $FilePm2List ] && rm -rf $FilePm2List
}

## Telegram Bot 功能
function Bot_Control() {

    ## 安装 Telegram Bot
    function Install_Bot() {
        ## 安装依赖
        echo -e "\n$WORKING 开始安装依赖\n"
        apk --no-cache add -f python3-dev py3-pip zlib-dev gcc jpeg-dev musl-dev freetype-dev
        if [ $? -eq 0 ]; then
            echo -e "\n$SUCCESS 依赖安装完成\n"
        else
            echo -e "\n$ERROR 依赖安装失败，请检查原因后重试！\n"
        fi
        ## 拉取组件
        if [ -d $BotRepoDir/.git ]; then
            cd $BotRepoDir
            echo -e "$WORKING 开始更新仓库\n"
            if [[ ${ENABLE_SCRIPTS_PROXY} == false ]]; then
                git remote set-url origin ${BotRepoGitUrl} >/dev/null
            else
                git remote set-url origin $(echo ${BotRepoGitUrl} | perl -pe '{s|github\.com|github\.com\.cnpmjs\.org|g}') >/dev/null
            fi
            git reset --hard origin/main >/dev/null
            git fetch --all
            local ExitStatusBot=$?
            git reset --hard origin/main
            git pull
        else
            echo -e "$WORKING 开始克隆仓库...\n"
            rm -rf $BotRepoDir
            if [[ ${ENABLE_SCRIPTS_PROXY} == false ]]; then
                git clone -b main ${BotRepoGitUrl} $BotRepoDir
            else
                git clone -b main $(echo ${BotRepoGitUrl} | perl -pe '{s|github\.com|github\.com\.cnpmjs\.org|g}') $BotRepoDir
            fi
            local ExitStatusBot=$?
        fi
        if [[ ${ExitStatusBot} -eq 0 ]]; then
            echo -e "\n$SUCCESS 仓库更新完成\n"
            sed -i "s/script: \"python\"/script: \"python3\"/g" $BotRepoDir/jbot/ecosystem.config.js
        else
            echo -e "\n$ERROR 仓库克隆失败，请检查原因后重试！\n"
            exit ## 终止退出
        fi

        if [ ! -s $ConfigDir/bot.json ]; then
            cp -fv $SampleDir/bot.json $ConfigDir/bot.json
        fi
        ## 安装模块
        echo -e "$WORKING 开始安装模块...\n"
        cp -rf $BotRepoDir/jbot $RootDir
        cd $RootDir/jbot
        pip3 config set global.index-url https://mirrors.aliyun.com/pypi/simple/
        pip3 --default-timeout=100 install -r requirements.txt --no-cache-dir
        pip3 install aiohttp
        if [[ $? -eq 0 ]]; then
            echo -e "\n$SUCCESS 模块安装完成\n"
        else
            echo -e "\n$ERROR 模块安装失败，请检查原因后重试！\n"
        fi
    }

    case ${ARCH} in
    armv7l | armv6l)
        echo -e "\n$ERROR 宿主机的处理器架构不支持使用此功能，建议更换运行环境！\n"
        exit ## 终止退出
        ;;
    *)
        if [[ -z $(grep -E "123456789" $ConfigDir/bot.json) ]]; then
            PM2_List_All_Services
            cat $FilePm2List | awk -F '|' '{print$3}' | grep "jbot" -wq
            local ExitStatusJbot=$?
            case $1 in
            ## 开启/重启服务
            start)
                ## 删除日志
                rm -rf $BotLogDir/up.log
                if [[ ${ExitStatusJbot} -eq 0 ]]; then
                    local ServiceStatus=$(cat $FilePm2List | grep "jbot" -w | awk -F '|' '{print$10}')
                    case ${ServiceStatus} in
                    online)
                        pm2 delete jbot >/dev/null 2>&1
                        cd $BotDir && pm2 start ecosystem.config.js && sleep 1
                        PM2_List_All_Services
                        local ServiceNewStatus=$(cat $FilePm2List | grep "jbot" -w | awk -F '|' '{print$10}')
                        if [[ ${ServiceNewStatus} == "online" ]]; then
                            echo -e "\n$COMPLETE Telegram Bot 已重启\n"
                        else
                            echo -e "\n$ERROR 重启失败，请检查原因后重试！\n"
                        fi
                        ;;
                    stopped)
                        pm2 start jbot
                        PM2_List_All_Services
                        local ServiceNewStatus=$(cat $FilePm2List | grep "jbot" -w | awk -F '|' '{print$10}')
                        if [[ ${ServiceNewStatus} == "online" ]]; then
                            echo -e "\n$COMPLETE Telegram Bot 已重新启动\n"
                        else
                            echo -e "\n$ERROR 启动失败，请检查原因后重试！\n"
                        fi
                        ;;
                    errored)
                        echo -e "\n$WARN 检测到服务状态异常，开始尝试修复...\n"
                        pm2 delete jbot >/dev/null 2>&1
                        rm -rf $BotRepoDir $BotDir $RootDir/bot.session
                        Install_Bot
                        cp -rf $BotRepoDir/jbot $RootDir
                        [ ! -x /usr/local/bin/jcsv ] && ln -sf $UtilsDir/jcsv.sh /usr/local/bin/jcsv
                        cd $BotDir && pm2 start ecosystem.config.js && sleep 1
                        PM2_List_All_Services
                        local ServiceNewStatus=$(cat $FilePm2List | grep "jbot" -w | awk -F '|' '{print$10}')
                        if [[ ${ServiceNewStatus} == "online" ]]; then
                            echo -e "\n$SUCCESS 修复成功！\n"
                        else
                            echo -e "\n$ERROR 修复失败，请检查原因后重试！\n"
                        fi
                        ;;
                    esac
                else
                    rm -rf $BotRepoDir
                    Install_Bot
                    cp -rf $BotRepoDir/jbot $RootDir
                    [ ! -x /usr/local/bin/jcsv ] && ln -sf $UtilsDir/jcsv.sh /usr/local/bin/jcsv
                    cd $BotDir && pm2 start ecosystem.config.js && sleep 1
                    local ServiceStatus=$(pm2 describe jbot | grep status | awk '{print $4}')
                    if [[ ${ServiceStatus} == "online" ]]; then
                        echo -e "\n$SUCCESS Telegram Bot 启动成功\n"
                    else
                        echo -e "\n$ERROR Telegram Bot 启动失败，请检查原因后重试！\n"
                    fi
                fi
                ;;
                ## 关闭服务
            stop)
                if [[ ${ExitStatusJbot} -eq 0 ]]; then
                    pm2 stop jbot >/dev/null 2>&1
                    pm2 list
                    echo -e "\n$COMPLETE Telegram Bot 已停止\n"
                else
                    echo -e "\n$ERROR 服务不存在！\n"
                fi
                ;;
                ## 查看日志
            logs)
                if [[ -f $BotLogDir/run.log ]]; then
                    cat $BotLogDir/run.log | tail -n 100
                else
                    echo -e "\n$ERROR 日志不存在！\n"
                fi
                ;;
            esac
            ## 删除 PM2 进程日志清单
            [ -f $FilePm2List ] && rm -rf $FilePm2List
        else
            echo -e "\n$ERROR 请先在 $FileConfUser 中配置好您的 Bot ！\n"
            exit ## 终止退出
        fi
        ;;
    esac
}

## 检测项目配置文件完整性
function Check_Files() {
    echo ''
    Make_Dir $LogDir
    if [ -s $ListCrontabUser ]; then
        crontab $ListCrontabUser
    else
        cp -fv $ListCrontabSample $ListCrontabUser
        echo -e "检测到 $ConfigDir 配置文件目录下不存在 crontab.list 或存在但且为空，已生成...\n"
        crontab $ListCrontabUser
    fi
    if [ ! -s $FileConfUser ]; then
        cp -fv $FileConfSample $FileConfUser
        echo -e "检测到 $ConfigDir 配置文件目录下不存在 config.sh 配置文件，已生成...\n"
    fi
    JsonFiles="auth.json bot.json account.json"
    for file in $JsonFiles; do
        if [ ! -s "$ConfigDir/$file" ]; then
            cp -fv "$SampleDir/$file" "$ConfigDir/$file"
            echo -e "检测到 $ConfigDir 配置文件目录下不存在 $file ，已生成...\n"
        fi
    done
}

## 列出各服务状态
function Server_Status() {
    local Services ServiceName StatusJudge Status CreateTime CPUOccupancy MemoryOccupancy RunTime
    local SERVICE_ONLINE="${GREEN}正在运行${PLAIN}"
    local SERVICE_STOPPED="${YELLOW}未在运行${PLAIN}"
    local SERVICE_ERRORED="${RED}服务异常${PLAIN}"
    echo ''
    pm2 list
    echo ''
    PM2_List_All_Services
    Services="server ttyd jd_cfd_loop jbot"
    for Name in ${Services}; do
        ServiceName=''
        StatusJudge=''
        Status=''
        CreateTime=''
        CPUOccupancy=''
        MemoryOccupancy=''
        RunTime=''
        cat $FilePm2List | awk -F '|' '{print$3}' | grep ${Name} -wq
        if [ $? -eq 0 ]; then
            StatusJudge=$(cat $FilePm2List | grep ${Name} | awk -F '|' '{print $10}')
            case $StatusJudge in
            online)
                Status=$SERVICE_ONLINE
                ;;
            stopped)
                Status=$SERVICE_STOPPED
                ;;
            errored)
                Status=$SERVICE_ERRORED
                ;;
            esac
            CreateTime="${BLUE}$(date --date "$(pm2 describe ${Name} | grep "created at" | awk '{print $5}')")${PLAIN}"
            CPUOccupancy="${BLUE}$(cat $FilePm2List | grep ${Name} | awk -F '|' '{print $11}')${PLAIN}"
            MemoryOccupancy="${BLUE}$(cat $FilePm2List | grep ${Name} | awk -F '|' '{print $12}')${PLAIN}"
            RunTime="${BLUE}$(cat $FilePm2List | grep ${Name} | awk -F '|' '{print $8}')${PLAIN}"
        else
            Status=$SERVICE_STOPPED
            CreateTime="${BLUE}          No Data           ${PLAIN}"
            CPUOccupancy="${BLUE}No Data${PLAIN}"
            MemoryOccupancy="${BLUE}No Data${PLAIN}"
            RunTime="${BLUE}No Data${PLAIN}"
        fi
        case ${Name} in
        server)
            ServiceName="[控ㅤ制ㅤ面ㅤ板]"
            ;;
        ttyd)
            ServiceName="[网ㅤ页ㅤ终ㅤ端]"
            ;;
        jd_cfd_loop)
            ServiceName="[挂ㅤ机ㅤ程ㅤ序]"
            ;;
        jbot)
            ServiceName="[ Telegram Bot ]"
            ;;
        esac
        echo -e " $ServiceName：$Status       [创建时间]：$CreateTime       [资源占用]：$CPUOccupancy / $MemoryOccupancy / $RunTime"
    done
    ## 删除 PM2 进程日志清单
    [ -f $FilePm2List ] && rm -rf $FilePm2List
    echo ''
}

## 处理环境软件包和模块
function Environment_Deployment() {
    case $1 in
    install)
        case ${ARCH} in
        armv7l | armv6l)
            echo -e "\n[${BLUE}*${PLAIN}] 开始安装常用模块...\n"
            ;;
        *)
            echo -e "\n[${BLUE}*${PLAIN}] 开始安装常用模块以及 Python & TypeScript 运行环境...\n"
            ;;
        esac
        echo -e "${GREEN}Tips:${PLAIN} 忽略 ${YELLOW}[WARN]${PLAIN} 警告类输出内容，如有 ${RED}[ERR!]${PLAIN} 类报错，90% 都是由网络原因所导致的，自行解读日志。\n"
        npm install -g npm npm-install-peers
        case ${ARCH} in
        armv7l | armv6l)
            npm install -g date-fns axios require request fs crypto crypto-js dotenv png-js ws@7.4.3
            ;;
        *)
            apk --no-cache add -f python3 py3-pip sudo build-base pkgconfig pixman-dev cairo-dev pango-dev
            pip3 config set global.index-url https://mirrors.aliyun.com/pypi/simple/
            pip3 install --upgrade pip
            pip3 install requests
            npm install -g got@11.8.3 date-fns axios require request fs crypto crypto-js dotenv png-js ws@7.4.3 ts-node typescript @types/node ts-md5 tslib jsdom prettytable js-base64
            ;;
        esac
        echo -e "\n$SUCCESS 安装完成\n"
        ;;
    repairs)
        echo -e "\n$WORKING 开始暴力修复 npm ...\n"
        apk del -f nodejs-lts npm
        apk --no-cache add -f nodejs-lts npm
        echo -e "\n$SUCCESS 修复完成\n"
        ;;
    esac
}

## 判定命令
case $# in
0)
    Help
    ;;
1)
    Output_Command_Error 1 ## 命令错误
    ;;
2)
    case $2 in
    on | off)
        case $1 in
        panel)
            Panel_Control $2
            ;;
        *)
            Output_Command_Error 1 ## 命令错误
            ;;
        esac
        ;;
    up | down)
        case $1 in
        hang)
            Hang_Control $2
            ;;
        *)
            Output_Command_Error 1 ## 命令错误
            ;;
        esac
        ;;
    start | stop)
        case $1 in
        jbot)
            Bot_Control $2
            ;;
        *)
            Output_Command_Error 1 ## 命令错误
            ;;
        esac
        ;;
    logs)
        case $1 in
        hang)
            Hang_Control $2
            ;;
        jbot)
            Bot_Control $2
            ;;
        *)
            Output_Command_Error 1 ## 命令错误
            ;;
        esac
        ;;
    status)
        case $1 in
        server)
            Server_Status
            ;;
        *)
            Output_Command_Error 1 ## 命令错误
            ;;
        esac
        ;;
    info | respwd)
        case $1 in
        panel)
            Panel_Control $2
            ;;
        *)
            Output_Command_Error 1 ## 命令错误
            ;;
        esac
        ;;
    install | repairs)
        case $1 in
        env)
            Environment_Deployment $2
            ;;
        *)
            Output_Command_Error 1 ## 命令错误
            ;;
        esac
        ;;
    files)
        case $1 in
        check)
            Check_Files
            ;;
        *)
            Output_Command_Error 1 ## 命令错误
            ;;
        esac
        ;;
    *)
        Output_Command_Error 1 ## 命令错误
        ;;
    esac
    ;;
*)
    Output_Command_Error 2 ## 命令过多
    ;;
esac
