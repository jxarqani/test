# 《使用说明》
- __修订日期：2021 年 12 月 12 日__

## 前言
- 请认真阅读所有注释内容，某些方法贯穿全文
- 在下方提到的命令中用 `<>` 括起来的部分表示需要用户自行输入某些内容
- 在下方提到的命令中 `<cmd>` 表示固定的可选命令参数，每个参数表示对应功能的不同用法，注意看注释内容

ㅤ
## 一、基础内容

- ### 1. 执行脚本：

    - #### 普通执行：
          task <name/path/url> now
        > 注意：脚本运行的日志位于日志目录下的某个文件夹内，文件夹名为脚本名去后缀，日志名由日期组成，own仓库脚本的日志文件夹会在原有名称前加上仓库名，并且中间用下划线分开。

    - #### 并发执行：
          task <name/path/url> conc
        > 含义：为每个账号作为单独的进程在后台运行脚本，由于是后台运行故不在命令行输出进度直接记录到日志中\
        > 注意：并发执行非常消耗资源，不要盲目使用尤其是0点，否则资源占满导致终端连不上后只能强制关机重启。

    - #### 命令含义：

        > `<name>` 脚本名，__仅限 scripts 目录__ 的脚本\
        > `<path>` 脚本的 __相对路径__ 或 __绝对路径__，注意在定时配置清单中编写时需使用绝对路径\
        > `<url>` 位于远程仓库的 __脚本链接地址__，自带地址纠正可自动转换为 raw 原始文件链接，执行后脚本默认保存在 scripts 目录

    - #### 注意事项：

        > 1.ㅤ执行以 `jd_` 或 `jx_` 为开头的脚本时该前缀内容可以省略，如遇同名则前者的优先级大于后者\
        > 2.ㅤ执行本地脚本时脚本名的后缀格式（脚本类型）可以省略，当未指定后缀格式时将启用模糊查找\
        > 3.ㅤ当未指定脚本类型但存在同名脚本时，执行优先级为 JavaScript > Python > TypeScript > Shell\
        > 4.ㅤ目前共支持运行 js、py、ts、sh 类型的脚本，TypeScript 和 Python 需要单独安装运行环境，关于如何安装详见高阶内容第Ⅷ条

    - #### 可选参数：

        > 使用方法：追加在命令的末尾，请认真阅读各参数的用法\
        > `--background`ㅤ（简写 `-p`），后台运行脚本，不在前台输出日志
        > `--proxy`ㅤ（简写 `-p`），作用为启用下载代理，该代理固定为 [GHProxy](https://ghproxy.com)，仅适用于执行位于远程仓库的脚本\
        > `--rapid`ㅤ（简写 `-r`），作用为启用迅速模式，不组合互助码降低脚本执行前耗时\
        > `--delay`ㅤ（简写 `-d`），作用为随机延迟一定秒数后再执行脚本，当时间处于每小时的 `0~3,30,58~59` 分时该参数无效\
        > `--cookie`ㅤ（简写 `-c`），作用为指定账号运行，__参数后面需跟账号序号__（在配置文件中的编号），如有多个需用 "," 隔开，支持账号区间，用 "-" 连接

ㅤ
- ### 2. 更新脚本：

    - #### 全部更新：
          update  或  update all

    - #### 单独更新部分内容：
          update <cmd/path>

        - ##### 固定可选参数：

            > `shell`ㅤ项目源码，在未特别说明的情况下更新项目不需要重新部署新的容器\
            > `scripts`ㅤScripts 仓库，项目预装的脚本库\
            > `own`ㅤOwn 仓库，用户自定义拉取的更多扩展仓库\
            > `repo`ㅤ所有仓库，作用为上面两个参数的整合\
            > `raw`ㅤRaw 脚本，用户自定义拉取的更多脚本\
            > `extra`ㅤExtra 自定义脚本，执行更新脚本结束后运行的用户自定义 Shell 脚本\
            > `<path>`ㅤ指定仓库，这里与上面不同需要自行输入内容，具体为目标仓库的相对路径或绝对路径

    - #### 更新仓库时的常见报错：

        > _`Repository more than 5 connections` ———— 原因在于 `Gitee` 的服务器限制 `每秒最多同时连接 5 个客户端`，此报错为正常现象，稍后重新更新即可。_\
        > _`ssh: connect to host gitee.com port XXX: Connection timed out` ———— 是由于当前宿主机的 `XXX` 端口不可用所导致的连接性问题，自行尝试解决。_\
        > _`Could not resolve hostname XXXX: Temporary failure in name resolution lost connection` ———— 字面意思表示无法解析到该 `XXXX` 域名服务器，说明网络环境异常。_

ㅤ
- ### 3. 列出脚本：
      task list
    > 注：查看本地有哪些可以运行的脚本。

ㅤ
- ### 4. 查看命令帮助：
      task 或 taskctl
    > 注：包含了大部分命令的使用方法，并且针对不同架构的设备做了特殊处理。


***

ㅤ
## 二、高阶内容

- ### 1. 终止执行：
      task <name/path> pkill
    > 注：终止运行中的脚本，根据脚本名称搜索对应的进程并立即杀死，当脚本报错死循环时可使用此功能。


- ### 2. 全部执行：
      source runall  或  . runall
    > 注：通过交互选择运行模式执行指定范围的脚本，时间较长不要盲目使用。


- ### 3. 删除日志：
      task rmlog
    > 注：删除活动脚本与更新脚本的日志文件，默认删除 `7天` 以上的日志文件，可以通过配置文件中的相关变量更改默认时间值，可选参数(加在末尾): `<days>` 指定天数。


- ### 4. 进程监控：
      task ps
    > 注：查看资源消耗情况和正在运行的脚本进程。


- ### 5. 清理进程：
      task cleanup
    > 注：检测并终止卡死的脚本进程以此释放内存占用，默认杀死距离启动超过 `6小时` 以上的卡死进程，可选参数(加在末尾): `<hours>` 指定时间（单位小时）。


- ### 6. 账号功能：
      task cookie <cmd>

    - #### 固定可选参数：

        > `check`ㅤ检测账号是否有效 ，更新日期从配置文件中的备注获取，同时判断账号过期时间\
        > `update`ㅤ使用 `WSKEY` 更新CK ，需要在 `account.json` 中正确配置您的信息，`ep` 为设备信息（非必填），若不填会从项目内置的参数中随机\
        > `<num>`ㅤ支持指定账号进行更新，num为某 Cookie 账号在配置文件中的具体编号即可，与指定执行类似


- ### 7. 管理全局环境变量功能：
      task env <cmd>
    > 注：默认通过交互管理全局环境变量，支持快捷命令一键执行相关操作。

    - #### 固定可选参数：

        > `add`ㅤ添加变量\
        > `del`ㅤ删除变量\
        > `edit`ㅤ修改变量\
        > `search`ㅤ查询变量

    - #### 快捷命令：

        - 启用环境变量：

              task env enable <变量名称>

        - 禁用环境变量：

              task env disable <变量名称>

        - 增加环境变量：

              task env add <变量名称> <变量的值>

        - 修改环境变量：

              task env edit <变量名称> <变量新的值>

        - 删除环境变量：

              task env del <变量名称>

        - 查询环境变量：

              task env search <查询关键词>


- ### 8. 安装环境：
      taskctl env install
    >  注：安装常用模块便于执行一些常见的脚本，64位处理器会附带安装 `Python` 和 `TypeSciprt` 环境。


- ### 9. 安装脚本依赖：

    - #### 适用于 JavaScript 和 TypeScript 脚本
          npm install -g <模块名>
        > 注：1. 当脚本报错提示 `need module xxx` 类似字样说明缺少脚本运行所需的依赖，看见 `module` 字样应立即联想到安装模块上。\
        > ㅤㅤ2. 特别要注意的是如果缺少的依赖中带有 `/` 则表示本地依赖文件，一般开发者都会提供相关组件，注意与安装模块区分开不要弄混。
    
    - #### 适用于 Python 脚本
          pip3 install <依赖名>


***

ㅤ
## 三、互助功能内容

- ### 1. 获取互助码：
      task get_share_code now


- ### 2. 格式化导出互助码：
      task exsc
    > 注：输出可直接应用在配置文件中的代码，其原理是从各个活动脚本的日志中获取，所以当新装环境运行完相关活动脚本后才能正常使用。

    - #### 定义导出用于提交到 Bot 的互助码格式的账号排序
          ## 在配置文件中编辑该变量
          BotSubmit=(
            1
            2
            3
            4
            5
          )
        > 注：数字为某 Cookie 账号在配置文件中的具体编号，注意缩进和格式，每行开头四个或两个空格，默认导出前5个账号。



- ### 3. 自动互助功能：
      ## 在配置文件中编辑该变量
      AutoHelpOther="true"
    > 注：详见配置文件中的相关注释，最好理解该功能的工作原理。


- ### 4. 手动定义互助码与相互助力：
      填法示例：

      ## 1.定义东东农场互助
      MyFruit1="xxxxxxxxxxxxxxxxxxxxxxxxx"
      MyFruit2="xxxxxxxxxxxxxxxxxxxxxxxxx"
      MyFruitA=""
      MyFruitB=""
      ForOtherFruit1="${MyFruit1}@${MyFruit2}"
      ForOtherFruit2="${MyFruit1}@${MyFruit2}"

      ## 2.定义东东萌宠互助
      MyPet1="xxxxxxxxxxxxxxxxxxxxxxxxx"
      MyPet2="xxxxxxxxxxxxxxxxxxxxxxxxx"
      MyPet3="xxxxxxxxxxxxxxxxxxxxxxxxx"
      MyPet4="xxxxxxxxxxxxxxxxxxxxxxxxx"
      MyPet5="xxxxxxxxxxxxxxxxxxxxxxxxx"
      MyPet6="xxxxxxxxxxxxxxxxxxxxxxxxx"
      MyPetA=""
      MyPetB=""
      ForOtherPet1="${MyPet1}@${MyPet2}@${MyPet3}@${MyPet4}@${MyPet5}@${MyPet6}"
      ForOtherPet2="${MyPet1}@${MyPet2}@${MyPet3}@${MyPet4}@${MyPet5}@${MyPet6}"
      ForOtherPet3="${MyPet1}@${MyPet2}@${MyPet3}@${MyPet4}@${MyPet5}@${MyPet6}"
      ForOtherPet4="${MyPet1}@${MyPet2}@${MyPet3}@${MyPet4}@${MyPet5}@${MyPet6}"
      ForOtherPet5="${MyPet1}@${MyPet2}@${MyPet3}@${MyPet4}@${MyPet5}@${MyPet6}"
      ForOtherPet6="${MyPet1}@${MyPet2}@${MyPet3}@${MyPet4}@${MyPet5}@${MyPet6}"
    > 注：所有符号需严格使用英文格式，如果启用了自动互助功能那么手动定义的互助码变量均会被覆盖，等于无效。


- ### 5. 提交互助码到公共助力池：
    > 公共池是什么？将本地账号多余的互助次数贡献给池子中的用户进行助力，同时别人会给您的互助码进行助力，前提是您已提交到公共池中

    > Telegram Bot（需要魔法）：\
    > [@JDShareCodebot](https://t.me/JDShareCodebot) \
    > 每周一0点清空助力池，同时开放提交\
    > 输入 /help 查看使用帮助


***

ㅤ
## 四、服务类功能控制内容

- ### 1. 查看各服务的状态
      taskctl server status
    > 注：如遇相关服务没有启动或状态异常，在容器初始成功的前提下请先尝试手动启动。


- ### 2. 后台挂机程序
    > _作用：在后台循环执行挂机类活动脚本。_
    - #### 启动/重启后台挂机程序：

          taskctl hang up
        > 注：当有新的账号添加或账号变动时须重启此程序，否则仍加载之前配置文件中的变量执行挂机活动脚本。

    - #### 停止后台挂机程序：

          taskctl hang down

    - #### 查看后台挂机程序的运行日志：

          taskctl hang logs
        > 注：`Ctrl + C` 退出，如发现脚本报错可尝试重启。


- ### 3. 控制面板和网页终端
    - #### 开启/重启控制面板和网页终端服务：

          taskctl panel on

        > 注：1. 容器第一次启动时如果启用了该功能变量后会自动启动相关服务无需手动执行此命令。\
        > ㅤㅤ2. 在某些环境下当系统重启导致控制面板没有在容器启动时自启可用此命令手动启动。\
        > ㅤㅤ3. 当控制面板或网页终端服务进程异常时还可尝试修复，如果仍然无法访问请检查容器是否初始化成功。

    - #### 关闭控制面板和网页终端服务：

          taskctl panel off

    - #### 查看控制面板的登录信息：

          taskctl panel info
        > 注：如果忘记了登录密码可以用此方法查看。

    - #### 重置控制面板用于登录的用户名和密码：

          taskctl respwd
        > 注：重置后的用户名和密码均为初始信息。


- ### 4. 机器人（Telegram Bot）
    > 关于如何配置该功能 [点此查看](https://crawling-nectarine-ef2.notion.site/Telegram-Bot-9709bbae7bf8488ab01f3b4867e29b44)

    - #### 启动/重启 Bot 服务：

          taskctl jbot start

    - #### 停止 Bot 服务：

          taskctl jbot stop

    - #### 查看 Bot 的运行日志：

          taskctl jbot logs


***

ㅤ
## 五、环境相关内容

- ### 1. 更新配置文件：

    - #### 备份当前配置文件

          cp -f /jd/config/config.sh /jd/config/bak/config.sh

    - #### 替换新版配置文件

          cp -f /jd/sample/config.sample.sh /jd/config/config.sh
        > 注：此操作为直接替换配置文件，建议优先使用通过控制面板的对比工具代替。

- ### 2. 更新定时配置清单：

    - #### 备份当前配置文件

          cp -f /jd/config/crontab.list /jd/config/bak/crontab.list

    - #### 替换新版配置文件

          cp -f /jd/sample/crontab.sample.list /jd/config/crontab.list
        > 注：此操作为直接替换定时配置清单，执行此操作后需通过更新脚本重新导入定时，注意提前保存您的配置。


- ### 3. 修复环境：
      taskctl env repairs
    > 注：当 npm 程序崩溃时可执行此命令进行修复。


- ### 4. 检测配置文件完整性：
      taskctl check files
    > 注：检测项目相关配置文件是否存在，如果缺失就从模板中重新导入。


***
