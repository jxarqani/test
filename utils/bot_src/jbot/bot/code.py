from telethon import events
from .. import jdbot, chat_id
import re, requests, json

## Nolan 公益API
API = 'http://api.nolanstore.top/JComExchange'

requests.adapters.DEFAULT_RETRIES = 1
session = requests.session()

@jdbot.on(events.NewMessage(from_users=chat_id, pattern='/code'))
async def code(event):
    parameter = re.split(r'\/code ', event.raw_text, re.S)
    if len(parameter) == 1:
        ## 消息为空
        await jdbot.send_message(chat_id, ("请输入需要解析的口令"))
        return
    else:
        msg = await jdbot.send_message(chat_id, ("🕙 正在解析中，请稍后..."))
        text = parameter[1]

    try:
        data = requests.post(url=API, headers={'Content-Type': 'application/json'}, json={"code": text}).json()

    except:
        push_msg = "❌ 接口状态异常，请检查网络连接"
    try:
        if (data["code"] == '0'):

            push_msg = f"**【活动标题】** {data['title']}\n**【用户昵称】** {data['userName']}\n**【用户头像】** [点此查看]({data['headImg']})\n**【活动链接】** __{data['jumpUrl']}__"

        elif (data["code"] == '400'):
            push_msg = "❌ 口令不存在，请检查是否正确！"

        else:
            push_msg = "口令不存在或解析失败，请检查口令是否正确！\n\n接口返回数据：\n" + str(json.dumps(data, indent=4, ensure_ascii=False))

    except KeyError:
        push_msg = "❌ 接口回传数据异常"

    await jdbot.edit_message(msg, push_msg, link_preview=False)
