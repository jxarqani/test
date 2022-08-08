import time
import json
from datetime import timedelta
from datetime import timezone
import datetime
from PIL import Image, ImageDraw,ImageFont
import os
import requests
from io import BytesIO
#引入库文件，基于telethon
from telethon import events
#从上级目录引入 jdbot,chat_id变量
from .. import jdbot,chat_id,LOG_DIR,logger,BOT_DIR
from ..bot.utils import CONFIG_SH_FILE, get_cks
from ..bot.quickchart import QuickChart,QuickChartFunction

users = [chat_id]#允许的用户id
period=10 #消息自动删除的时间 单位：秒

SHA_TZ = timezone(
    timedelta(hours=8),
    name='Asia/Shanghai',
)
requests.adapters.DEFAULT_RETRIES = 5
session = requests.session()
session.keep_alive = False

url = "https://api.m.jd.com/api"
def gen_body(page):
    body = {
        "beginDate": datetime.datetime.utcnow().replace(tzinfo=timezone.utc).astimezone(SHA_TZ).strftime("%Y-%m-%d %H:%M:%S"),
        "endDate": datetime.datetime.utcnow().replace(tzinfo=timezone.utc).astimezone(SHA_TZ).strftime("%Y-%m-%d %H:%M:%S"),
        "pageNo": page,
        "pageSize": 20,
    }
    return body


def gen_params(page):
    body = gen_body(page)
    params = {
        "functionId": "jposTradeQuery",
        "appid": "swat_miniprogram",
        "client": "tjj_m",
        "sdkName": "orderDetail",
        "sdkVersion": "1.0.0",
        "clientVersion": "3.1.3",
        "timestamp": int(round(time.time() * 1000)),
        "body": json.dumps(body)
    }
    return params


def get_beans_7days(ck):
    try:
        day_7 = True
        page = 0
        headers = {
            "Host": "api.m.jd.com",
            "Connection": "keep-alive",
            "charset": "utf-8",
            "User-Agent": "Mozilla/5.0 (Linux; Android 10; MI 9 Build/QKQ1.190825.002; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/78.0.3904.62 XWEB/2797 MMWEBSDK/201201 Mobile Safari/537.36 MMWEBID/7986 MicroMessenger/8.0.1840(0x2800003B) Process/appbrand4 WeChat/arm64 Weixin NetType/4G Language/zh_CN ABI/arm64 MiniProgramEnv/android",
            "Content-Type": "application/x-www-form-urlencoded;",
            "Accept-Encoding": "gzip, compress, deflate, br",
            "Cookie": ck,
            "Referer": "https://servicewechat.com/wxa5bf5ee667d91626/141/page-frame.html",
        }
        days = []
        for i in range(0, 7):
            days.append(
                (datetime.date.today() - datetime.timedelta(days=i)).strftime("%Y-%m-%d"))
        beans_in = {key: 0 for key in days}
        beans_out = {key: 0 for key in days}
        while day_7:
            page = page + 1
            resp = session.get(url, params=gen_params(page),
                               headers=headers, timeout=100).text
            res = json.loads(resp)
            if res['resultCode'] == 0:
                for i in res['data']['list']:
                    for date in days:
                        if str(date) in i['createDate'] and i['amount'] > 0:
                            beans_in[str(date)] = beans_in[str(
                                date)] + i['amount']
                            break
                        elif str(date) in i['createDate'] and i['amount'] < 0:
                            beans_out[str(date)] = beans_out[str(
                                date)] + i['amount']
                            break
                    if i['createDate'].split(' ')[0] not in str(days):
                        day_7 = False
            else:
                return {'code': 400, 'data': res}
        days = list(map(lambda x: x[5:] , days))
        return {'code': 200, 'data': [beans_in, beans_out, days]}
    except Exception as e:
        logger.error(str(e))
        return {'code': 400, 'data': str(e)}


def get_total_beans(ck):
    try:
        headers = {
            "Host": "wxapp.m.jd.com",
            "Connection": "keep-alive",
            "charset": "utf-8",
            "User-Agent": "Mozilla/5.0 (Linux; Android 10; MI 9 Build/QKQ1.190825.002; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/78.0.3904.62 XWEB/2797 MMWEBSDK/201201 Mobile Safari/537.36 MMWEBID/7986 MicroMessenger/8.0.1840(0x2800003B) Process/appbrand4 WeChat/arm64 Weixin NetType/4G Language/zh_CN ABI/arm64 MiniProgramEnv/android",
            "Content-Type": "application/x-www-form-urlencoded;",
            "Accept-Encoding": "gzip, compress, deflate, br",
            "Cookie": ck,
        }
        jurl = "https://wxapp.m.jd.com/kwxhome/myJd/home.json"
        resp = session.get(jurl, headers=headers, timeout=100).text
        res = json.loads(resp)
        return res['user']['jingBean'],res['user']['petName'],res['user']['imgUrl']
    except Exception as e:
        logger.error(str(e))

