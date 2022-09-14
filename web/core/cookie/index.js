const got = require('got');
const util = require("../../utils");
const {CONFIG_FILE_KEY, getFile, saveNewConf} = require("../file");

/**
 * 初始化CK
 * @param ptKey
 * @param ptPin
 * @param phone
 * @param lastUpdateTime
 * @param remark
 * @param id
 * @returns {{}}
 * @constructor
 */
function CookieObj(id = 0, ptKey, ptPin, lastUpdateTime = util.dateFormat("YYYY-mm-dd HH:MM:SS", new Date()), remark = '无', phone = '无') {
    this.id = id;
    this.ptKey = ptKey;
    this.ptPin = ptPin;
    this.phone = phone;
    this.lastUpdateTime = lastUpdateTime;
    this.remark = remark;
    this.cookieStr = () => {
        return `Cookie${this.id}="pt_key=${this.ptKey};pt_pin=${this.ptPin};"`;
    };
    this.tipStr = () => {
        return `## pt_pin=${this.ptPin};  联系方式：${this.phone};  上次更新：${this.lastUpdateTime};  备注：${this.remark};`;
    };

    this.convert = (cookie, tips, phone = '无') => {
        if (cookie.indexOf("Cookie") > -1) {
            this.id = parseInt(util.regExecFirst(cookie, /(?<=Cookie)([^=]+)/));
        } else {
            this.id = 0;
        }
        this.ptKey = util.regExecFirst(cookie, /(?<=pt_key=)([^;]+)/)
        this.ptPin = util.regExecFirst(cookie, /(?<=pt_pin=)([^;]+)/)
        if (tips && tips.indexOf("上次更新") > 0) {
            this.lastUpdateTime = util.regExecFirst(tips, /(?<=上次更新：)([^;]+)/);
            if(this.lastUpdateTime.length > 19){
                this.lastUpdateTime =  this.lastUpdateTime.substring(0,19);
            }
            this.phone = util.regExecFirst(tips, /(?<=联系方式：)([^;]+)/);
            this.remark = util.regExecFirst(tips, /(?<=备注：)([^;]+)/);
        } else {
            this.lastUpdateTime = util.dateFormat("YYYY-mm-dd HH:MM:SS", new Date());
            this.remark = tips;
            this.phone = phone;
        }
        return this;
    }

    return this;
}

/**
 * 读取本地config.sh中的cookie
 * @returns {*[]}
 */
function readCookies() {
    const content = getFile(CONFIG_FILE_KEY.CONFIG);
    const lines = content.split('\n');
    let cookieList = [];
    for (let i = 0; i < lines.length; i++) {
        let line = lines[i];
        if (line.startsWith('Cookie')) {
            try {
                let tips = lines[i + 1];
                cookieList.push(new CookieObj(i).convert(line, tips))
            } catch (e) {
                console.error(`${i + 1}行Cookie读取失败，请检查Cookie或Cookie下方的备注是否有误！`)
            }
        }
    }
    return cookieList;
}

/**
 * 将Cookie数组保存至本地Config.sh
 * @returns {*[]}
 */
function saveCookiesToConfig(cookieList = []) {
    const content = getFile(CONFIG_FILE_KEY.CONFIG);
    const lines = content.split('\n');
    //写入的下标
    let writeIndex = 0, id = 1, over = false;
    for (let i = 0; i < lines.length; i++) {
        let line = lines[i];
        if (over && (line.startsWith('Cookie') || line.startsWith('## pt_pin'))) {
            lines.splice(i, 1);
            i--;
            continue;
        }
        if (line.startsWith('Cookie')) {
            writeIndex = i;
            cookieList.forEach(item => {
                if (item.id === 0) {
                    item.id = id;
                    //说明该CK为新增的CK
                    if (lines[writeIndex].startsWith("Cookie")) {
                        //说明此次保存存在CK删除，当前CK直接覆盖
                        lines[writeIndex] = item.cookieStr();
                        writeIndex++;
                        lines[writeIndex] = item.tipStr();
                        writeIndex++;
                    } else {
                        lines.splice(writeIndex, 0, item.cookieStr(), item.tipStr());
                        writeIndex = writeIndex + 2;
                    }
                } else {
                    item.id = id;
                    lines[writeIndex] = item.cookieStr();
                    writeIndex++;
                    lines[writeIndex] = item.tipStr();
                    writeIndex++;
                }
                id++;
            })
            over = true;
            i = writeIndex - 1;
        }
    }
    saveNewConf(CONFIG_FILE_KEY.CONFIG, lines.join('\n'));
    return cookieList;
}

/**
 * 判断CK自动添加是否开启
 */
function ckAutoAddOpen() {
    let CK_AUTO_ADD = 'false'
    const content = getFile(CONFIG_FILE_KEY.CONFIG);
    if (content.match(/CK_AUTO_ADD=".+?"/)) {
        CK_AUTO_ADD = content.match(/CK_AUTO_ADD=".+?"/)[0].split('"')[1]
    }
    return CK_AUTO_ADD && CK_AUTO_ADD === 'true';
}

/**
 * 获取账号
 * @return
 */
function getAccount() {
    let accounts = JSON.parse(getFile(CONFIG_FILE_KEY.ACCOUNT)) || []
    accounts = accounts.filter((item) => {
        return util.isNotEmpty(item.pt_pin) && util.isNotEmpty(item.ws_key)
    })
    return accounts;
}

/**
 * 获取cookie数量
 * @return {{accountCount: number, cookieCount: number}}
 */
