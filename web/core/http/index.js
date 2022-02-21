const path = require("path");
const {API_STATUS_CODE} = require("./apiCode");

var userAgentTools = {
    Android: function (userAgent) {
        return (/android/i.test(userAgent.toLowerCase()));
    },
    BlackBerry: function (userAgent) {
        return (/blackberry/i.test(userAgent.toLowerCase()));
    },
    iOS: function (userAgent) {
        return (/iphone|ipad|ipod/i.test(userAgent.toLowerCase()));
    },
    iPhone: function (userAgent) {
        return (/iphone/i.test(userAgent.toLowerCase()));
    },
    iPad: function (userAgent) {
        return (/ipad/i.test(userAgent.toLowerCase()));
    },
    iPod: function (userAgent) {
        return (/ipod/i.test(userAgent.toLowerCase()));
    },
    Opera: function (userAgent) {
        return (/opera mini/i.test(userAgent.toLowerCase()));
    },
    Windows: function (userAgent) {
        return (/iemobile/i.test(userAgent.toLowerCase()));
    },
    Pad: function (userAgent) {
        return (/pad|m2105k81ac/i.test(userAgent.toLowerCase()));
    },
    mobile: function (userAgent) {
        if (userAgentTools.Pad(userAgent)) {
            return false;
        }
        return (userAgentTools.Android(userAgent) || userAgentTools.iPhone(userAgent) || userAgentTools.BlackBerry(userAgent));
    }
};

/**
 * @getClientIP
 * @desc 获取用户 ip 地址
 * @param {Object} req - 请求
 */
function getClientIP(req) {
    let ip = req.headers['x-forwarded-for'] ||
        req.ip ||
        req.connection.remoteAddress ||
        req.socket.remoteAddress ||
        req.connection.socket.remoteAddress || '';
    if (ip.split(',').length > 0) {
        ip = ip.split(',')[0]
    }
    return ip.substr(ip.lastIndexOf(':') + 1, ip.length);
}




module.exports = {
    API_STATUS_CODE, userAgentTools, getClientIP
}
