## Version: v1.14.0
## Date: 2022-08-09
## Update Content: 1. 移除了部分变量 2. 新增定时任务变动通知控制变量 3. 账号屏蔽功能新增支持填入用户名

# ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ 自 定 义 环 境 变 量 设 置 区 域 ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ #
# 可在下方编写您需要用到的额外环境变量，格式：export 变量名="变量值"




# ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ 账 号 设 置 区 域 ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ #

# 注意：所有赋值等号两边不能有空格，所有的值请一律在两侧添加半角的双引号，如果变量值中含有双引号，则外侧改为一对半角的单引号。

## ※ 定义账号（必填）
# 请依次填入每个用户的Cookie，具体格式为( pt_key=xxxxxxxxxx;pt_pin=xxxx; )，只有 pt_key 字段和 pt_pin 字段，没有其他字段
# 必须按数字顺序1、2、3、4...依次编号下去，账号变量之间不能有空变量，否则自第一个空变量开始下面的所有账号将不会生效
# 不允许有汉字，如果ID有汉字，请在PC浏览器上获取Cookie，会自动将汉字转换为URL编码，或者通过面板的转码工具进行转换
# 每次获取、更新账号后会自动在变量的下一行更新备注
Cookie1=""
## pt_pin=无;  手机号：无;  上次更新：无;  备注：无;
Cookie2=""
## pt_pin=无;  手机号：无;  上次更新：无;  备注：无;


## ❖ 账号屏蔽功能（选填）
# 可以使用此功能在不调整 Cookie 账号变量的的前提下屏蔽掉目标账号，变量中需填写目标屏蔽账号对应 Cookie 序号或 pt_pin 用户名
# 注意该功能仅在默认使用全部账号运行脚本时有效，在使用指定账号参数或分组账号参数运行脚本时所有屏蔽设置均不会生效
# 示例：TempBlockCookie="2 test_user" 临时屏蔽掉账号2和用户名为 test_user 的账号，多个用空格分开不分前后顺序
TempBlockCookie=""

# 如果只想屏蔽某账号不执行特定脚本，可以参考下方 case 语句的例子来控制
# 注意代码缩进和该 case 语句的语法，脚本名称需去掉后缀格式，否则不能被程序识别
# 代码示例：
# case $1 in
# test)
#   TempBlockCookie="test_user"     # 用户名为 test_user 的账号不执行 test 脚本
#   ;;
# example | warp)
#   TempBlockCookie="3 6"     # 账号3、账号6不执行 example 和 warp 脚本
#   ;;
# esac


## ❖ 自动增加新的账号
# 控制通过调用面板 OpenApi 接口或使用本项目其它添加账号工具后是否自动添加新的 Cookie 账号
# 默认已启用，如想禁用请修改为 "false"，可避免自动添加陌生人的账号，也可以防止被滥用
export CK_AUTO_ADD="true"




# ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ 主 要 仓 库 设 置 区 域 ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ #

# 项目文档：https://supermanito.github.io/Helloworld/#/config/主要仓库

## ❖ Scripts 主要仓库脚本定时任务开关（自动增加/自动删除）
# 当启用自动增加时，如果从检测文件中检测到有新的定时任务会自动在本地增加，定时时间为检测文件中定义的时间
# 当启用自动删除时，会自动从检测文件中读取比对删除的任务，脚本只会删除失效定时任务的所在行
# 当启用自动删除时，如果您有添加额外脚本是以 "jd_" "jr_" "jx_" 开头的会被自动删除，其它字符开头的任务则不受影响
# 检测文件：Scripts仓库中的 docker/crontab_list.sh（此清单由仓库开发者维护），如果文件不存在将使用 utils 目录下的公共定时清单
# "AutoAddCron": 自动增加；"AutoDelCron": 自动删除；如需启用请设置为 "true"，否则请设置为 "false"，默认均为 "true"
AutoAddCron="true"
AutoDelCron="true"

## ❖ Scripts 主要仓库脚本新增定时任务自动禁用功能
# 当主要仓库有新脚本时，如果不想让其自动运行，可以使用该功能，会自动注释新的定时任务，如需启用该功能请设置为 "true"
DisableNewCron=""




# ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ 扩 展 仓 库 设 置 区 域 ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ #

