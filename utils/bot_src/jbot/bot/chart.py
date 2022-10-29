import time, json, requests, datetime
from datetime import timedelta, timezone
from PIL import Image, ImageDraw, ImageFont
from io import BytesIO
# 引入库文件，基于telethon
from telethon import events
# 从上级目录引入 jdbot,chat_id变量
from .. import jdbot, chat_id, LOG_DIR, logger, BOT_DIR, ch_name, BOT_SET
from ..bot.utils import CONFIG_SH_FILE, get_cks
from ..bot.quickchart import QuickChart, QuickChartFunction
from .beandata import get_bean_data

period = 10  # 消息自动删除的时间 单位：秒

SHA_TZ = timezone(
    timedelta(hours=8),
    name='Asia/Shanghai',
)
requests.adapters.DEFAULT_RETRIES = 5
session = requests.session()
session.keep_alive = False

BEAN_IMG = f'{LOG_DIR}/TelegramBot/bean.png'

def createpic(text, totalbean, avatar_url="https://img11.360buyimg.com/jdphoto/s120x120_jfs/t21160/90/706848746/2813/d1060df5/5b163ef9N4a3d7aa6.png"):
    fontSize = 60
    avatar = Image.open(BytesIO(requests.get(
        avatar_url, headers={"User-Agent": ""}).content))
    avatar_size = (110, 110)
    avatar = avatar.resize(avatar_size)
    mask = Image.new('RGBA', avatar_size, color=(0, 0, 0, 0))
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.ellipse(
        (0, 0, avatar_size[0], avatar_size[1]), fill=(0, 0, 0, 255))
    x, y = 50, 25
    box = (x, y, x+avatar_size[0], y+avatar_size[1])
    ttf_path = f'{BOT_DIR}/font/simkai.ttf'
    ttf = ImageFont.truetype(ttf_path, fontSize)
    image = Image.new(mode="RGB", size=(1200, 150), color="#22252a")
    image.paste(avatar, box, mask)
    img_draw = ImageDraw.Draw(image)
    text = text + "·京豆：" + str(totalbean)+"豆"
    img_draw.text((200, 40), text, font=ttf, fill="#9a9b9f")
    bg = Image.open(BEAN_IMG)
    bg.paste(image, (50, 650))
    bg.convert('RGB')
    bg.save(BEAN_IMG)


def createChart(income, out, label):
    qc = QuickChart()
    qc.width = 1600
    qc.height = 800
    qc.background_color = "#22252a"
    qc.config = {
        "data": {
            "datasets": [{
                "backgroundColor": QuickChartFunction('getGradientFillHelper(\'vertical\', ["#2cb9fa", "#598bf8", "#7d5def"])'),
                "data": income,
                "label": "收入",
                "type": "bar"
            },
                {
                "backgroundColor": QuickChartFunction('getGradientFillHelper(\'vertical\', ["#36a2eb", "#a336eb", "#eb3639"])'),
                "data": out,
                "label": "支出",
                "type": "bar"
            }
            ],
            "labels": label
        },
        "options": {
            "plugins": {
                "datalabels": {
                    "display": True,
                    "color": "#eee",
                    "align": "top",
                    "offset": -4,
                    "anchor": "end",
                    "font": {
                        "family": "Helvetica Neue",
                        "size": 30
                    }
                },
                "roundedBars": True
            },
            "legend": {
                "position": "bottom",
                "align": "end",
                "display": True,
                "labels": {
                    "fontSize": 25
                }
            },
            "layout": {
                "padding": {
                    "left": 10,
                    "right": 20,
                    "top": 50,
                    "bottom": 100
                }
            },
            "responsive": True,
            "title": {
                "display": False,
                "position": "bottom",
                "text": '',
                "fontSize": 25,
                "fontColor": "#aaa"
            },
            "tooltips": {
                "intersect": True,
                "mode": "index"
            },
            "scales": {
                "xAxes": [{
                    "gridLines": {
                        "display": True,
                        "color": ""
                    },
                    "ticks": {
                        "display": True,
                        "fontSize": 25,
                        "fontColor": "#999"
                    }
                }],
                "yAxes": [{
                    "gridLines": {
                        "display": True,
                        "color": ""
                    },
                    "ticks": {
                        "display": True,
                        "fontSize": 25,
                        "fontColor": "#999"
                    }
                }]
            }
        },
        "type": "bar"
    }
    qc.to_file(BEAN_IMG)
# 格式基本固定，本例子表示从chat_id处接收到包含hello消息后，要做的事情


@jdbot.on(events.NewMessage(from_users=chat_id, pattern=(r'^/chart')))
# 定义自己的函数名称
async def chart(event):
    msg_text = event.raw_text.split(' ')
    chat_id = event.sender_id
    try:
        if isinstance(msg_text, list) and len(msg_text) == 2:
            text = msg_text[-1]
        else:
            text = None
        if text and int(text) and (int(text) > 0):
            msg = await jdbot.send_message(chat_id, '🕙 正在查询，请稍后...')
            res = await get_bean_data(int(text))
            if res['code'] != 200:
                logger.error("data error")
                await msg.delete()
                await jdbot.send_message(chat_id, "❌ 序号不存在或单次请求过多\n\n" + res['data'])
            else:
                aver = round((res["data"][0][0]+res["data"][0][1]+res["data"][0][2]+res["data"]
                             [0][3]+res["data"][0][4]+res["data"][0][5]+res["data"][0][6])/7, 2)
                createChart(res['data'][0], res['data'][1], res['data'][3])
                logger.info("Start create image")
                createpic(res['data'][4], res['data'][2][-1])
                logger.info("ok")
                await msg.delete()
                result = await jdbot.send_message(chat_id, f'近七天平均收入{aver}豆⚡', file=BEAN_IMG)
                # time.sleep(period)
                # await result.delete()
        else:
            await jdbot.send_message(chat_id, '请在 /chart 后面加上账号序号使用哦~')
    except Exception as e:
        logger.error(str(e))
        line = e.__traceback__.tb_lineno
        await jdbot.send_message(chat_id, "错误类型：" + str(e)+f'\n错误发生在第{line}行\n\n' + str(e))
        logger.error(f'错误发生在第{line}行')

if ch_name:
    jdbot.add_event_handler(chart, events.NewMessage(
        from_users=chat_id, pattern=BOT_SET['命令别名']['chart']))
