from telethon import events
from .. import jdbot, chat_id
from .utils import cmd


@jdbot.on(events.NewMessage(from_users=chat_id, pattern=r'^/reboot$'))
async def bot_reboot(event):
    await jdbot.send_message(chat_id, '🕙 正在重启，请稍后...')
    await cmd('taskctl jbot start')
