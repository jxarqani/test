from telethon import events
from .. import jdbot, chat_id, logger, BOT_SET, ch_name
from .utils import cmd

@jdbot.on(events.NewMessage(from_users=chat_id, pattern=(r'^/beaninfo')))
async def beaninfo(event):
    msg_text = event.raw_text.split(' ')
    chat_id = event.sender_id
    try:
        if isinstance(msg_text, list) and len(msg_text) == 2:
            text = msg_text[-1]
        else:
            text = None
        if text and int(text) and (int(text) > 0):
            text_cmd = "task cookie beans " + text
            await cmd(text)
            logger.info(text)
        else:
            await jdbot.send_message(chat_id, '请在 /beaninfo 后面加上账号序号使用哦~')
        logger.info(f'[OK] 执行{event.raw_text}命令完毕')
            

    except Exception as e:
        await jdbot.send_message(chat_id, f'something wrong,I\'m sorry\n{str(e)}')
        logger.error(f'发生了某些错误\n{str(e)}')

if ch_name:
    jdbot.add_event_handler(beaninfo, events.NewMessage(
        chats=chat_id, pattern=BOT_SET['命令别名']['beaninfo']))
