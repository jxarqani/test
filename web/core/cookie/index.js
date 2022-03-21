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
    this.sort = 999;
    this.cookieStr = () => {
        return `Cookie${this.id}="pt_key=${this.ptKey};pt_pin=${this.ptPin};"`;
    };
    this.tipStr = () => {
        return `## pt_pin=${this.ptPin};  上次更新：${this.lastUpdateTime};  备注：${this.remark};`;
    };

    this.convert = (cookie, tips) => {
        if (cookie.indexOf("Cookie") > -1) {
            this.id = parseInt(util.regExecFirst(cookie, /(?<=Cookie)([^=]+)/));
        } else {
            this.id = 0;
        }
        this.ptKey = util.regExecFirst(cookie, /(?<=pt_key=)([^;]+)/)
        this.ptPin = util.regExecFirst(cookie, /(?<=pt_pin=)([^;]+)/)
        if (util.isNotEmpty(this.ptPin)) {
            let account = getAccountByPtPin(this.ptPin);
            this.sort = account['sort'] || (this.id !== 0 ? this.id : 999)
        }
        if (tips && tips.indexOf("上次更新") > 0) {
            this.lastUpdateTime = util.regExecFirst(tips, /(?<=上次更新：)([^;]+)/);
            this.remark = util.regExecFirst(tips, /(?<=备注：)([^;]+)/);
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
                console.error(`${i + 1}行Cookie读取失败，请检查Cookie或Cookie下方的备注是否有误！`)
            }
        }
    }
    return cookieList;
}

/**
 * 根据ptpin获取cookie
 * @param ptPin
 * @returns {{}}
 */
function getCookieByPtPin(ptPin) {
    let cookieList = readCookies();
    let cookie = {};
    cookieList.forEach((item) => {
        if (item.ptPin === ptPin) {
            cookie = item;
        }
    })
    return cookie;
}


/**
 * 将Cookie数组保存至本地Config.sh
 * @returns {*[]}
 */
function saveCookiesToConfig(cookieList = []) {
    //开启排序
    if (accountEnableSort()) {
        cookieList = util.arrayObjectSort(cookieList, "sort", true);
    }
    let cookieIdMap = {};
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
                cookieIdMap[item.ptPin] = item.id;
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
 * 账号刷新
 */
function cookieReload() {
    saveCookiesToConfig(readCookies())
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
 * 判断账号是否开启排序
 */
function accountEnableSort() {
    let ACCOUNT_SORT = 'false'
    const content = getFile(CONFIG_FILE_KEY.CONFIG);
    if (content.match(/ACCOUNT_SORT=".+?"/)) {
        ACCOUNT_SORT = content.match(/ACCOUNT_SORT=".+?"/)[0].split('"')[1]
    }
    return ACCOUNT_SORT && ACCOUNT_SORT === 'true';
}

/**
 * 获取已经禁用的cookie
 */
function getTempBlockCookie() {
    let tempBlockCookie = ""
    const content = getFile(CONFIG_FILE_KEY.CONFIG);
    if (content.match(/\nTempBlockCookie=".+?"/)) {
        tempBlockCookie = content.match(/\nTempBlockCookie=".+?"/)[0].split('"')[1]
    }
    if (tempBlockCookie === "") {
        return [];
    }
    let cookieList = readCookies();
    let tempBlockCookieIdArr = tempBlockCookie.split(" ");
    let tempBlockCookieArr = []
    cookieList.map((cookie) => {
        tempBlockCookieIdArr.map(cookieId => {
            if (cookieId === cookie.id.toString()) {
                tempBlockCookieArr.push(cookie.ptPin);
            }
        });
    })
    return tempBlockCookieArr;
}

/**
 * 获取可用的账号
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
 * @return {{enableAccountCount: number,accountCount: number, cookieCount: number}}
 */
function getCount() {
    return {
        cookieCount: readCookies().length,
        accountCount: getAccount().length
    };
}

/**
 * 删除指定CK
 * @param ptPins 一个或者多个ptPins
 * @return {{enableAccountCount: number,accountCount: number, cookieCount: number}}
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

/**
 * 修改账号排序
 * @param ptPin
 * @param sort 排序
 */
function updateAccountSort(ptPin, sort = 999) {
    let accounts = getAccount();
    let updated = false;
    accounts.forEach((account) => {
        if (account['pt_pin'] && account['pt_pin'] === ptPin) {
            account["sort"] = sort;
            updated = true;
        }
    })
    if (updated) {
        saveAccount(accounts);
    } else {
        throw new Error(`账号 ${ptPin} 不存在`)
    }


}

/**
 * 根据ptPin获取账号
 * @param ptPin
 * @returns 账号信息
 */
function getAccountByPtPin(ptPin) {
    let accounts = getAccount(), res = {};
    accounts.forEach((account) => {
        if (account['pt_pin'] && account['pt_pin'] === ptPin) {
            res = account
        }
    })
    return res;
}

/**
 * 更新账号
 * @param ptPin
 * @param ptKey
 * @param wsKey
 * @param remarks
 * @returns {{enableAccountCount: number, accountCount: number, cookieCount: number}}
 */
function updateAccount(ptPin, ptKey, wsKey, remarks) {
    if (util.isNotEmpty(ptPin)) {
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
    saveAccount(accounts);
    if (util.isNotEmpty(ptKey)) {
        updateCookie(`pt_key=${ptKey};pt_pin=${ptPin};`, remarks);
    }
    console.log(`ptPin：${ptPin} 更新完成`)
    return getCount();


}

/**
 * 保存账号到文件
 * @param accounts
 */
function saveAccount(accounts = []) {
    accounts.forEach((account, index) => {
        if (undefined === account['sort']) {
            account['sort'] = 999;
        }
    })
    saveNewConf(CONFIG_FILE_KEY.ACCOUNT, JSON.stringify(accounts, null, 2))
}

module.exports = {
    CookieObj,
    getCount,
    readCookies,
    saveCookiesToConfig,
    updateAccount,
    updateCookie,
    removeCookie,
    updateAccountSort,
    getAccount,
    saveAccount,
    getTempBlockCookie,
    cookieReload
}
