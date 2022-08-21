from telethon import events
from .. import jdbot, chat_id,ch_name


@jdbot.on(events.NewMessage(from_users=chat_id, pattern='/start'))
async def bot_start(event):
    '''接收/start命令后执行程序'''
    msg = '''使用方法如下：
    /help 获取命令，可直接发送至botfather。
    /start 开始使用本程序。
    /a 使用你的自定义快捷按钮。
    /addcron 增加cron，例：0 0 * * * task example。
    /clearboard 删除快捷输入按钮。
    /cmd 在系统命令行执行指令，例：/cmd task 查看命令帮助。 
    /cron 进行cron管理。
    /dl 下载文件，例：/dl 
    /edit 从目录选择文件并编辑，需要将编辑好信息全部发给BOT，BOT会根据你发的信息进行替换。建议仅编辑config或crontab.list，其他文件慎用！！！
    /getfile 获取项目文件。
    /log 查看脚本执行日志。
    /task 执行脚本，例：/task example.js。此命令会等待脚本执行完毕，期间不能使用BOT，建议使用run命令。
    /set 设置。
    /setname 设置命令别名。
    /setshort 设置自定义按钮，每次设置会覆盖原设置。
    /run 选择脚本执行，仅支持scripts和own目录下的脚本，选择完后直接后台运行，不影响BOT响应其他命令。 
    
    此外，直接发送文件至BOT，会让您选择保存到目标文件夹，支持保存并运行。'''
    await jdbot.send_message(chat_id, msg)

if ch_name:
    jdbot.add_event_handler(bot_start,events.NewMessage(from_users=chat_id, pattern='开始'))