## ❖ Own Repo 扩展仓库
# 项目文档：https://supermanito.github.io/Helloworld/#/config/扩展仓库
# 除 Scripts 主库外用户还可以通过定义下方的变量添加更多的仓库到本地

# 如果启用了 "自动增加定时" 那么通过此方式导入的脚本会按照标准格式导入定时任务，不符合的脚本会被略过，仅支持导入 js 类型的脚本
# 标准格式指定的是当脚本的注释内容中同时含有crontab表达式和完整脚本名才可自动增加定时任务，此标准方法能排除许多无用脚本
# 如果您的设备不能有效连通 GitHub 建议加上代理，否则可能会出现连接缓慢、丢包等情况，非常影响使用

OwnRepoUrl1=""
OwnRepoUrl2=""

OwnRepoBranch1=""
OwnRepoBranch2=""

OwnRepoPath1=""
OwnRepoPath2=""

# 示例：
# OwnRepoUrl：仓库地址清单，必须从1开始依次编号
# OwnRepoBranch：分支清单，不能为 "空" 必须指定分支的名称，编号必须和 OwnRepoUrl 对应。
# OwnRepoPath：脚本路径清单，要使用的脚本在仓库哪个路径下，请输入仓库下的相对路径，默认空值""代表仓库根目录，编号必须和 OwnRepoUrl 对应。
#              同一个仓库下不同文件夹之间使用空格分开，如果既包括根目录又包括子目录，填写请见示例中OwnRepoPath3。
# 所有脚本存放在 own 目录下，三个清单必须一一对应，示例如下：
# OwnRepoUrl1="https://gitee.com/abc/jdtsa.git"
# OwnRepoUrl2="https://github.com/nedcd/jxddfsa.git"
# OwnRepoUrl3="git@github.com:eject/poex.git"
# OwnRepoBranch1="master"   # 代表第1个仓库 https://gitee.com/abc/jdtsa.git 使用 "master" 主分支
# OwnRepoBranch2="main"     # 代表第2个仓库 https://github.com/nedcd/jxddfsa.git 使用 "main" 分支
# OwnRepoBranch3="master"   # 代表第3个仓库 git@github.com:eject/poex.git 使用 "master" 分支
# OwnRepoPath1=""                   # 代表第1个仓库https://gitee.com/abc/jdtsa.git，您想使用的脚本就在仓库根目录下。
# OwnRepoPath2="parse/tc normal"    # 代表第2个仓库 https://github.com/nedcd/jxddfsa.git，您想使用的脚本在仓库的 parse/tc 和 normal 文件夹下，必须输入相对路径
# OwnRepoPath3="'' cron"            # 代表第3个仓库git@github.com:eject/poex.git，您想使用的脚本在仓库的 根目录 和 cron 文件夹下，必须输入相对路径

## ❖ Own Repo 扩展仓库脚本定时任务开关（自动增加/自动删除）
# 自动增加: "AutoAddOwnRepoCron"；自动删除: "AutoDelOwnRepoCron"；如需启用请设置为 "true"，否则请设置为 "false"
# 默认均为 "true"，项目不一定能完全从脚本中识别出有效的 cron 设置，如果发现不能满足您的需要，请修改为 "false" 以取消自动增加或自动删除
AutoAddOwnRepoCron="true"
AutoDelOwnRepoCron="true"

## ❖ Own Repo 扩展仓库脚本新增定时任务自动禁用功能
# 当扩展仓库有新脚本时，如果不想让其自动运行，可以使用该功能，会自动注释新的定时任务，如需启用该功能请设置为 "true"
DisableNewOwnRepoCron=""

## ❖ Own Repo 扩展仓库脚本重复定时任务自动禁用功能
# 重复脚本依据脚本名判断，自动检测定时清单中 Own 目录下的同名脚本，如需启用该功能请设置为 "true"
# 启用该功能后如果定时清单中已存在相同脚本名称的定时任务，那么导入的定时任务会被注释，注意只有在拉取单个仓库时有效，同时拉取多个仓库时无效
DisableDuplicateOwnRepoCron=""

## ❖ Own Repo 扩展仓库脚本定时任务屏蔽功能
# 如果不想导入某类脚本的定时就在该变量中定义屏蔽关键词，关键词仅限英文和数字不支持符号，多个关键词用空格隔开，注意区分大小写
# 例如不想自动增加开卡脚本和宠汪汪脚本的定时任务 OwnRepoCronShielding="opencard joy"
OwnRepoCronShielding=""




# ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ 扩 展 脚 本 设 置 区 域 ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ #

## ❖ Own RawFile 扩展脚本
# 项目文档：https://supermanito.github.io/Helloworld/#/config/扩展脚本
# 用户可以通过定义下方的变量单独添加更多的脚本到本地

# 请先确认您能正常下载目标脚本后再列在下方，位于托管仓库的脚本支持地址纠正功能可不填入 raw 原始文件地址，也支持一般网站
# 如果启用了 "自动增加定时" 那么通过此方式导入的脚本始终自动增加定时任务，支持导入 js、py、ts 类型的脚本
# 导入前请先确认目标脚本中是否含有 `Crontab 表达式`，如若没有或者未识别到那么将随机指定一个每天执行一次的定时
# 注意缩进和格式，每行开头两个或四个空格，一行一个脚本链接，首尾一对半角括号
# 如果您的设备不能有效连通 GitHub 则需要使用代理，建议优先使用您的个人代理
# 如果您没有代理则推荐使用 jsDelivr 公共代理，可使用官方代理链接转换工具 https://www.jsdelivr.com/github

OwnRawFile=(
)

# 示例：
# OwnRawFile=(
#   https://gitee.com/wabdwdd/scipts/raw/master/example.js
#   https://cdn.jsdelivr.net/gh/lonfeg/loon@raw/main/test.js
#   https://cdn.jsdelivr.net/gh/sunsem/qx@raw/main/utils.js
# )

## ❖ Own RawFile 扩展脚本定时任务开关（自动增加/自动删除）
# 自动增加: "AutoAddOwnRawCron"；自动删除: "AutoDelOwnRawCron"；如需启用请设置为 "true"，否则请设置为 "false"，默认均为 "true"
AutoAddOwnRawCron="true"
AutoDelOwnRawCron="true"




# ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ 项 目 功 能 设 置 区 域 ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ #

## ❖ 1. 定时任务变动推送通知
# 定义当定时任务变动时是否推送通知提醒，Add 代表新增定时，Del 代表失效定时，如果不想收到项目关于定时任务变动的推送通知请修改为 "false"
EnableAddCronNotify="true"
EnableDelCronNotify="true"

## ❖ 2. 控制删除日志时间
# 定义在运行删除旧的日志任务时要删除多少天以前的日志，请输入正整数，不填则禁用删除日志的功能
RmLogDaysAgo="7"

## ❖ 3. 定义随机延迟时间范围
# 如果任务不是必须准点运行的任务，那么给它增加一个随机延迟，由您定义最大延迟时间，单位为秒，如 RandomDelay="300" ，表示任务将在 1-300 秒内随机延迟一个秒数，然后再运行
# 在定时清单中，在每小时第的 0~3,30~31,58~59 几个分钟时间内启动的任务，均算作必须准点运行的任务，在启动这些任务时，即使您定义了RandomDelay，也将准点运行，不启用随机延迟
# 在定时清单中，除掉每小时上述时间启动的任务外，其他任务在您定义了 RandomDelay 的情况下，一律启用随机延迟，但如果给某些任务添加了 "now"，那么这些任务也将无视随机延迟直接运行
RandomDelay="300"

## ❖ 4. 自定义 Extra 脚本功能
# 在每次执行更新脚本时额外运行的 Shell 脚本
# 必须将脚本命名为 "extra.sh" 并且放置在 config 目录下
# 如想启用请赋值为 "true"
EnableExtraShell=""
# 定义 Extra 自定义脚本远程同步功能：
#   1). 功能开关，如想启用请赋值为 "true"
EnableExtraShellSync=""
#   2). 同步地址
ExtraShellSyncUrl=""

## ❖ 5. 更新账号推送通知
# 控制当使用 wskey 更新 Cookie 后是否推送更新结果内容
# 默认不推送，如想要接收推送通知提醒请赋值为 "true"
EnableCookieUpdateNotify=""

## ❖ 6. 更新账号异常告警
# 控制当使用 wskey 更新 Cookie 失败后是否推送通知提醒，以用于快速处理失效的 wskey
# 默认不推送，如想要接收推送通知提醒请赋值为 "true"
EnableCookieUpdateFailureNotify=""

