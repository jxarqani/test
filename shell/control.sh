#!/bin/bash
## Author: SuperManito
## Modified: 2022-08-21

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

## 控制面板和网页终端功能
function Panel_Control() {

    ## 安装网页终端
    function Install_TTYD() {
        [ ! -x /usr/bin/ttyd ] && apk --no-cache add -f ttyd
        ## 增加环境变量
        export PS1="\[\e[32;1m\]@Helloworld Cli\[\e[37;1m\] ➜\[\e[34;1m\]  \w\[\e[0m\] \\$ "
        pm2 start ttyd --name "web_terminal" --log-date-format "YYYY-MM-DD HH:mm:ss" -- -p 7685 -t 'theme={"background": "#292A2B"}' -t cursorBlink=true -t fontSize=16 -t disableLeaveAlert=true bash
    }

    local ServiceStatus
    PM2_List_All_Services
    cat $FilePm2List | awk -F '|' '{print$3}' | grep "web_server" -wq
    local ExitStatusSERVER=$?
    cat $FilePm2List | awk -F '|' '{print$3}' | grep "web_terminal" -wq
    local ExitStatusTTYD=$?
    case $1 in
    ## 开启/重启服务
    on)
        ## 删除日志
        rm -rf /root/.pm2/logs/web_server-*.log /root/.pm2/logs/web_terminal-*.log
        if [[ ${ExitStatusSERVER} -eq 0 ]]; then
            local ServiceStatus=$(cat $FilePm2List | grep "web_server" -w | awk -F '|' '{print$10}')
            case ${ServiceStatus} in
            online)
                pm2 restart web_server
                echo -e "\n$COMPLETE 控制面板已重启\n"
                ;;
            stopped)
                pm2 start web_server
                echo -e "\n$COMPLETE 控制面板已重新启动\n"
                ;;
            errored)
                echo -e "\n$WARN 检测到服务状态异常，开始尝试修复...\n"
                pm2 delete web_server
                Update_Shell
                cd $PanelDir
                npm install
                pm2 start ecosystem.config.js && sleep 3
                PM2_List_All_Services
                local ServiceNewStatus=$(cat $FilePm2List | grep "web_server" -w | awk -F '|' '{print$10}')
                if [[ ${ServiceNewStatus} == "online" ]]; then
                    echo -e "\n$SUCCESS 已修复错误，服务恢复正常运行！\n"
                else
                    echo -e "\n$FAIL 未能自动修复错误，请检查原因后重试！\n"
                fi
                ;;
            esac
        else
            Update_Shell
            cd $PanelDir
            npm install
            pm2 start ecosystem.config.js && sleep 1
            PM2_List_All_Services
            local ServiceStatus=$(cat $FilePm2List | grep "web_server" -w | awk -F '|' '{print$10}')
            if [[ ${ServiceStatus} == "online" ]]; then
                echo -e "\n$SUCCESS 控制面板已启动\n"
            else
                echo -e "\n$FAIL 控制面板启动失败，请检查原因后重试！\n"
            fi
        fi
        if [[ ${ExitStatusTTYD} -eq 0 ]]; then
            ServiceStatus=$(pm2 describe web_terminal | grep status | awk '{print $4}')
            case ${ServiceStatus} in
            online)
                pm2 restart web_terminal
                echo -e "\n$COMPLETE 网页终端已重启\n"
                ;;
            stopped)
                pm2 start web_terminal
                echo -e "\n$COMPLETE 网页终端已重新启动\n"
                ;;
            errored)
                echo -e "\n$WARN 检测到服务状态异常，开始尝试修复...\n"
                pm2 delete web_terminal
                Update_Shell
                cd $RootDir
                Install_TTYD && sleep 3
                PM2_List_All_Services
                local ServiceNewStatus=$(cat $FilePm2List | grep "web_terminal" -w | awk -F '|' '{print$10}')
                if [[ ${ServiceNewStatus} == "online" ]]; then
                    echo -e "\n$SUCCESS 已修复错误，服务恢复正常运行！\n"
                else
                    echo -e "\n$FAIL 未能自动修复错误，请检查原因后重试！\n"
                fi
                ;;
            esac
        else
            Update_Shell
            cd $RootDir
            Install_TTYD && sleep 1
            PM2_List_All_Services
            local ServiceStatus=$(cat $FilePm2List | grep "web_terminal" -w | awk -F '|' '{print$10}')
            if [[ ${ServiceStatus} == "online" ]]; then
                echo -e "\n$SUCCESS 网页终端已启动\n"
            else
                echo -e "\n$FAIL 网页终端启动失败，请检查原因后重试！\n"
            fi
        fi
        ;;
    ## 关闭服务
    off)
        if [[ ${ExitStatusSERVER} -eq 0 ]]; then
            pm2 stop web_server >/dev/null 2>&1
            if [[ ${ExitStatusTTYD} -eq 0 ]]; then
                pm2 stop web_terminal >/dev/null 2>&1
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
        echo -e "\n$COMPLETE 已重置控制面板的用户名和登录密码\n\n[用户名]： useradmin\n[密  码]： passwd\n"
        ;;
    esac
    ## 删除 PM2 进程日志清单
    [ -f $FilePm2List ] && rm -rf $FilePm2List
}

