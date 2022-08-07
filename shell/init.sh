#!/bin/bash
## Author: SuperManito
## Modified: 2022-03-05

set -e
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
PLAIN='\033[0m'
BOLD='\033[1m'
SUCCESS='[\033[32mOK\033[0m]'
COMPLETE='[\033[32mDone\033[0m]'
WARN='[\033[33mWARN\033[0m]'
ERROR='[\033[31mERROR\033[0m]'
WORKING='[\033[34m*\033[0m]'
TIPS='[\033[32m友情提示\033[0m]'
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
sleep 2
## 检测配置文件
${ContrlCmd} check files >/dev/null 2>&1
sleep 2
${UpdateCmd} shell
echo -e "\n\033[1;34m$(date "${TIME}")${PLAIN} ----- ➀ 同步最新源码结束 -----\n"

# ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ 第 二 区 域 ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ #
echo -e "\n\033[1;34m$(date "${TIME}")${PLAIN} ----- ➁ 挂机程序开始 -----\n"
if [[ ${ENABLE_HANGUP} == true ]]; then
  if [[ $(grep "^Cookie1=" ${WORK_DIR}/config/config.sh | awk -F "[\"\']" '{print$2}') ]]; then
    $ContrlCmd hang up
  else
    echo -e "检测到当前可能是首次部署容器，配置文件中还未填入有效的信息，因此不启动挂机程序"
  fi
elif [[ ${ENABLE_HANGUP} == false ]]; then
  echo -e "已设置为不自动启动挂机程序"
fi
echo -e "\n\033[1;34m$(date "${TIME}")${PLAIN} ----- ➁ 挂机程序结束 -----\n"

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
  echo -e "已设置为不自动启动电报机器人"
fi
echo -e "\n\033[1;34m$(date "${TIME}")${PLAIN} ----- ➂ 电报机器人结束 -----\n"

# ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ 第 四 区 域 ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ #
echo -e "\n\033[1;34m$(date "${TIME}")${PLAIN} ----- ➃ 控制面板和网页终端开始 -----\n"
if [[ ${ENABLE_WEB_PANEL} == true ]]; then
  cd ${WORK_DIR}
  export PS1="\u@\h:\w# "
  pm2 start ttyd --name="ttyd" -- -p 7685 -t 'theme={"background": "#292A2B"}' -t cursorBlink=true -t lineHeight=1.3 -t fontSize=16 -t disableLeaveAlert=true bash
  echo -e "\n\033[1;34m$(date "${TIME}")${PLAIN} 网页终端启动成功 $SUCCESS\n"

  cd ./web
  echo -e "[${BLUE}*${PLAIN}] 开始安装面板依赖模块...\n"
  npm install
  echo -e "\n$SUCCESS 模块安装完成\n"
  pm2 start ecosystem.config.js
  cd ${WORK_DIR}
  echo -e "\nTips: 如果这是首次安装并启动此面板，则初始用户名为：useradmin，初始密码为：supermanito"
  echo -e "      请访问 http://<IP>:5678 登陆控制面板并修改配置，注意首次登录会自动强制修改初始密码"
  echo -e "\n\033[1;34m$(date "${TIME}")${PLAIN} 控制面板启动成功 $SUCCESS\n"
elif [[ ${ENABLE_WEB_PANEL} == false ]]; then
  echo -e "已设置为不自动启动控制面板"
fi
echo -e "\n\033[1;34m$(date "${TIME}")${PLAIN} ----- ➃ 控制面板和网页终端结束 -----\n"

# ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ 第 五 区 域 ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ #
echo -e "\n\033[1;34m$(date "${TIME}")${PLAIN} ----- ➄ 预装运行环境开始 -----\n"
if [[ ${ENABLE_ALL_ENV} == false ]]; then
  echo -e "已设置为不在容器启动时安装环境包"
else
  $ContrlCmd env install
fi
echo -e "\n\033[1;34m$(date "${TIME}")${PLAIN} ----- ➄ 预装运行环境结束 -----\n"

echo -e "..." && sleep 1 && echo -e "...." && sleep 1 && echo -e "....." && sleep 1

echo -e "\n\033[1;34m$(date "${TIME}")${PLAIN} \033[1;32m容器启动成功${PLAIN}\n"
echo -e "$TIPS 请退出查看容器初始化日志\n"

crond -f >/dev/null

exec "$@"