## ❖ 7. 控制是否保存远程执行的脚本
# 控制当 task <url> now 任务执行完毕后是否删除脚本（下载的脚本默认存放在 scripts 目录），即是否本地保存执行的脚本
# 默认不删除，如想要自动删除请赋值为 "true"
AutoDelRawFiles=""

## ❖ 8. 脚本全局代理
# Powered by global-agent (仅支持 js 脚本)
# 官方仓库：https://github.com/gajus/global-agent
# 官方文档：https://www.npmjs.com/package/global-agent
# 全局代理，如想全局启用代理请赋值为 "true"
EnableGlobalProxy=""

# 如果只是想在执行部分脚本时使用代理，可以参考下方 case 语句的例子来控制，脚本名称请去掉后缀格式，同时注意代码缩进
# case $1 in
# test)
#   EnableGlobalProxy="true"    ## 在执行 test 脚本时启用代理
#   ;;
# utils | warp)
#   EnableGlobalProxy="true"    ## 在执行 utils 和 warp 脚本时启用代理
#   ;;
# *)
#   EnableGlobalProxy="false"
#   ;;
# esac

## 定义 HTTP 代理地址（必填）
# 如需使用，请自行解除下一行的注释并赋值并赋值
# export GLOBAL_AGENT_HTTP_PROXY=""

## 定义 HTTPS 代理地址，为 HTTPS 请求指定单独的代理（选填）
# 如果未设置此变量那么两种协议的请求均通过 HTTP 代理地址变量设定的地址
# 如需使用，请自行解除下一行的注释并赋值并赋值
# export GLOBAL_AGENT_HTTPS_PROXY=""

## ❖ 9. 自定义推送通知模块功能
# 默认使用项目提供的 sendNotify.js 推送通知模块，配置教程详见官网 https://supermanito.github.io/Helloworld/#/config/推送通知
# 如想使用第三方推送通知模块请将下方变量赋值为 "true" ，并在 config 目录下存放您的 sendNotify.js 脚本
# 注意如若使用第三方通知模块可能会出现兼容性问题导致项目部分功能不可用
EnableCustomNotify=""




# ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ 推 送 通 知 设 置 区 域 ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ #

# 在下方定义推送通知方式，想通过什么渠道收取通知，就填入对应渠道的值，您也可以同时使用多个渠道获取通知
# 目前提供：Server酱、Bark、Telegram、钉钉、企业微信、iGot、pushplus、go-cqhttp、WxPusher
# 项目文档：https://supermanito.github.io/Helloworld/#/config/推送通知

## ❖ 定义通知尾
export NOTIFY_TAIL="❖ 本通知 By：https://supermanito.github.io/Helloworld"

## ❖ 通知内容屏蔽关键词，多个词用 "&" 连接，注意屏蔽针对的是内容而不是通知标题
export NOTIFY_MASKING=""

## ❖ 1. Server酱
# 官网：https://sct.ftqq.com
# 下方填写 SCHKEY 值或 SendKey 值
export PUSH_KEY=""
# 自建Server酱
export SCKEY_WECOM=""
export SCKEY_WECOM_URL=""


## ❖ 2. Bark
# 参考图片：https://github.com/chinnkarahoi/jd_scripts/blob/master/icon/bark.jpg
# 下方填写app提供的设备码，例如：https://api.day.app/123 那么此处的设备码就是123
export BARK_PUSH=""
# 下方填写推送声音设置，例如choo，具体值请在bark-推送铃声-查看所有铃声
export BARK_SOUND=""
# 下方填写推送消息分组，默认为 "HelloWorld"，推送成功后可以在bark-历史消息-右上角文件夹图标查看
export BARK_GROUP=""


