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
    webhookok(msg = 'success', data) {
        return {
            code: 200,
            data: data,
            message: msg
        }
    },
    webhookfail() {
        return {
            code: 400,
            message: '已成功获取到您的账号信息但未能将其同步至服务器，请联系管理员进行处理！'
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
            msg: "认证失败!"
        }
    }
}

module.exports = {
    API_STATUS_CODE
}
