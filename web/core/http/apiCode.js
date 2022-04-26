const API_STATUS_CODE = {
    ok(msg = 'success', data, desc) {
        return {
            code: 1,
            data: data,
            desc: desc,
            msg: msg
        }
    },
    okData(data) {
        return this.ok('success', data)
    },

    fail(msg = 'fail', code = 0, desc) {
        return {
            code: code,
            msg: msg,
            desc: desc
        }
    },
    failData(msg = 'fail', data) {
        return {
            data: data,
            code: 0,
            msg: msg,
        }
    },
    webhook(data) {
        return {
            code: 200,
            data: data,
            msg: "您的账号已成功同步至服务器"
        }
    },
    API: {
        NEED_LOGIN: {
            code: 403,
            message: "请先登录!"
        }
    },
    OPEN_API: {
        AUTH_FAIL: {
            code: 4403,
            msg: "认证失败!",
            desc: "注意，新版本将'cookieApiToken'改名为'openApiToken',请及时重置修改密码重置此token"
        }
    }
}

module.exports = {
    API_STATUS_CODE
}