## ❖ 3. Telegram
# 具体教程：https://github.com/chinnkarahoi/jd_scripts/blob/master/backUp/TG_PUSH.md
# 需设备可连接外网，"TG_BOT_TOKEN" 和 "TG_USER_ID" 必须同时赋值
# 下方填写自己申请 @BotFather 的 Token，如 10xxx4:AAFcqxxxxgER5uw
export TG_BOT_TOKEN=""
# 下方填写 @getuseridbot 中获取到的纯数字ID
export TG_USER_ID=""
# Telegram 代理IP（选填）
# 下方填写代理IP地址，代理类型为 http，比如您代理是 http://127.0.0.1:1080，则填写 "127.0.0.1"
# 如需使用，请自行解除下一行的注释并赋值
# export TG_PROXY_HOST=""
# Telegram 代理端口（选填）
# 下方填写代理端口号，代理类型为 http，比如您代理是 http://127.0.0.1:1080，则填写 "1080"
# 如需使用，请自行解除下一行的注释并赋值
# export TG_PROXY_PORT=""
# Telegram 代理的认证参数（选填）
# export TG_PROXY_AUTH=""
# Telegram api自建反向代理地址（选填）
# 教程：https://www.hostloc.com/thread-805441-1-1.html
# 如反向代理地址 http://aaa.bbb.ccc 则填写 aaa.bbb.ccc
# 如需使用，请赋值代理地址链接，并自行解除下一行的注释
# export TG_API_HOST=""


## ❖ 4. 钉钉
# 官方文档：https://developers.dingtalk.com/document/app/custom-robot-access
# 参考图片：https://github.com/chinnkarahoi/jd_scripts/blob/master/icon/DD_bot.png
# "DD_BOT_TOKEN" 和 "DD_BOT_SECRET" 必须同时赋值
# 下方填写token后面的内容，只需 https://oapi.dingtalk.com/robot/send?access_token=XXX 等于=符号后面的XXX即可
export DD_BOT_TOKEN=""
# 下方填写密钥，机器人安全设置页面，加签一栏下面显示的 SEC 开头的 SECXXXXXXXXXX 等字符
# 注:钉钉机器人安全设置只需勾选加签即可，其他选项不要勾选
export DD_BOT_SECRET=""


## ❖ 5. 企业微信 - 机器人
# 官方文档：https://work.weixin.qq.com/api/doc/90000/90136/91770
# 下方填写密钥，企业微信推送 webhook 后面的 key
export QYWX_KEY=""


## ❖ 6. 企业微信 - 应用
# 参考文档：http://note.youdao.com/s/HMiudGkb
#          http://note.youdao.com/noteshare?id=1a0c8aff284ad28cbd011b29b3ad0191
# 下方填写素材库图片id（corpid,corpsecret,touser,agentid），素材库图片填0为图文消息, 填1为纯文本消息
export QYWX_AM=""


## ❖ 7. iGot聚合
# 官方文档：https://wahao.github.io/Bark-MP-helper
# 下方填写iGot的推送key，支持多方式推送，确保消息可达
export IGOT_PUSH_KEY=""


## ❖ 8. pushplus
# 官网：http://www.pushplus.plus
# 下方填写您的Token，微信扫码登录后一对一推送或一对多推送下面的 token，只填 "PUSH_PLUS_TOKEN" 默认为一对一推送
export PUSH_PLUS_TOKEN=""
# 一对一多推送（选填）
# 下方填写您的一对多推送的 "群组编码" ，（一对多推送下面->您的群组(如无则新建)->群组编码）
# 注 1. 需订阅者扫描二维码
#    2、如果您是创建群组所属人，也需点击“查看二维码”扫描绑定，否则不能接受群组消息推送
export PUSH_PLUS_USER=""


## ❖ 9. go-cqhttp
# 官方仓库：https://github.com/Mrs4s/go-cqhttp
# 官方文档：https://docs.go-cqhttp.org/api/
# 官方搭建教程：https://docs.go-cqhttp.org/guide/quick_start.html
# 需要自建服务，默认监听地址：127.0.0.1:5700，下方填写您服务的监听地址
export GO_CQHTTP_URL=""
# 下方填写接收消息的QQ或QQ群
export GO_CQHTTP_QQ=""
# 下方填写 "send_private_msg" 或 "send_group_msg" 的值
export GO_CQHTTP_METHOD=""
# 下方填写分开推送的脚本名，如需使用请赋值并自行解除下一行的注释
# export GO_CQHTTP_SCRIPTS=""
# 下方填写外网扫码地址，如需使用请赋值并自行解除下一行的注释
# export GO_CQHTTP_LINK=""
# 下方填写消息分页字数，默认每 "1500" 字分为一条信息，如需修改请在赋值下面的变量
export GO_CQHTTP_MSG_SIZE=""
# 下方填写当账号失效后是否启用私信，默认启用，如需关闭请修改为 "false"
# 由于在账号失效后一般会批量群发，有可能触发风控下线或者封号，不建议禁用
# export GO_CQHTTP_EXPIRE_SEND_PRIVATE=""


