const util = require("../../utils");
const {CONFIG_FILE_KEY, getFile, saveNewConf} = require("../file");

/**
 * 初始化CK
 * @param ptKey
 * @param ptPin
 * @param lastUpdateTime
 * @param remark
 * @param id
 * @returns {{}}
 * @constructor
 */
function CookieObj(id = 0, ptKey, ptPin, lastUpdateTime = util.dateFormat("YYYY-mm-dd HH:MM:SS", new Date()), remark = '无') {
    this.id = id;
    this.ptKey = ptKey;
    this.ptPin = ptPin
    this.lastUpdateTime = lastUpdateTime;
    this.remark = remark;
    this.cookieStr = () => {
        return `Cookie${this.id}="pt_key=${this.ptKey};pt_pin=${this.ptPin};"`;
    };
    this.tipStr = () => {
        return `## pt_pin=${this.ptPin}; 上次更新：${this.lastUpdateTime} 备注：${this.remark}`;
    };

    this.convert = (cookie, tips) => {
        if (cookie.indexOf("Cookie") > 0) {
            this.id = parseInt(/(?<=Cookie)([^=]+)/.exec(cookie)[0]);
        } else {
            this.id = 0;
        }
        this.ptKey = /(?<=pt_key=)([^;]+)/.exec(cookie)[0]
        this.ptPin = /(?<=pt_pin=)([^;]+)/.exec(cookie)[0]
        if (tips && tips.indexOf("上次更新") > 0) {
            this.lastUpdateTime = /(?<=上次更新：)([^;]+(\s))/.exec(tips)[0];
            this.remark = /(?<=备注：)([^;]+)/.exec(tips)[0];
        } else {
            this.lastUpdateTime = util.dateFormat("YYYY-mm-dd HH:MM:SS", new Date());
            this.remark = tips;

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
                console.error(`${i}行Cookie读取失败，请检查Cookie或Cookie下方的备注是否有误！`)
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
                        writeIndex++
                    } else {
                        lines.splice(writeIndex, 0, item.cookieStr(), item.tipStr());
                        writeIndex = writeIndex + 2;
                    }
                } else {
                    item.id = id;
                    lines[writeIndex] = item.cookieStr();
                    writeIndex++;
                    lines[writeIndex] = item.tipStr();
                    writeIndex++
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
 * @return T[]
 */
function getAccount() {
    let accounts = JSON.parse(getFile(CONFIG_FILE_KEY.ACCOUNT)) || []
    return accounts.filter((item) => {
        return util.isNotEmpty(item.pt_pin) && util.isNotEmpty(item.ws_key)
    })
}

/**
 * 获取cookie数量
 * @return {{accountCount: number, cookieCount: number}}
 */
function getCount() {
    return {cookieCount: readCookies().length, accountCount: accounts.length};
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
 * @param cookie pt_key=xxx;pt_pin=xxx;
 * @param userMsg 备注
 * @return {number} ck数量
 */
function updateCookie(cookie, userMsg) {
    let cookieList = readCookies();
    let cookieObj = new CookieObj().convert(cookie, userMsg);
    let isUpdate = false;
    cookieList.forEach((item) => {
        if (item.ptPin === cookieObj.ptPin) {
            isUpdate = true;
            //更新ptKey
            item.ptKey = cookieObj.ptKey;
            item.lastUpdateTime = cookieObj.lastUpdateTime;
            if (userMsg && userMsg !== '') {
                item.remark = userMsg;
            }
        }
    })
    if (!isUpdate) {
        if (!ckAutoAddOpen()) {
            throw new Error(`【添加COOKIE失败】\n服务器配置不自动添加Cookie\n如需启用请添加export CK_AUTO_ADD="true"`);
        } else {
            //新增CK
            cookieList.push(cookieObj)
        }
    }
    cookieList = saveCookiesToConfig(cookieList);
    return cookieList.length;
}

function updateAccount(ptPin, ptKey, wsKey, remarks) {
    if (!ptPin || ptPin === '') {
        throw new Error("ptPin不能为空")
    }
    if (ptPin === '%2A%2A%2A%2A%2A%2A') {
        throw new Error("ptPin不正确")
    }
    let accounts = getAccount(), isUpdate = false;
    remarks = remarks || ptPin;
    accounts.forEach((account, index) => {
        if (account['pt_pin'] && account['pt_pin'] === ptPin) {
            account['ws_key'] = wsKey || '';
            account['remarks'] = remarks;
            isUpdate = true;
        }
    })
    if (!isUpdate) {
        accounts.push({
            "pt_pin": ptPin,
            "ws_key": wsKey,
            "remarks": remarks
        })
    }
    saveNewConf("account.json", JSON.stringify(accounts, null, 2))
    let cookieCount = 0
    if (ptKey && ptKey !== '') {
        updateCookie(`pt_key=${ptKey};pt_pin=${ptPin};`, remarks);
    }
    console.log(`ptPin：${ptPin} 更新完成`)
    return getCount();


}


module.exports = {
    CookieObj,
    getCount,
    readCookies,
    saveCookiesToConfig,
    updateAccount,
    updateCookie,
    removeCookie
}
