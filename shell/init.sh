#!/bin/bash
## Author: SuperManito
## Modified: 2022-10-27

set -e
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
PURPLE='\033[35m'
AZURE='\033[36m'
PLAIN='\033[0m'
BOLD='\033[1m'
SUCCESS="[${GREEN}成功${PLAIN}]"
COMPLETE="[${GREEN}完成${PLAIN}]"
WARN="[${YELLOW}注意${PLAIN}]"
ERROR="[${RED}错误${PLAIN}]"
FAIL="[${RED}失败${PLAIN}]"
WORKING="[${AZURE} >_ ${PLAIN}]"
EXAMPLE="[${GREEN}参考命令${PLAIN}]"
TIPS="[${GREEN}友情提示${PLAIN}]"
TIME="+%Y-%m-%d %T"
ContrlCmd="taskctl"
UpdateCmd="update"

if [ ! -d ${WORK_DIR}/config ]; then
  echo -e "$ERROR 没有映射 config 配置文件目录给本容器，请先按教程映射该目录...\n"
  exit 1
fi

# ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ 第 一 区 域 ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ #
echo -e "\n\033[1;34m$(date "${TIME}")${PLAIN} ----- ➀ 同步最新源码开始 -----\n"
cd ${WORK_DIR}
sleep 2
git fetch --all
git reset --hard origin/$(git status | head -n 1 | awk -F ' ' '{print$NF}')
[ ! -x /usr/bin/npm ] && apk add -f nodejs-lts npm
sleep 2
## 检测配置文件
${ContrlCmd} check files >/dev/null 2>&1
${UpdateCmd} shell
echo -e "\n\033[1;34m$(date "${TIME}")${PLAIN} ----- ➀ 同步最新源码结束 -----\n"

# ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ 第 二 区 域 ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ #
echo -e "\n\033[1;34m$(date "${TIME}")${PLAIN} ----- ➁ 控制面板和网页终端开始 -----\n"
if [[ ${ENABLE_WEB_PANEL} == true ]]; then
  cd ${WORK_DIR}
  export PS1="\[\e[32;1m\]@Helloworld Cli\[\e[37;1m\] ➜\[\e[34;1m\]  \w\[\e[0m\] \\$ "
  pm2 start ttyd --name "web_terminal" --log-date-format "YYYY-MM-DD HH:mm:ss" -- -p 7685 -t 'theme={"background": "#292A2B"}' -t cursorBlink=true -t fontSize=16 -t disableLeaveAlert=true bash
  echo -e "\n\033[1;34m$(date "${TIME}")${PLAIN} 网页终端启动成功 $SUCCESS\n"

  cd ./web
  echo -e "$WORKING 开始安装面板依赖模块...\n"
  npm install
  echo -e "\n$SUCCESS 模块安装完成\n"
  pm2 start ecosystem.config.js
  cd ${WORK_DIR}
  echo -e "\nTips: 如果这是首次安装并启动此面板，则初始用户名为：useradmin，初始密码为：passwd"
  echo -e "      请访问 http://<IP>:5678 登陆控制面板并修改配置，注意首次登录会自动强制修改初始密码"
  echo -e "\n\033[1;34m$(date "${TIME}")${PLAIN} 控制面板启动成功 $SUCCESS\n"
elif [[ ${ENABLE_WEB_PANEL} == false ]]; then
  echo -e "已设置为不自动启动控制面板"
fi
echo -e "\n\033[1;34m$(date "${TIME}")${PLAIN} ----- ➁ 控制面板和网页终端结束 -----\n"

# ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ 第 三 区 域 ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ #
echo -e "\n\033[1;34m$(date "${TIME}")${PLAIN} ----- ➂ 电报机器人开始 -----\n"
if [[ ${ENABLE_TG_BOT} == true ]]; then
  case $(uname -m) in
  armv7l | armv6l)
    echo -e "宿主机的处理器架构不支持使用此功能"
    ;;
  *)
    if [[ -z $(grep -E "123456789" ${WORK_DIR}/config/bot.json) ]]; then
      $ContrlCmd jbot start
    else
      echo -e "检测到当前还没有配置 bot.json 可能是首次部署容器，因此不启动电报机器人..."
    fi
    ;;
  esac
elif [[ ${ENABLE_TG_BOT} == false ]]; then
  echo -e "已设置为不自启电报机器人"
fi
echo -e "\n\033[1;34m$(date "${TIME}")${PLAIN} ----- ➂ 电报机器人结束 -----\n"

# ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ 第 四 区 域 ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ #
echo -e "\n\033[1;34m$(date "${TIME}")${PLAIN} ----- ➃ 预装运行环境开始 -----\n"
if [[ ${ENABLE_ALL_ENV} == false ]]; then
  echo -e "已设置为不在容器启动时安装环境包"
else
  $ContrlCmd env install
fi
echo -e "\n\033[1;34m$(date "${TIME}")${PLAIN} ----- ➃ 预装运行环境结束 -----\n"

echo -e "..." && sleep 1 && echo -e "...." && sleep 1 && echo -e "....." && sleep 1

echo -e "\n\033[1;34m$(date "${TIME}")${PLAIN} \033[1;32m容器启动成功${PLAIN}\n"
echo -e "$TIPS 请退出查看容器初始化日志\n"

crond -f >/dev/null

exec "$@"