## ❖ 10. WxPusher
# 官方仓库：https://github.com/wxpusher/wxpusher-client
# 官方文档：https://wxpusher.zjiecode.com/docs
# 微信公众号：WxPusher 消息推送平台
# 下方填写您申请的 appToken，可在管理台查看：https://wxpusher.zjiecode.com/admin/main/app/appToken
export WP_APP_TOKEN=""
# 下方填写发送目标用户的UID，多个用户用 ";" 分隔，WP_UIDS 和 WP_TOPICIDS 可以同时填写, 也可以只填写一个
export WP_UIDS=""
# 下方填写发送主题的 TopicId ，适用于群发，用户只需要订阅主题即可，多个主题用 ";" 分隔，使用 WP_UIDS 单独发送的时可以不定义此变量
export WP_TOPICIDS=""
# 下方填写原文链接，如需使用请赋值并自行解除下一行的注释
# export WP_URL=""




# ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ 互 助 码 类 设 置 区 域  ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ #

## ❖ 1. 自动互助功能
# 工作原理为导入最新的导出互助码日志，日志位于 log/ShareCodes 目录下，当该变量赋值为 true 时会导入最新的导出互助码日志
# 导出互助码脚本如果检测到某个互助码变量为空将从上一个日志中获取，您还可以通过修改日志解决一直无法获取到互助码的问题
# 由于相关命令处理字符的数量有一定限制，该功能最多支持 55 个账号，超出部分的账号不会参与互助
# 默认已启用该功能，如想关闭该功能取消赋值变量即可
AutoHelpOther="true"

## ❖ 2. 定义导出互助码的助力类型
# 填 0 或不填使用 “按编号优先助力模板” ，此模板为默认助力类型也是最优的选择
# 填 1 使用 “全部一致助力模板” ，所有账户要助力的码全部一致
# 填 2 使用 “均等机会助力模板” ，所有账户获得助力次数一致
# 填 3 使用 “随机顺序助力模板” ，本套脚本内账号间随机顺序助力，每次生成的顺序都不一致
HelpType=""

## ❖ 3. 定义导出用于提交到 Bot 的互助码格式的账号排序
# 数字为某 Cookie 账号在配置文件中的具体编号，注意缩进和格式，每行开头四个或两个空格，默认导出前5个账号
BotSubmit=(
  1
  2
  3
  4
  5
)

## ❖ 4. 手动定义互助码环境变量（选填）
# 请在运行过一次需要互助的活动脚本以后，再运行一次 task exsc 即可获取，将输出内容替换下面自定义互助码填写区域中的内容即可
# 如果启用了自动互助功能那么下方手动定义的互助码变量和助力规则将不会生效，已默认注释掉相关模板
# 受限于代码底层相关命令，根据实际测试可能最多支持不超过 60 个账号，否则超出后会导致项目主命令报错无法执行任何脚本，包括定时计划任务

# 互助码是填在My系列变量中的，ForOther系列变量中只要填入My系列的变量名即可，按注释中的例子拼接，以东东农场为例，如下所示。
# 实际上东东农场一个账号只能给别人助力3次，多写的话只有前几个会被助力。但如果前面的账号获得的助力次数已经达到上限了那么还是会尝试继续给余下的账号助力，所以多填也是有意义的。
# ForOther系列变量必须从1开始编号，依次编下去。

