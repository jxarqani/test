import re,os,datetime,asyncio
from functools import wraps
from telethon import events, Button
from .. import jdbot, chat_id, LOG_DIR, logger, JD_DIR, OWN_DIR, CONFIG_DIR, BOT_SET

row = int(BOT_SET['每页列数'])
CRON_FILE = f'{CONFIG_DIR}/crontab.list'
BEAN_LOG_DIR = f'{LOG_DIR}/jd_bean_change/'
CONFIG_SH_FILE = f'{CONFIG_DIR}/config.sh'
DIY_DIR = OWN_DIR
TASK_CMD = 'task'


def get_cks(ckfile):
    ck_reg = re.compile(r'pt_key=\S*?;.*?pt_pin=\S*?;')
    with open(ckfile, 'r', encoding='utf-8') as f:
        lines = f.read()
    cookies = ck_reg.findall(lines)
    for ck in cookies:
        if ck == 'pt_key=xxxxxxxxxx;pt_pin=xxxx;':
            cookies.remove(ck)
            break
    return cookies


def split_list(datas, n, row: bool = True):
    """一维列表转二维列表，根据N不同，生成不同级别的列表"""
    length = len(datas)
    size = length / n + 1 if length % n else length/n
    _datas = []
    if not row:
        size, n = n, size
    for i in range(int(size)):
        start = int(i * n)
        end = int((i + 1) * n)
        _datas.append(datas[start:end])
    return _datas


def backup_file(file):
    '''如果文件存在，则备份，并更新'''
    if os.path.exists(file):
        try:
            os.rename(file, f'{file}.bak')
        except WindowsError:
            os.remove(f'{file}.bak')
            os.rename(file, f'{file}.bak')


def press_event(user_id):
    return events.CallbackQuery(func=lambda e: e.sender_id == user_id)

def reContent_INVALID(text):
    replaceArr = ['_', '*', '~']
    for i in replaceArr:
        t = ''
        for a in range(5):
            t += i
        text = re.sub('\%s{6,}' % i, t, text)
    return text

