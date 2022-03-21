/**
 * 格式化时间
 * @param fmt
 * @param date
 * @returns {*}
 */
function dateFormat(fmt, date) {
    let ret;
    const opt = {
        "Y+": date.getFullYear().toString(),        // 年
        "m+": (date.getMonth() + 1).toString(),     // 月
        "d+": date.getDate().toString(),            // 日
        "H+": date.getHours().toString(),           // 时
        "M+": date.getMinutes().toString(),         // 分
        "S+": date.getSeconds().toString()          // 秒
        // 有其他格式化字符需求可以继续添加，必须转化成字符串
    };
    for (let k in opt) {
        ret = new RegExp("(" + k + ")").exec(fmt);
        if (ret) {
            fmt = fmt.replace(ret[1], (ret[1].length === 1) ? (opt[k]) : (opt[k].padStart(ret[1].length, "0")))
        }
    }
    return fmt;
}

function randomNumber(min = 0, max = 100) {
    return Math.min(Math.floor(min + Math.random() * (max - min)), max);
}

/**
 * 对象数组排序
 * @param array 需要排序的数组
 * @param field 字段
 * @param isAsc 是否升序
 * @returns {*[]}
 */
function arrayObjectSort(array = [], field, isAsc = true) {
    field && array.sort((a, b) => {
        return isAsc ? a[field] - b[field] : b[field] - a[field];
    })
    return array;
}

//console.log(arrayObjectSort([{a: 1, c: '1'}, {a: 3, c: '3'}, {a: 2, c: '2'}],'a',false));

function inArray(search, array) {
    for (let i in array) {
        if (array[i] === search) {
            return true;
        }
    }
    return false;
}

/**
 * 是否为空
 * @param str
 * @returns {boolean}
 */
function isNotEmpty(str) {
    return null !== str && undefined !== str && str !== ''
}

/**
 * 去空格
 */
function strTrim(str = "") {
    return str.trim();
}

/**
 * 正则匹配
 */
function regExecFirst(str = "", reg) {
    let exec = reg.exec(str);
    if (exec && exec.length > 0) {
        return strTrim(exec[0])
    }
    return "";
}

module.exports = {
    dateFormat, randomNumber, arrayObjectSort, inArray, isNotEmpty, strTrim, regExecFirst
}
