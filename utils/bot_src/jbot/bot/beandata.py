import requests, datetime, time, json
from datetime import timedelta, timezone
from asyncio import sleep
from .. import jdbot, chat_id
from .utils import CONFIG_SH_FILE, get_cks, logger
SHA_TZ = timezone(
    timedelta(hours=8),
    name='Asia/Shanghai',
)
requests.adapters.DEFAULT_RETRIES = 5
session = requests.session()

url = "https://api.m.jd.com/client.action"
SIGN_API = "https://api.nolanstore.top/sign"

def gen_body(page):
    body = {
        "page": str(page),
        "pageSize": "20",
    }
    return body


def gen_params(page):
    body = gen_body(page)
    params = {
        "functionId": "getJingBeanBalanceDetail",
        "appid": "ld",
        "body": json.dumps(body)
    }
    return params


async def get_beans_7days(ck):
    try:
        day_7 = True
        functionId = "getJingBeanBalanceDetail"
        page = 0
        headers = {
            "Host": "api.m.jd.com",
            "Connection": "keep-alive",
            "User-Agent": "jdapp;iPhone;9.4.4;14.3;network/4g;Mozilla/5.0 (iPhone; CPU iPhone OS 14_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148;supportJDSHWK/1",
            "Content-Type": "application/x-www-form-urlencoded",
            "Accept-Encoding": "gzip,deflate",
            'Accept-Charset': 'UTF-8',
            "Cookie": ck,
        }
        days = []
        for i in range(0, 7):
            days.append(
                (datetime.date.today() - datetime.timedelta(days=i)).strftime("%Y-%m-%d"))
        beans_in = {key: 0 for key in days}
        beans_out = {key: 0 for key in days}
        while day_7:
            page = page + 1
            signBody = get_sign(functionId, gen_body(page))
            logger.info(signBody)
            res = requests.post(url=url + '?functionId=getJingBeanBalanceDetail&' + signBody, headers=headers)
            await sleep(1)
            if res.status_code == 200:
                res = res.json()
            else:
                return {'code': 400, 'data': 'API Response Status_Code with' + str(res.status_code)}
            logger.info(res)
            if res['code'] == '0':
                for i in res['detailList']:
                    for date in days:
                        if str(date) in i['date'] and int(i['amount']) > 0:
                            beans_in[str(date)] = beans_in[str(
                                date)] + int(i['amount'])
                            break
                        elif str(date) in i['date'] and int(i['amount']) < 0:
                            beans_out[str(date)] = beans_out[str(
                                date)] + int(i['amount'])
                            break
                    if i['date'].split(' ')[0] not in str(days):
                        day_7 = False
            else:
                return {'code': 400, 'data': res}
        days = list(map(lambda x: x[5:], days))
        return {'code': 200, 'data': [beans_in, beans_out, days]}
    except Exception as e:
        errorMsg = f"❌ 第{e.__traceback__.tb_lineno}行：{e}"
        logger.error(errorMsg)
        return {'code': 400, 'data': str(errorMsg)}

def get_total_beans(ck):
    try:
        headers = {
            "Host": "me-api.jd.com",
            "Connection": "keep-alive",
            "User-Agent": "Mozilla/5.0 (Linux; Android 10; MI 9 Build/QKQ1.190825.002; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/78.0.3904.62 XWEB/2797 MMWEBSDK/201201 Mobile Safari/537.36 MMWEBID/7986 MicroMessenger/8.0.1840(0x2800003B) Process/appbrand4 WeChat/arm64 Weixin NetType/4G Language/zh_CN ABI/arm64 MiniProgramEnv/android",
            "Content-Type": "application/x-www-form-urlencoded;",
            "Accept-Encoding": "gzip,deflate",
            "Cookie": ck,
        }
        jurl = "https://me-api.jd.com/user_new/info/GetJDUserInfoUnion"
        resp = session.get(jurl, headers=headers, timeout=100).text
        res = json.loads(resp)
        return res['data']['assetInfo']['beanNum'], res['data']['userInfo']['baseInfo']['nickname'], res['data']['userInfo']['baseInfo']['headImageUrl']
    except Exception as e:
        logger.error(str(e))


async def get_bean_data(i):
    try:
        ckfile = CONFIG_SH_FILE
        cookies = get_cks(ckfile)
        if cookies:
            ck = cookies[i-1]
            beans_res = await get_beans_7days(ck)
            beantotal, nickname, pic = get_total_beans(ck)
            if beans_res['code'] != 200:
                return beans_res
            else:
                beans_in, beans_out = [], []
                beanstotal = [int(beantotal), ]
                for i in beans_res['data'][0]:
                    beantotal = int(
                        beantotal) - int(beans_res['data'][0][i]) - int(beans_res['data'][1][i])
                    beans_in.append(int(beans_res['data'][0][i]))
                    beans_out.append(
                        int(str(beans_res['data'][1][i]).replace('-', '')))
                    beanstotal.append(beantotal)
            return {'code': 200, 'data': [beans_in[::-1], beans_out[::-1], beanstotal[::-1], beans_res['data'][2][::-1], nickname, pic]}
    except Exception as e:
        logger.error(str(e))
        return {"code": 400}

def get_sign(fn, body):
    try:
        data = {
            "fn": fn,
            "body": body
        }
        headers = {
            "Content-Type": "application/json",
        }
        res = session.post(url=SIGN_API, headers=headers, json=data, timeout=30000).json()
        logger.info(res)
        return res['body']
    except Exception as e:
        logger.error(str(e))