from telethon import events
from .. import jdbot, START_CMD, chat_id, logger, BOT_SET, ch_name
from .utils import cmd


@jdbot.on(events.NewMessage(from_users=chat_id, pattern='/cmd'))
async def my_cmd(event):
    """接收/cmd命令后执行程序"""
    logger.info(f'即将执行{event.raw_text}命令')
    msg_text = event.raw_text.split(' ')
    try:
        if isinstance(msg_text, list):
            text = ' '.join(msg_text[1:])
        else:
            text = None
        if START_CMD and text:
            await cmd(text)
            logger.info(text)
        elif START_CMD:
            msg = '''请正确使用/cmd命令，如
            /cmd task                # 查看命令帮助
            /cmd task cookie list    # 查看本地账号清单
            '''
            await jdbot.send_message(chat_id, msg)
        else:
            await jdbot.send_message(chat_id, '未开启CMD命令，如需使用请修改配置文件')
        logger.info(f'[OK] 执行{event.raw_text}命令完毕')
    except Exception as e:
        await jdbot.send_message(chat_id, f'something wrong,I\'m sorry\n{str(e)}')
        logger.error(f'发生了某些错误\n{str(e)}')


if ch_name:
    jdbot.add_event_handler(my_cmd, events.NewMessage(
        chats=chat_id, pattern=BOT_SET['命令别名']['cmd']))