## Telegram Bot 功能
function Bot_Control() {

    ## 卸载
    function Remove() {
        echo -e "\n$WORKING 开始卸载...\n"
        [ -f $BotDir/requirements.txt ] && pip3 uninstall -y -r $BotDir/requirements.txt
        rm -rf $BotDir/* $RootDir/bot.session*
        echo -e "\n$COMPLETE 卸载完成"
    }

    ## 备份用户的脚本
    function BackUpUserFiles() {
        local UserFiles=($(
            ls $BotDir/diy 2>/dev/null | grep -Ev "__pycache__|example.py"
        ))
        if [ ${#UserFiles[@]} -gt 0 ]; then
            Make_Dir $RootDir/tmp
            for ((i = 0; i < ${#UserFiles[*]}; i++)); do
                mv -f $BotDir/diy/${UserFiles[i]} $RootDir/tmp
            done
        fi
    }

    ## 安装 Telegram Bot
    function Install_Bot() {
        ## 安装依赖
        echo -e "\n$WORKING 开始安装依赖...\n"
        apk --no-cache add -f python3-dev zlib-dev gcc g++ jpeg-dev musl-dev freetype-dev
        if [ $? -eq 0 ]; then
            echo -e "\n$COMPLETE 依赖安装完成\n"
        else
            echo -e "\n$FAIL 依赖安装失败，请检查原因后重试！\n"
        fi
        ## 检测配置文件是否存在
        if [ ! -s $ConfigDir/bot.json ]; then
            cp -fv $SampleDir/bot.json $ConfigDir/bot.json
        fi
        Make_Dir $BotLogDir
        ## 安装模块
        echo -e "$WORKING 开始安装模块...\n"
        cp -rf $BotSrcDir/jbot $RootDir
        cd $BotDir
        pip3 --default-timeout=3600 install -r requirements.txt
        if [[ $? -eq 0 ]]; then
            echo -e "\n$COMPLETE 模块安装完成\n"
        else
            echo -e "\n$FAIL 模块安装失败，请检查原因后重试！\n"
        fi
    }

    Import_Config_Not_Check
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
                rm -rf $BotLogDir/up.log /root/.pm2/logs/jbot-*.log
                if [[ ${ExitStatusJbot} -eq 0 ]]; then
                    local ServiceStatus=$(cat $FilePm2List | grep "jbot" -w | awk -F '|' '{print$10}')
                    case ${ServiceStatus} in
                    online)
                        pm2 delete jbot >/dev/null 2>&1
                        ## 启动 bot
                        cd $BotDir && pm2 start ecosystem.config.js && sleep 1
                        PM2_List_All_Services
                        local ServiceNewStatus=$(cat $FilePm2List | grep "jbot" -w | awk -F '|' '{print$10}')
                        if [[ ${ServiceNewStatus} == "online" ]]; then
                            echo -e "\n$COMPLETE 电报机器人已重启\n"
                        else
                            echo -e "\n$FAIL 重启失败，请检查原因后重试！\n"
                        fi
                        ;;
                    stopped)
                        pm2 start jbot
                        PM2_List_All_Services
                        local ServiceNewStatus=$(cat $FilePm2List | grep "jbot" -w | awk -F '|' '{print$10}')
                        if [[ ${ServiceNewStatus} == "online" ]]; then
                            echo -e "\n$COMPLETE 电报机器人已重新启动\n"
                        else
                            echo -e "\n$FAIL 启动失败，请检查原因后重试！\n"
                        fi
                        ;;
                    errored)
                        echo -e "\n$WARN 检测到服务状态异常，开始尝试修复...\n"
                        pm2 delete jbot >/dev/null 2>&1
                        ## 恢复用户插件
                        if [ -d $BotDir ]; then
                            BackUpUserFiles
                            [ ! -x /usr/bin/python3 ] && Remove
                            Install_Bot
                            if [[ -d $RootDir/tmp ]]; then
                                mv -f $RootDir/tmp/* $BotSrcDir/jbot/diy
                                rm -rf $RootDir/tmp
                            fi
                        else
                            Install_Bot
                        fi
                        cp -rf $BotSrcDir/jbot $RootDir
                        ## 启动 bot
                        cd $BotDir && pm2 start ecosystem.config.js && sleep 1
                        PM2_List_All_Services
                        local ServiceNewStatus=$(cat $FilePm2List | grep "jbot" -w | awk -F '|' '{print$10}')
                        if [[ ${ServiceNewStatus} == "online" ]]; then
                            echo -e "\n$SUCCESS 已修复错误，服务恢复正常运行！\n"
                        else
                            echo -e "\n$FAIL 未能自动修复错误，请检查原因后重试！\n"
                        fi
                        ;;
                    esac
                else
                    ## 恢复用户插件
                    if [ -d $BotDir ]; then
                        BackUpUserFiles
                        [ ! -x /usr/bin/python3 ] && Remove
                        Install_Bot
                        if [[ -d $RootDir/tmp ]]; then
                            mv -f $RootDir/tmp/* $BotSrcDir/jbot/diy
                            rm -rf $RootDir/tmp
                        fi
                    else
                        Install_Bot
                    fi
                    cp -rf $BotSrcDir/jbot $RootDir
                    ## 软链接
                    [ ! -x /usr/local/bin/jcsv ] && ln -sf $UtilsDir/jcsv.sh /usr/local/bin/jcsv
                    ## 启动 bot
                    cd $BotDir && pm2 start ecosystem.config.js && sleep 1
                    local ServiceStatus=$(pm2 describe jbot | grep status | awk '{print $4}')
                    if [[ ${ServiceStatus} == "online" ]]; then
                        echo -e "\n$SUCCESS 电报机器人已启动\n"
                    else
                        echo -e "\n$FAIL 电报机器人启动失败，请检查原因后重试！\n"
                    fi
                fi
                ;;

            ## 关闭服务
            stop)
                if [[ ${ExitStatusJbot} -eq 0 ]]; then
                    pm2 stop jbot >/dev/null 2>&1
                    pm2 list
                    echo -e "\n$COMPLETE 电报机器人已停止\n"
                else
                    echo -e "\n$ERROR 服务不存在！\n"
                fi
                ;;

            ## 更新
            update)
                if [[ ${ExitStatusJbot} -eq 0 ]]; then
                    pm2 delete jbot >/dev/null 2>&1
                    ## 删除日志
                    rm -rf $BotLogDir/up.log
                    ## 保存用户的脚本
                    if [ -d $BotDir ]; then
                        BackUpUserFiles
                        [ ! -x /usr/bin/python3 ] && Remove
                        Install_Bot
                        if [[ -d $RootDir/tmp ]]; then
                            mv -f $RootDir/tmp/* $BotSrcDir/jbot/diy
                            rm -rf $RootDir/tmp
                        fi
                    else
                        Install_Bot
                    fi
                    cp -rf $BotSrcDir/jbot $RootDir
                    ## 启动 bot
                    cd $BotDir && pm2 start ecosystem.config.js && sleep 1
                    local ServiceStatus=$(pm2 describe jbot | grep status | awk '{print $4}')
                    if [[ ${ServiceStatus} == "online" ]]; then
                        echo -e "\n$SUCCESS 电报机器人已更新至最新版本\n"
                    else
                        echo -e "\n$FAIL 电报机器人更新后启动异常，请检查原因后重试！\n"
                    fi
                else
                    echo -e "\n$ERROR 请先启动您的 Bot ！\n"
                    exit ## 终止退出
                fi
                ;;

            ## 查看日志
            logs)
                if [[ -f $BotLogDir/run.log ]]; then
                    echo ''
                    cat $BotLogDir/run.log | tail -n 200
                    echo ''
                else
                    echo -e "\n$ERROR 日志不存在！\n"
                fi
                ;;
            esac
            ## 删除 PM2 进程日志清单
            [ -f $FilePm2List ] && rm -rf $FilePm2List
        else
            echo -e "\n$ERROR 请先在 $ConfigDir/bot.json 中配置好您的 Bot ！\n"
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
    Services="web_server web_terminal jbot"
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
        web_server)
            ServiceName="[控ㅤ制ㅤ面ㅤ板]"
            ;;
        web_terminal)
            ServiceName="[网ㅤ页ㅤ终ㅤ端]"
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
        npm install -g npm npm-install-peers >/dev/null 2>&1
        case ${ARCH} in
        armv7l | armv6l)
            echo -e "\n$WORKING 开始安装常用模块...\n"
            npm install -g date-fns fs crypto dotenv png-js ws@7.4.3
            ;;
        *)
            if [ ! -x /usr/bin/python3 ]; then
                echo -e "\n$WORKING 开始安装 ${BLUE}Python3${PLAIN} 运行环境...\n"
                apk --no-cache add -f python3 py3-pip
                pip3 config set global.index-url https://mirrors.aliyun.com/pypi/simple
                pip3 install --upgrade pip
                pip3 install requests
            fi
            if [ ! -x /usr/bin/ts-node ]; then
                echo -e "\n$WORKING 开始安装 ${BLUE}TypeScript${PLAIN} 运行环境...\n"
                npm install -g ts-node typescript @types/node ts-md5 tslib
            fi
            echo -e "\n$WORKING 开始安装常用模块...\n"
            npm install -g date-fns file-system-cache fs crypto dotenv png-js ws@7.4.3 tunnel prettytable js-base64 ds
            ;;
        esac
        echo -e "\n$TIPS 忽略 ${YELLOW}WARN${PLAIN} 警告类输出内容，如有 ${RED}ERR!${PLAIN} 类报错，自行解读日志。"
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
        jbot)
            Bot_Control $2
            ;;
        *)
            Output_Command_Error 1 ## 命令错误
            ;;
        esac
        ;;
    update)
        case $1 in
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
