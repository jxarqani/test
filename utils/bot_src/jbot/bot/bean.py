from PIL import Image, ImageFont, ImageDraw
from telethon import events
from .. import LOG_DIR, jdbot, chat_id, BOT_SET, BOT_DIR, logger, ch_name
from prettytable import PrettyTable
import subprocess
from .beandata import get_bean_data

BEAN_IN_FILE = f'{LOG_DIR}/bean_income.csv'
BEAN_OUT_FILE = f'{LOG_DIR}/bean_outlay.csv'
BEAN_TOTAL_FILE = f'{LOG_DIR}/bean_total.csv'
BEAN_IMG = f'{LOG_DIR}/bean.jpg'
FONT_FILE = f'{BOT_DIR}/font/jet.ttf'


@jdbot.on(events.NewMessage(chats=chat_id, pattern=r'^/bean'))
async def bot_bean(event):
    msg_text = event.raw_text.split(' ')
    try:
        msg = await jdbot.send_message(chat_id, '🕙 正在查询，请稍后...')
        if isinstance(msg_text, list) and len(msg_text) == 2:
            text = msg_text[-1]
        else:
            text = None
        if text == 'in':
            subprocess.check_output(
                'jcsv', shell=True, stderr=subprocess.STDOUT)
            creat_bean_counts(BEAN_IN_FILE)
            await jdbot.delete_messages(chat_id, msg)
            await jdbot.send_message(chat_id, '您的近日收入情况', file=BEAN_IMG)
        elif text == 'out':
            subprocess.check_output(
                'jcsv', shell=True, stderr=subprocess.STDOUT)
            creat_bean_counts(BEAN_OUT_FILE)
            await jdbot.delete_messages(chat_id, msg)
            await jdbot.send_message(chat_id, '您的近日支出情况', file=BEAN_IMG)
        elif text and int(text):
            res = get_bean_data(int(text))
            if res['code'] != 200:
                await jdbot.delete_messages(chat_id, msg)
                await jdbot.send_message(chat_id, f'something wrong,I\'m sorry\n{str(res["data"])}')
            else:
                creat_bean_count(res['data'][3], res['data']
                                 [0], res['data'][1], res['data'][2][1:])
                await jdbot.delete_messages(chat_id, msg)
                await jdbot.send_message(chat_id, f'您的账号{text}收支情况', file=BEAN_IMG)
        elif not text:
            subprocess.check_output(
                'jcsv', shell=True, stderr=subprocess.STDOUT)
            creat_bean_counts(BEAN_TOTAL_FILE)
            await jdbot.delete_messages(chat_id, msg)
            await jdbot.send_message(chat_id, '您的总京豆情况', file=BEAN_IMG)
        else:
            await jdbot.delete_messages(chat_id, msg)
            await jdbot.send_message(chat_id, '暂仅支持/bean n n为账号数字')
    except Exception as e:
        await jdbot.send_message(chat_id, f'something wrong,I\'m sorry\n{str(e)}')
        logger.error(f'something wrong,I\'m sorry{str(e)}')

if ch_name:
    jdbot.add_event_handler(bot_bean, events.NewMessage(
        chats=chat_id, pattern=BOT_SET['命令别名']['bean']))


def creat_bean_count(date, beansin, beansout, beanstotal):
    tb = PrettyTable()
    tb.add_column('DATE', date)
    tb.add_column('BEANSIN', beansin)
    tb.add_column('BEANSOUT', beansout)
    tb.add_column('TOTAL', beanstotal)
    font = ImageFont.truetype(FONT_FILE, 18)
    im = Image.new("RGB", (500, 260), (244, 244, 244))
    dr = ImageDraw.Draw(im)
    dr.text((10, 5), str(tb), font=font, fill="#000000")
    im.save(BEAN_IMG)


def creat_bean_counts(csv_file):
    with open(csv_file, 'r', encoding='utf-8') as f:
        data = f.readlines()
    tb = PrettyTable()
    num = len(data[-1].split(',')) - 1
    title = ['DATE']
    for i in range(0, num):
        title.append('COUNT'+str(i+1))
    tb.field_names = title
    data = data[-7:]
    for line in data:
        row = line.split(',')
        if len(row) > len(title):
            row = row[:len(title)]
        elif len(row) < len(title):
            i = len(title) - len(row)
            for _ in range(0, i):
                row.append(str(0))
        tb.add_row(row)
    length = 172 + 100 * num
    im = Image.new("RGB", (length, 400), (244, 244, 244))
    dr = ImageDraw.Draw(im)
    font = ImageFont.truetype(FONT_FILE, 18)
    dr.text((10, 5), str(tb), font=font, fill="#000000")
    im.save(BEAN_IMG)