async def cmd(cmdtext):
    '''定义执行cmd命令'''
    try:
        msg = await jdbot.send_message(chat_id, '开始执行命令')
        p = await asyncio.create_subprocess_shell(
            cmdtext + "| sed 's/\[3[0-9]m//g; s/\[4[0-9];3[0-9]m//g; s/\[[0-1]m//g'", stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
        res_bytes, res_err = await p.communicate()
        res = res_bytes.decode('utf-8')
        res = reContent_INVALID(res)
        if len(res) == 0:
            await jdbot.edit_message(msg, '已执行命令但返回值为空，可能遇到了某些错误～')
        elif len(res) <= 2000:
            await jdbot.delete_messages(chat_id, msg)
            await jdbot.send_message(chat_id, res)
        elif len(res) > 2000:
            tmp_log = f'{LOG_DIR}/bot/{cmdtext.split("/")[-1].split(".js")[0]}-{datetime.datetime.now().strftime("%H-%M-%S")}.log'
            with open(tmp_log, 'w+', encoding='utf-8') as f:
                f.write(res)
            await jdbot.delete_messages(chat_id, msg)
            await jdbot.send_message(chat_id, '✅ 执行结果较长，具体请查看日志', file=tmp_log)
            os.remove(tmp_log)
    except Exception as e:
        await jdbot.send_message(chat_id, f'something wrong,I\'m sorry\n{str(e)}')
        logger.error(f'something wrong,I\'m sorry\n{str(e)}')


def get_ch_names(path, dir):
    '''获取文件中文名称，如无则返回文件名'''
    file_ch_names = []
    reg = r'new Env\(\'[\S]+?\'\)'
    ch_name = False
    for file in dir:
        try:
            if os.path.isdir(f'{path}/{file}'):
                file_ch_names.append(file)
            elif file.endswith('.js') and file != 'jdCookie.js' and file != 'getJDCookie.js' and file != 'JD_extra_cookie.js' and 'ShareCode' not in file:
                with open(f'{path}/{file}', 'r', encoding='utf-8') as f:
                    lines = f.readlines()
                for line in lines:
                    if 'new Env' in line:
                        line = line.replace('\"', '\'')
                        res = re.findall(reg, line)
                        if len(res) != 0:
                            res = res[0].split('\'')[-2]
                            file_ch_names.append(f'{res}--->{file}')
                            ch_name = True
                        break
                if not ch_name:
                    file_ch_names.append(f'{file}--->{file}')
                    ch_name = False
            else:
                continue
        except:
            continue
    return file_ch_names


async def log_btn(conv, sender, path, msg, page, files_list):
    '''定义log日志按钮'''
    my_btns = [Button.inline('上一页', data='up'), Button.inline(
        '下一页', data='next'), Button.inline('上级', data='updir'), Button.inline('取消', data='cancel')]
    try:
        if files_list:
            markup = files_list
            new_markup = markup[page]
            if my_btns not in new_markup:
                new_markup.append(my_btns)
        else:
            dir = os.listdir(path)
            dir.sort()
            if path == LOG_DIR:
                markup = [Button.inline("_".join(file.split("_")[-2:]), data=str(file))
                          for file in dir]
            elif os.path.dirname(os.path.realpath(path)) == LOG_DIR:
                markup = [Button.inline("-".join(file.split("-")[-5:]), data=str(file))
                          for file in dir]
            else:
                markup = [Button.inline(file, data=str(file))
                          for file in dir]
            markup = split_list(markup, row)
            if len(markup) > 30:
                markup = split_list(markup, 30)
                new_markup = markup[page]
                new_markup.append(my_btns)
            else:
                new_markup = markup
                if path == JD_DIR:
                    new_markup.append([Button.inline('取消', data='cancel')])
                else:
                    new_markup.append(
                        [Button.inline('上级', data='updir'), Button.inline('取消', data='cancel')])
        msg = await jdbot.edit_message(msg, '请做出您的选择：', buttons=new_markup)
        convdata = await conv.wait_event(press_event(sender))
        res = bytes.decode(convdata.data)
        if res == 'cancel':
            msg = await jdbot.edit_message(msg, '对话已取消')
            conv.cancel()
            return None, None, None, None
        elif res == 'next':
            page = page + 1
            if page > len(markup) - 1:
                page = 0
            return path, msg, page, markup
        elif res == 'up':
            page = page - 1
            if page < 0:
                page = len(markup) - 1
            return path, msg, page, markup
        elif res == 'updir':
            path = '/'.join(path.split('/')[:-1])
            if path == '':
                path = JD_DIR
            return path, msg, page, None
        elif os.path.isfile(f'{path}/{res}'):
            msg = await jdbot.edit_message(msg, '文件发送中，请注意查收')
            await conv.send_file(f'{path}/{res}')
            msg = await jdbot.edit_message(msg, f'{res}发送成功，请查收')
            conv.cancel()
            return None, None, None, None
        else:
            return f'{path}/{res}', msg, page, None
    except asyncio.exceptions.TimeoutError:
        msg = await jdbot.edit_message(msg, '选择已超时，本次对话已停止')
        return None, None, None, None
    except Exception as e:
        msg = await jdbot.edit_message(msg, f'something wrong,I\'m sorry\n{str(e)}')
        logger.error(f'something wrong,I\'m sorry\n{str(e)}')
        return None, None, None, None


async def snode_btn(conv, sender, path, msg, page, files_list):
    '''定义scripts脚本按钮'''
    my_btns = [Button.inline('上一页', data='up'), Button.inline(
        '下一页', data='next'), Button.inline('上级', data='updir'), Button.inline('取消', data='cancel')]
    try:
        if files_list:
            markup = files_list
            new_markup = markup[page]
            if my_btns not in new_markup:
                new_markup.append(my_btns)
        else:
            dir = ['scripts', OWN_DIR.split('/')[-1]]
            dir.sort()
            markup = [Button.inline(file.split('--->')[0], data=str(file.split('--->')[-1]))
                      for file in dir if os.path.isdir(f'{path}/{file}') or file.endswith('.js')]
            markup = split_list(markup, row)
            if len(markup) > 30:
                markup = split_list(markup, 30)
                new_markup = markup[page]
                new_markup.append(my_btns)
            else:
                new_markup = markup
                if path == JD_DIR:
                    new_markup.append([Button.inline('取消', data='cancel')])
                else:
                    new_markup.append(
                        [Button.inline('上级', data='updir'), Button.inline('取消', data='cancel')])
        msg = await jdbot.edit_message(msg, '请做出您的选择：', buttons=new_markup)
        convdata = await conv.wait_event(press_event(sender))
        res = bytes.decode(convdata.data)
        if res == 'cancel':
            msg = await jdbot.edit_message(msg, '对话已取消')
            conv.cancel()
            return None, None, None, None
        elif res == 'next':
            page = page + 1
            if page > len(markup) - 1:
                page = 0
            return path, msg, page, markup
        elif res == 'up':
            page = page - 1
            if page < 0:
                page = len(markup) - 1
            return path, msg, page, markup
        elif res == 'updir':
            path = '/'.join(path.split('/')[:-1])
            if path == '':
                path = JD_DIR
            return path, msg, page, None
        elif os.path.isfile(f'{path}/{res}'):
            conv.cancel()
            logger.info(f'{path}/{res} 脚本即将在后台运行')
            msg = await jdbot.edit_message(msg, f'{res} 在后台运行成功')
            cmdtext = f'{TASK_CMD} {path}/{res} now'
            return None, None, None, f'CMD-->{cmdtext}'
        else:
            return f'{path}/{res}', msg, page, None
    except asyncio.exceptions.TimeoutError:
        msg = await jdbot.edit_message(msg, '选择已超时，对话已停止')
        return None, None, None, None
    except Exception as e:
        msg = await jdbot.edit_message(msg, f'something wrong,I\'m sorry\n{str(e)}')
        logger.error(f'something wrong,I\'m sorry\n{str(e)}')
        return None, None, None, None


def mycron(lines):
    cronreg = re.compile(r'([0-9\-\*/,]{1,} ){4,5}([0-9\-\*/,]){1,}')
    return cronreg.search(lines).group()


async def add_cron(jdbot, conv, resp, filename, msg, sender, markup, path):
    try:
        crondata = f'{mycron(resp)} task {path}/{filename}'
        msg = await jdbot.edit_message(msg, f'已识别定时\n```{crondata}```\n是否需要修改', buttons=markup)
    except:
        crondata = f'0 0 * * * task {path}/{filename}'
        msg = await jdbot.edit_message(msg, f'未识别到定时，默认定时\n```{crondata}```\n是否需要修改', buttons=markup)
    convdata3 = await conv.wait_event(press_event(sender))
    res3 = bytes.decode(convdata3.data)
    if res3 == 'yes':
        convmsg = await conv.send_message(f'```{crondata}```\n请输入您要修改内容，可以直接点击上方定时进行复制修改\n如果需要取消，请输入`cancel`或`取消`')
        crondata = await conv.get_response()
        crondata = crondata.raw_text
        if crondata == 'cancel' or crondata == '取消':
            conv.cancel()
            await jdbot.send_message(chat_id, '对话已取消')
            return
        await jdbot.delete_messages(chat_id, convmsg)
    await jdbot.delete_messages(chat_id, msg)

    owninfo = '# 用户定时任务区'
    with open(CRON_FILE, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    for line in lines:
        if owninfo in line:
            i = lines.index(line)
            lines.insert(i + 4, crondata+'\n')
            break
    with open(CRON_FILE, 'w', encoding='utf-8') as f:
        f.write(''.join(lines))

    await jdbot.send_message(chat_id, f'{filename}已保存到{path}，并已尝试添加定时任务')


def cron_manage_api(fun, crondata):
    file = f'{CONFIG_DIR}/crontab.list'
    with open(file, 'r', encoding='utf-8') as f:
        crons = f.readlines()
    try:
        if fun == 'search':
            res = {'code': 200, 'data': {}}
            for cron in crons:
                if str(crondata) in cron:
                    res['data'][cron.split(
                        'task ')[-1].split(' ')[0].split('/')[-1].replace('\n', '')] = cron
        elif fun == 'add':
            crons.append(crondata)
            res = {'code': 200, 'data': 'success'}
        elif fun == 'run':
            cmd(f'task {crondata.split("task")[-1]}')
            res = {'code': 200, 'data': 'success'}
        elif fun == 'edit':
            ocron, ncron = crondata.split('-->')
            i = crons.index(ocron)
            crons.pop(i)
            crons.insert(i, ncron)
            res = {'code': 200, 'data': 'success'}
        elif fun == 'disable':
            i = crons.index(crondata)
            crondatal = list(crondata)
            crondatal.insert(0, '#')
            ncron = ''.join(crondatal)
            crons.pop(i)
            crons.insert(i, ncron)
            res = {'code': 200, 'data': 'success'}
        elif fun == 'enable':
            i = crons.index(crondata)
            ncron = crondata.replace('#', '')
            crons.pop(i)
            crons.insert(i, ncron)
            res = {'code': 200, 'data': 'success'}
        elif fun == 'del':
            i = crons.index(crondata)
            crons.pop(i)
            res = {'code': 200, 'data': 'success'}
        else:
            res = {'code': 400, 'data': '未知功能'}
        with open(file, 'w', encoding='utf-8') as f:
            f.write(''.join(crons))
    except Exception as e:
        res = {'code': 400, 'data': str(e)}
    finally:
        return res


def cron_manage(fun, crondata, token):
    res = cron_manage_api(fun, crondata)
    return res