def get_bean_data(i):
    try:
        ckfile = CONFIG_SH_FILE
        cookies = get_cks(ckfile)
        if cookies:
            ck = cookies[i-1]
            beans_res = get_beans_7days(ck)
            beantotal,nickname,pic = get_total_beans(ck)
            if beans_res['code'] != 200:
                return beans_res
            else:
                beans_in, beans_out = [], []
                beanstotal = [int(beantotal), ]
                for i in beans_res['data'][0]:
                    beantotal = int(
                        beantotal) - int(beans_res['data'][0][i]) - int(beans_res['data'][1][i])
                    beans_in.append(int(beans_res['data'][0][i]))
                    beans_out.append(int(str(beans_res['data'][1][i]).replace('-', '')))
                    beanstotal.append(beantotal)
            return {'code': 200, 'data': [beans_in[::-1], beans_out[::-1], beanstotal[::-1], beans_res['data'][2][::-1],nickname,pic]}
    except Exception as e:
        logger.error(str(e))
        return {"code":400}
        

BEAN_IMG = f'{LOG_DIR}/bot/bean.png'

def createpic(text,totalbean,avatar_url="https://img11.360buyimg.com/jdphoto/s120x120_jfs/t21160/90/706848746/2813/d1060df5/5b163ef9N4a3d7aa6.png"):
    fontSize = 60
    avatar = Image.open(BytesIO(requests.get(avatar_url,headers={"User-Agent":""}).content))
    avatar_size=(110,110)
    avatar = avatar.resize(avatar_size)
    mask = Image.new('RGBA', avatar_size, color=(0,0,0,0))
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.ellipse((0,0, avatar_size[0], avatar_size[1]), fill=(0,0,0,255))
    x,y=50,25
    box =(x,y,x+avatar_size[0],y+avatar_size[1])
    ttf_path = f'{BOT_DIR}/font/simkai.ttf'
    ttf = ImageFont.truetype(ttf_path, fontSize)
    image = Image.new(mode="RGB", size=(1200, 150), color="#22252a")
    image.paste(avatar,box,mask)
    img_draw = ImageDraw.Draw(image)
    text = text + "·京豆："+ str(totalbean)+"豆"
    img_draw.text((200, 40), text, font=ttf, fill="#9a9b9f")
    bg = Image.open(BEAN_IMG)
    bg.paste(image,(50,650))
    bg.convert('RGB')
    bg.save(BEAN_IMG)

def createChart(income,out,label):
    qc = QuickChart()
    qc.width=1600
    qc.height=800
    qc.background_color="#22252a"
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
   "labels":{
     "fontSize":25
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
#格式基本固定，本例子表示从chat_id处接收到包含hello消息后，要做的事情
@jdbot.on(events.NewMessage(from_users=users,pattern=(r'^/chart')))
#定义自己的函数名称
async def hi(event):
    msg_text = event.raw_text.split(' ')
    chat_id = event.sender_id
    msg = await jdbot.send_message(chat_id, '🕙 正在查询，请稍后...')
    try:
        if isinstance(msg_text, list) and len(msg_text) == 2:
            text = msg_text[-1]
        else:
            text = None
        if text and int(text):
            res = get_bean_data(int(text))
            if res['code'] != 200:
                logger.error("data error")
                await jdbot.send_message(chat_id,"序号不存在或单次请求过多")
            else:
                aver = round((res["data"][0][0]+res["data"][0][1]+res["data"][0][2]+res["data"][0][3]+res["data"][0][4]+res["data"][0][5]+res["data"][0][6])/7,2)
                createChart(res['data'][0],res['data'][1],res['data'][3])
                logger.info("Start create image")
                if(res['data'][5]!='/images/html5/newDefaul.png'):
                    createpic(res['data'][4],res['data'][2][-1],res['data'][5])
                else:
                    createpic(res['data'][4],res['data'][2][-1])
                logger.info("ok")
                await msg.delete()
                result = await jdbot.send_message(chat_id,f'近七天平均收入{aver}豆⚡',file=BEAN_IMG)
                #time.sleep(period)
                #await result.delete()
        else:
            await jdbot.send_message(chat_id, '请正确使用命令\n/dou n n为第n个账号')
    except Exception as e:
        logger.error(str(e))
        line = e.__traceback__.tb_lineno 
        await jdbot.send_message(chat_id,"错误类型：" + str(e)+f'\n错误发生在第{line}行')
        logger.error(f'错误发生在第{line}行')