# 示例：
# MyFruit1="e6e04602d5e343258873af1651b603ec"  # 这是Cookie1这个账号的互助码
# MyFruit2="52801b06ce2a462f95e1d59d7e856ef4"  # 这是Cookie2这个账号的互助码
# MyFruit3="e2fd1311229146cc9507528d0b054da8"  # 这是Cookie3这个账号的互助码
# MyFruit4="6dc9461f662d490991a31b798f624128"  # 这是Cookie4这个账号的互助码
# MyFruit5="30f29addd75d44e88fb452bbfe9f2110"  # 这是Cookie5这个账号的互助码
# MyFruit6="1d02fc9e0e574b4fa928e84cb1c5e70b"  # 这是Cookie6这个账号的互助码
# MyFruitA="5bc73a365ff74a559bdee785ea97fcc5"  # 这是我和别人交换互助，另外一个用户A的互助码
# MyFruitB="6d402dcfae1043fba7b519e0d6579a6f"  # 这是我和别人交换互助，另外一个用户B的互助码
# MyFruitC="5efc7fdbb8e0436f8694c4c393359576"  # 这是我和别人交换互助，另外一个用户C的互助码
# ForOtherFruit1="${MyFruit2}@${MyFruitB}@${MyFruit4}"   # Cookie1这个账号助力Cookie2的账号的账号、Cookie4的账号以及用户B
# ForOtherFruit2="${MyFruit1}@${MyFruitA}@${MyFruit4}"   # Cookie2这个账号助力Cookie1的账号的账号、Cookie4的账号以及用户A
# ForOtherFruit3="${MyFruit1}@${MyFruit2}@${MyFruitC}@${MyFruit4}@${MyFruitA}@${MyFruit6}"  # 解释同上，东东农场实际上只能助力3次
# ForOtherFruit4="${MyFruit1}@${MyFruit2}@${MyFruit3}@${MyFruitC}@${MyFruit6}@${MyFruitA}"  # 解释同上，东东农场实际上只能助力3次
# ForOtherFruit5="${MyFruit1}@${MyFruit2}@${MyFruit3}@${MyFruitB}@${MyFruit4}@${MyFruit6}@${MyFruitC}@${MyFruitA}"
# ForOtherFruit6="${MyFruit1}@${MyFruit2}@${MyFruit3}@${MyFruitA}@${MyFruit4}@${MyFruit5}@${MyFruitC}"

## 1. 东东农场
# MyFruit1=""
# MyFruit2=""
# MyFruitA=""
# MyFruitB=""
# ForOtherFruit1=""
# ForOtherFruit2=""

## 2. 东东萌宠
# MyPet1=""
# MyPet2=""
# MyPetA=""
# MyPetB=""
# ForOtherPet1=""
# ForOtherPet2=""

## 3. 种豆得豆
# MyBean1=""
# MyBean2=""
# MyBeanA=""
# MyBeanB=""
# ForOtherBean1=""
# ForOtherBean2=""

## 4. 东东工厂
# MyJdFactory1=""
# MyJdFactory2=""
# MyJdFactoryA=""
# MyJdFactoryB=""
# ForOtherJdFactory1=""
# ForOtherJdFactory2=""

## 5. 京喜工厂
# MyDreamFactory1=""
# MyDreamFactory2=""
# MyDreamFactoryA=""
# MyDreamFactoryB=""
# ForOtherDreamFactory1=""
# ForOtherDreamFactory2=""

## 6. 口袋书店
# MyBookShop1=""
# MyBookShop2=""
# MyBookShopA=""
# MyBookShopB=""
# ForOtherBookShop1=""
# ForOtherBookShop2=""

## 7. 签到领现金
# MyCash1=""
# MyCash2=""
# MyCashA=""
# MyCashB=""
# ForOtherCash1=""
# ForOtherCash2=""

## 8. 闪购盲盒
# MySgmh1=""
# MySgmh2=""
# MySgmhA=""
# MySgmhB=""
# ForOtherSgmh1=""
# ForOtherSgmh2=""

## 9. 东东健康社区
# MyHealth1=""
# MyHealth2=""
# MyHealthA=""
# MyHealthB=""
# ForOtherHealth1=""
# ForOtherHealth2=""

## 10. 环球挑战赛(限时活动)
# MyGlobal1=""
# MyGlobal2=""
# MyGlobalA=""
# MyGlobalB=""
# ForOtherGlobal1=""
# ForOtherGlobal2=""

## 11. 京东手机狂欢城(限时活动)
# MyCarni1=""
# MyCarni2=""
# MyCarniA=""
# MyCarniB=""
# ForOtherCarni1=""
# ForOtherCarni2=""

## 12. 城城分现金(限时活动)
# MyCity1=""
# MyCity2=""
# MyCityA=""
# MyCityB=""
# ForOtherCity1=""
# ForOtherCity2=""

##################################################################################################