function getCount() {
    return {cookieCount: readCookies().length, accountCount: getAccount().length};
}

/**
 * 删除指定CK
 * @param ptPins 一个或者多个ptPins
 * @return {{accountCount: number, cookieCount: number, deleteCount: number}}
 */
function removeCookie(ptPins) {
    if (typeof ptPins === 'string') {
        ptPins = [ptPins];
    }
    let cookieList = readCookies();
    let deleteCount = 0
    if (ptPins && ptPins.length > 0) {
        for (let i = 0; i < cookieList.length; i++) {
            let cookieObj = cookieList[i];
            if (ptPins.indexOf(cookieObj.ptPin) > -1) {
                cookieList.splice(i, 1);
                deleteCount++;
            }
        }
    } else {
        throw new Error("传入的ptPin不能为空")
    }
    saveCookiesToConfig(cookieList);
    return {...getCount(), deleteCount};
}

/**
 * 更新ck
 * @param ck pt_key=xxx;pt_pin=xxx;
 * @param remarks 备注
 * @param phone 联系方式
 * @return {number} ck数量
 */
function updateCookie({ck, remarks, phone}) {
    let cookieList = readCookies();
    let cookieObj = new CookieObj().convert(ck, remarks, phone);
    let isUpdate = false;
    cookieList.forEach((item) => {
        if (item.ptPin === cookieObj.ptPin) {
            isUpdate = true;
            //更新ptKey
            item.ptKey = cookieObj.ptKey;
            item.lastUpdateTime = cookieObj.lastUpdateTime;
            if (remarks) {
                item.remark = remarks;
            }
            if (phone) {
                item.phone = phone;
            }
        }
    })
    if (!isUpdate) {
        if (!ckAutoAddOpen()) {
            throw new Error(`添加 Cookie 失败，当前服务器已关闭自动添加`);
        } else {
            !remarks && (cookieObj.remark = '无');
            //新增CK
            cookieList.push(cookieObj)
        }
    }
    cookieList = saveCookiesToConfig(cookieList);

    // 打印日志
    var UpdateTime = util.dateFormat("YYYY-mm-dd HH:MM:SS", new Date());
    var remark_tmp = '';
    if (remarks) remark_tmp += ` · ${remarks}`;
    if (phone) remark_tmp += ` · ${phone}`;
    if (isUpdate) {
        console.log(`[${UpdateTime}] - 更新账号(Cookie) => ${cookieObj.ptPin}${remark_tmp}`);
    } else {
        console.log(`[${UpdateTime}] - 新增账号(Cookie) => ${cookieObj.ptPin}${remark_tmp}`);
    }

    return cookieList.length;
}

function updateAccount({ptPin, ptKey, wsKey, remarks, phone}) {
    if (!util.isNotEmpty(ptPin)) {
        throw new Error("ptPin不能为空")
    }
    if (!util.isNotEmpty(wsKey) && !util.isNotEmpty(ptKey)) {
        throw new Error("账号不能为空")
    }
    if (ptPin === '%2A%2A%2A%2A%2A%2A') {
        throw new Error("ptPin不正确")
    }
    if (util.isNotEmpty(ptKey)) {
        updateCookie({ck: `pt_key=${ptKey};pt_pin=${ptPin};`, remarks, phone});
    }
    if (util.isNotEmpty(wsKey)) {
        let accounts = getAccount(), isUpdate = false;
        accounts.forEach((account, index) => {
            if (account['pt_pin'] && account['pt_pin'] === ptPin) {
                account['ws_key'] = wsKey || '';
                if (remarks) {
                    account['remarks'] = remarks;
                }
                if (phone) {
                    account['phone'] = phone;
                }
                isUpdate = true;
            }
        })
        if (!isUpdate) {
            remarks = remarks || ptPin;
            accounts.push({
                "pt_pin": ptPin,
                "ws_key": wsKey,
                "remarks": remarks,
                "phone": phone
            })
        }
        saveAccount(accounts);

        // 打印日志
        var UpdateTime = util.dateFormat("YYYY-mm-dd HH:MM:SS", new Date());
        var remark_tmp = '';
        if (remarks) remark_tmp += ` · ${remarks}`;
        if (phone) remark_tmp += ` · ${phone}`;
        if (isUpdate) {
            console.log(`[${UpdateTime}] - 更新账号(wskey) => ${ptPin}${remark_tmp}`);
        } else {
            console.log(`[${UpdateTime}] - 新增账号(wskey) => ${ptPin}${remark_tmp}`);
        }

    }
    return getCount();
}

/**
 * 保存账号到文件
 * @param accounts
 */
function saveAccount(accounts = []) {
    saveNewConf(CONFIG_FILE_KEY.ACCOUNT, JSON.stringify(accounts, null, 2))
}

/**
 * 检测账号是否有效（pt_key or wskey）
 * 无需提供 pt_pin
 * @param  ck pt_key=xxx; 或 wskey=xxx;
 */
async function checkCookieSatus(ck) {
    res = await got.get('https://me-api.jd.com/user_new/info/GetJDUserInfoUnion', {
        method: 'get',
        headers: {
            'content-type': 'application/x-www-form-urlencoded',
            cookie: ck,
        }
    });
    data = res.body;
    return data
};

module.exports = {
    CookieObj,
    getCount,
    readCookies,
    saveCookiesToConfig,
    updateAccount,
    updateCookie,
    removeCookie,
    getAccount,
    saveAccount,
    checkCookieSatus
}
