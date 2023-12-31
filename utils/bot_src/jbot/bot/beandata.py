import requests
import datetime
import time
import json
from datetime import timedelta
from datetime import timezone
from .utils import CONFIG_SH_FILE, get_cks, logger
SHA_TZ = timezone(
    timedelta(hours=8),
    name='Asia/Shanghai',
)
requests.adapters.DEFAULT_RETRIES = 5
session = requests.session()
session.keep_alive = False

url = "https://bean.m.jd.com/beanDetail/detail.json"

# def gen_body(page):
#     body = {
#         "page": str(page),
#         "pageSize": "20",
#     }
#     return body


# def gen_params(page):
#     body = gen_body(page)
#     params = {
#         "functionId": "getJingBeanBalanceDetail",
#         "appid": "ld",
#         "body": json.dumps(body)
#     }
#     return params


def get_beans_7days(ck):
    try:
        day_7 = True
        page = 0
        headers = {
            # "Host": "api.m.jd.com",
            # "Connection": "keep-alive",
            "User-Agent": "Mozilla/5.0 (Linux; Android 12; SM-G9880) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 Mobile Safari/537.36 EdgA/106.0.1370.47",
            # "Content-Type": "application/x-www-form-urlencoded",
            "Accept-Encoding": "gzip,deflate",
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
            res = session.get(url=url + '?page=' + str(page), headers=headers).json()
            # logger.info(res)
            if res['code'] == '0':
                for i in res['jingDetailList']:
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
        logger.error(str(e))
        return {'code': 400, 'data': str(e)}

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


def get_bean_data(i):
    try:
        ckfile = CONFIG_SH_FILE
        cookies = get_cks(ckfile)
        if cookies:
            ck = cookies[i-1]
            beans_res = get_beans_7days(ck)
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