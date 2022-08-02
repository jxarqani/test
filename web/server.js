var express = require('express');
var session = require('express-session');
var FileStore = require('session-file-store')(session);
var compression = require('compression');
var bodyParser = require('body-parser');
var got = require('got');
var path = require('path');
var rootPath = path.resolve(__dirname, '..')
var svgCaptcha = require('svg-captcha');
var {
    exec
} = require('child_process');
const {
    createProxyMiddleware
} = require('http-proxy-middleware');
const random = require('string-random');
const util = require('./utils/index');

const {
    checkCode,
    sendSms
} = require("./core/cookie/sms");
const {
    extraServerFile,
    checkConfigFile,
    ScriptsPath,
    saveFile,
    loadScripts,
    logPath,
    loadLogTree,
    saveNewConf,
    getFileContentByName,
    getLastModifyFilePath,
    CONFIG_FILE_KEY,
    getFile,
    getNeatContent,
} = require("./core/file");

const {
    panelSendNotify
} = require("./core/notify");
const {
    getCount,
    removeCookie,
    updateCookie,
    updateAccount,
    saveAccount,
    checkCookieSatus
} = require("./core/cookie");
const {
    getCookie,
    step1,
    step2,
    checkLogin
} = require("./core/cookie/qrcode");
const {
    API_STATUS_CODE,
    userAgentTools,
    getClientIP
} = require("./core/http");
const {
    getLocalIp
} = require("./core");

let authError = '错误的用户名密码，请重试',
    errorCount = 1;

function getPath(request, page) {
    let userAgent = request.headers["user-agent"];
    if (userAgentTools.mobile(userAgent)) {
        return path.join(__dirname + '/public/mobile/' + page)
    }

    return path.join(__dirname + '/public/' + page)
}

function getUrl(request, page) {
    let userAgent = request.headers["user-agent"];
    if (userAgentTools.mobile(userAgent)) {
        return 'mobile/' + page;
    }
    return page;
}

var app = express();
// gzip压缩
app.use(compression({
    level: 6,
    filter: shouldCompress
}));

//设置跨域访问
app.all("*", function (req, res, next) {
    //设置允许跨域的域名，*代表允许任意域名跨域
    res.header("Access-Control-Allow-Origin", "*");
    //允许的header类型
    res.header("Access-Control-Allow-Headers", "content-type,api-token");
    //跨域允许的请求方式
    res.header("Access-Control-Allow-Methods", "DELETE,PUT,POST,GET,OPTIONS");
    if (req.method.toLowerCase() === 'options')
        res.send(200); //让options尝试请求快速结束
    else
        next();
})

function shouldCompress(req, res) {
    if (req.headers['x-no-compression']) {
        // don't compress responses with this request header
        return false;
    }

    // fallback to standard filter function
    return compression.filter(req, res);
}

let fileStoreOptions = {
    path: "./sessions",
    fileExtension: ".json",
    ttl: 24 * 60 * 60
};

app.use(
    session({
        store: new FileStore(fileStoreOptions),
        secret: 'secret',
        name: `panel-connect-name-${getLocalIp().replace(/\./g, '_')}`,
        resave: true,
        saveUninitialized: true,
        cookie: {
            maxAge: fileStoreOptions.ttl * 1000
        },
    })
);
app.use(bodyParser.json({
    limit: '50mb'
}));
app.use(bodyParser.urlencoded({
    limit: '50mb',
    extended: true
}));
app.use(express.static(path.join(__dirname, 'public')));

// ttyd proxy
app.use(
    '/shell',
    createProxyMiddleware({
        target: 'http://127.0.0.1:7685',
        ws: true,
        changeOrigin: true,
        pathRewrite: {
            '^/shell': '/',
        },
        onProxyReq(proxyReq, req, res) {
            if (!req.session.loggedin) {
                res.redirect('/');
            }
        },
    })
);


//所有API登录拦截
app.all('/*', function (req, res, next) {
    if (req.session.loggedin && req.url.indexOf("openApi") === -1) {
        next();
    } else {
        let arr = req.url.split('/');
        //去除参数
        for (let i = 0, length = arr.length; i < length; i++) {
            arr[i] = arr[i].split('?')[0];
        }
        if (arr.length === 1 && arr[0] === '') {
            // 根目录
            next();
        } else if (arr.length >= 2) {
            if (arr[1] === "openApi") {
                // openApi
                let authFileJson = JSON.parse(getFile(CONFIG_FILE_KEY.AUTH));
                let token = req.headers["api-token"]
                if (!token || token === '') {
                    //取URL中的TOKEN
                    token = req.query['api-token'];
                }
                if (token && token !== '' && token === authFileJson.openApiToken) {
                    next();
                } else {
                    res.send(API_STATUS_CODE.OPEN_API.AUTH_FAIL);
                }
            } else if (arr[1] !== "api") {
                if (arr[1] === 'auth' || arr[1] === 'logout') {
                    // 登录或者退出登录页面
                    next();
                } else {
                    // API拦截
                    req.session.originalUrl = req.originalUrl ? req.originalUrl : null; // 记录用户原始请求路径
                    res.redirect('/auth'); // 将用户重定向到登录页面
                }
            } else if (arr[1] === "api") {
                if ((arr[2] === 'captcha' || arr[2] === 'auth' || arr[2] === 'extra')) {
                    next();
                } else {
                    res.send(API_STATUS_CODE.API.NEED_LOGIN);
                }
            } else {
                // API拦截
                req.session.originalUrl = req.originalUrl ? req.originalUrl : null; // 记录用户原始请求路径
                res.redirect('/auth'); // 将用户重定向到登录页面
            }
        }
    }
});

/**
 * 根目录
 */
app.get('/', function (request, response) {
    response.redirect(`./run`);
});


app.get(`/:page`, (request, response) => {
    let page = request.params.page;
    const pageList = ['bot', 'crontab', 'config', 'diff', 'extra', 'changePwd', 'account', 'run', 'taskLog', 'terminal', 'viewScripts'];
    if (page && pageList.includes(page)) {
        response.sendFile(getPath(request, `${page}.html`));
    } else {
        if (page === 'logout') {
            request.session.loggedin = false;
            response.redirect('./auth');
        } else {
            response.sendFile(getPath(request, `auth.html`));
        }

    }
})


/**
 * 登录是否显示验证码
 */
app.get('/api/captcha/flag', function (request, response) {
    let data = getFile(CONFIG_FILE_KEY.AUTH);
    let con = JSON.parse(data);
    let authErrorCount = con['authErrorCount'] || 0;
    response.send(API_STATUS_CODE.okData({
        showCaptcha: authErrorCount >= errorCount
    }));
});

/**
 * 获取二维码链接
 */

app.get('/api/qrcode', function (request, response) {
    (async () => {
        try {
            await step1();
            const qrUrl = await step2();
            if (qrUrl !== 0) {
                response.send(API_STATUS_CODE.okData({
                    qrCode: qrUrl
                }));
            } else {
                response.send(API_STATUS_CODE.fail("出现错误"));
            }
        } catch (err) {
            response.send(API_STATUS_CODE.fail(err));
        }
    })();
});

/**
 * 获取返回的cookie信息
 */

app.get('/api/cookie', function (request, response) {
    (async () => {
        try {
            const cookie = await checkLogin();
            if (cookie.body.errcode === 0) {
                let ucookie = getCookie(cookie);
                let autoReplace = request.query.autoReplace && request.query.autoReplace === 'true';
                if (autoReplace) {
                    updateCookie({
                        ck: ucookie
                    });
                }
                response.send(API_STATUS_CODE.okData({
                    cookie: ucookie
                }))
            } else {
                response.send(API_STATUS_CODE.fail(cookie.body.message, cookie.body.errcode))
            }
        } catch (err) {
            response.send(API_STATUS_CODE.fail(err));
        }
    })();
});

/**
 * 获取各种配置文件api
 */

app.get('/api/config/:key', function (request, response) {
    let configString = 'config sample crontab extra bot account';
    if (configString.indexOf(request.params.key) > -1) {
        response.setHeader('Content-Type', 'text/plain');
        response.send(API_STATUS_CODE.okData(getFile(request.params.key)));
    } else {
        response.send(API_STATUS_CODE.okData(""));
    }
});

app.post('/api/runCmd', function (request, response) {
    const cmd = `cd ${rootPath};` + request.body.cmd;
    const delay = request.body.delay || 0;
    // console.log('before exec');
    // exec maxBuffer 20MB
    exec(cmd, {
        maxBuffer: 1024 * 1024 * 20
    }, (error, stdout, stderr) => {
        // console.log(error, stdout, stderr);
        // 根据传入延时返回数据，有时太快会出问题
        setTimeout(() => {
            if (error) {
                console.error(`执行的错误: ${error}`);
                response.send(API_STATUS_CODE.okData(stdout ? `${stdout}${error}` : `${error}`));
                return;
            }

            if (stdout) {
                // console.log(`stdout: ${stdout}`)
                response.send(API_STATUS_CODE.okData(getNeatContent(`${stdout}`)));
                return;
            }

            if (stderr) {
                console.error(`stderr: ${stderr}`);
                response.send(API_STATUS_CODE.okData(stderr));
                return;
            }
            response.send(API_STATUS_CODE.okData("执行结束，无结果返回。"));
        }, delay);
    });

});

/**
 * 使用jsName获取最新的日志
 */
app.get('/api/runLog', function (request, response) {
    let jsName = request.query.jsName;
    let logFile;
    if (['update', 'rmlog', 'exsc', 'tasklist'].includes(jsName)) {
        logFile = path.join(rootPath, `log/${jsName}.log`);
    } else {
        if (jsName.indexOf(".") > -1) {
            jsName = jsName.substring(0, jsName.lastIndexOf("."));
        }
        if (jsName === 'jd_getShareCodes') {
            jsName = 'jd_get_share_code'
        }
        let pathUrl = `log/${jsName}/`;
        if (jsName.startsWith("scripts/")) {
            jsName = jsName.substring(jsName.indexOf("/") + 1);
            pathUrl = `log/${jsName}/`;
        } else if (jsName.startsWith("own/")) {
            jsName = jsName.substring(jsName.indexOf("/") + 1);
            pathUrl = `log/${jsName.replace(new RegExp('[/\\-]', "gm"), '_')}/`;
        } else {
            if (!fs.existsSync(path.join(rootPath, pathUrl))) {
                pathUrl = `log/jd_${jsName}/`;
            }
        }
        logFile = getLastModifyFilePath(
            path.join(rootPath, pathUrl)
        );
    }

    if (logFile) {
        const content = getFileContentByName(logFile);
        response.setHeader('Content-Type', 'text/plain');
        response.send(API_STATUS_CODE.okData(getNeatContent(content)));
    } else {
        response.send(API_STATUS_CODE.okData("no logs"));
    }
});


/**
 * 验证码
 */
app.get('/api/captcha', function (req, res) {
    var captcha = svgCaptcha.createMathExpr({
        width: 120,
        height: 50
    });
    req.session.captcha = captcha.text;
    res.type('svg');
    res.status(200).send(captcha.data);
});

/**
 * ip转为地址
 * @param ip
 */
async function ip2Address(ip) {
    try {
        const {body} = await got(`http://ip.360.cn/IPShare/info?ip=${ip}`, {
            responseType: 'json',
            timeout: 2000,
            headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/101.0.4951.64 Safari/537.36 Edg/101.0.1210.53',
                Referer: 'http://ip.360.cn/',
                Host: 'ip.360.cn',
            },
        });
        let address = body.location;
        address === '* ' ? '未知' : address;
        address = address.replace(/\t/g, ' ');

        return {
            ip: ip,
            address: address,
        };
    } catch (e) {
        console.error("IP 转为地址失败", e);
    }
    return {
        ip: ip,
        address: "未知"
    };
}

/**
 * auth
 */
app.post('/api/auth', async function (request, response) {
    let {
        username,
        password,
        captcha = ''
    } = request.body;
    let con = JSON.parse(getFile(CONFIG_FILE_KEY.AUTH));
    let authErrorCount = con['authErrorCount'] || 0;
    if (authErrorCount >= 30) {
        //错误次数超过30次，直接禁止登录
        response.send(API_STATUS_CODE.failData('面板错误登录次数到达30次，已禁止登录!', {
            showCaptcha: true
        }))
        return;
    }
    let showCaptcha = authErrorCount >= errorCount;
    if (captcha === '' && showCaptcha) {
        response.send(API_STATUS_CODE.failData('请输入验证码!', {
            showCaptcha: true
        }))
        return;
    }
    if (showCaptcha && captcha !== request.session.captcha) {
        response.send(API_STATUS_CODE.failData('验证码不正确!', {
            showCaptcha: showCaptcha
        }))
        return;
    }
    if (username && password) {
        if (username === con.user && password === con.password) {
            request.session.loggedin = true;
            request.session.username = username;
            const result = {
                err: 0,
                lastLoginInfo: {},
                redirect: '/run'
            };
            Object.assign(result.lastLoginInfo, con.lastLoginInfo || {});
            if (password === "supermanito") {
                //如果是默认密码
                con.password = random(16);
                console.log(`系统检测到您的密码为初始密码，已修改为随机密码：${con.password}`);
                result['newPwd'] = con.password;
                request.session.loggedin = false;
                request.session.username = null;
            }
            con['authErrorCount'] = 0;
            //记录本次登录信息
            await ip2Address(getClientIP(request)).then(({
                                                             ip,
                                                             address
                                                         }) => {
                con.lastLoginInfo = {
                    loginIp: ip,
                    loginAddress: address,
                    loginTime: util.dateFormat("YYYY-mm-dd HH:MM:SS", new Date())
                }
                console.log(`${username} 用户登录成功，登录IP：${ip}，登录地址：${address}`);
                saveNewConf(CONFIG_FILE_KEY.AUTH, JSON.stringify(con), false);
            });
            response.send(API_STATUS_CODE.okData(result));
        } else {
            authErrorCount++;
            if (authErrorCount === 10 || authErrorCount === 20) {
                panelSendNotify(`异常登录提醒`, `您的面板登录验证错误次数已达到${authErrorCount}次，为了保障您的面板安全，请进行检查！温馨提示：请定期修改账号和密码，并将面板更新至最新版本`);
            } else if (authErrorCount === 30) {
                panelSendNotify(`异常登录提醒`, `您的面板登录验证错误次数已达到${authErrorCount}次，已禁用面板登录。请手动设置/jd/config/auth.json文件里面的“authErrorCount”为0来恢复面板登录！`);
            }
            con['authErrorCount'] = authErrorCount;
            saveNewConf(CONFIG_FILE_KEY.AUTH, JSON.stringify(con), false);
            response.send(API_STATUS_CODE.failData(authError, {
                showCaptcha: authErrorCount >= errorCount
            }))
        }
    } else {
        response.send(API_STATUS_CODE.fail("请输入用户名密码！"))
    }

});


/**
 * change pwd
 */
app.post('/api/changePwd', function (request, response) {
    let username = request.body.username;
    let password = request.body.password;
    let config = {
        user: username,
        password: password,
        openApiToken: random(32)
    };
    if (username && password) {
        saveNewConf(CONFIG_FILE_KEY.AUTH, JSON.stringify(config), false);
        response.send(API_STATUS_CODE.ok("修改成功"));
    } else {
        response.send(API_STATUS_CODE.fail("请输入用户名密码！"));
    }

});

/**
 * save config
 */

app.post('/api/save', function (request, response) {
    let postContent = request.body.content;
    let postFile = request.body.name;
    try {
        if (postFile === "account.json") {
            saveAccount(JSON.parse(postContent));
        } else {
            saveNewConf(postFile, postContent);
        }
        response.send(API_STATUS_CODE.ok("保存成功", {}, {}));
    } catch (e) {
        response.send(API_STATUS_CODE.fail("保存失败", 0, e.message));
    }

});


/**
 * 日志列表
 */
app.get('/api/logs', function (request, response) {
    let keywords = request.query.keywords || '';
    response.send(API_STATUS_CODE.okData(loadLogTree(keywords)));
});

/**
 * 日志文件
 */
app.get('/api/logs/:dir/:file', function (request, response) {

    let filePath;
    if (request.params.dir === '@') {
        filePath = logPath + request.params.file;
    } else {
        filePath = logPath + request.params.dir + '/' + request.params.file;
    }
    response.setHeader('Content-Type', 'text/plain');
    response.send(API_STATUS_CODE.okData(getNeatContent(getFileContentByName(filePath))));

});


/**
 * 脚本列表
 */
app.get('/api/scripts', function (request, response) {
    let keywords = request.query.keywords || '';
    let onlyRunJs = request.query.onlyRunJs || 'false';
    response.send(API_STATUS_CODE.okData(loadScripts(keywords, onlyRunJs === 'true')));

});

/**
 * save scripts
 */
app.post('/api/scripts/save', function (request, response) {
    let postContent = request.body.content;
    let postFile = request.body.name;
    saveFile(postFile, postContent);
    response.send(API_STATUS_CODE.ok("保存成功", {}, '注意：脚本库更新可能会导致修改的内容丢失'));
});

/**
 * 脚本文件
 */
app.get('/api/scripts/content', function (request, response) {

    let filePath;
    if (request.query.dir === '@') {
        filePath = ScriptsPath + request.query.file;
    } else if (request.query.path && request.query.path !== '') {
        filePath = rootPath + '/' + request.query.path;
    } else {
        filePath = rootPath + '/' + request.query.dir + '/' + request.query.file;
    }
    var content = getFileContentByName(filePath);
    response.setHeader('Content-Type', 'text/plain');
    response.send(API_STATUS_CODE.okData(content));

});

/**
 * 检测账号状态
 */
app.post("/api/checkCookie", async function (request, response) {
    let ck = request.body.cookie;
    var data = await checkCookieSatus(ck).then(function (req) {
        return req
    })
    var status_code = JSON.parse(data).retcode;
    if (status_code) {
        if (status_code == "0") {
            // 有效
            var send_content = {
                "code": "1",
                "status": "1",
            };
        } else {
            // 无效
            var send_content = {
                "code": "1",
                "status": "0",
            };
        }
    } else {
        var send_content = {
            "code": "0",
            "msg": "网络环境异常"
        };
    }
    response.send(send_content);
});

/**
 * API 发验证码
 */
app.get('/api/sms/send', async function (request, response) {
    try {
        const phone = request.query.phone;
        if (!new RegExp('\\d{11}').test(phone)) {
            response.send(API_STATUS_CODE.fail("手机号格式错误"));
            return;
        }
        const data = await sendSms(phone);
        if (data.err_code > 0) {
            response.send(API_STATUS_CODE.fail('发送验证码失败:' + data.err_msg));
        } else {
            response.send(API_STATUS_CODE.okData(data));
        }
    } catch (e) {
        console.log(e);
        response.send(API_STATUS_CODE.fail("系统错误", 0, e.message));
    }
});

app.post('/api/sms/checkCode', async function (request, response) {
    try {
        const {
            gsalt,
            ck,
            phone,
            code
        } = request.body;
        if (!new RegExp('\\d{11}').test(phone)) {
            response.send(API_STATUS_CODE.fail("手机号格式错误"));
            return;
        }
        if (!new RegExp('\\d{6}').test(code)) {
            response.send(API_STATUS_CODE.fail("验证码格式错误"));
            return;
        }
        const data = await checkCode(phone, code, gsalt, ck);
        if (data.err_code > 0) {
            response.send(API_STATUS_CODE.fail('登录失败:' + data.err_msg));
        } else {
            const cookie =
                `pt_key=${data.data.pt_key};pt_pin=${encodeURIComponent(data.data.pt_pin)};`;
            let cookieCount = 0,
                updateSuccess = false,
                errorMsg = "";
            try {
                cookieCount = updateCookie({
                    ck: cookie,
                    remarks: "",
                    phone
                });
                updateSuccess = true;
            } catch (e) {
                errorMsg = e.message;
                updateSuccess = false;
            }
            if (updateSuccess) {
                response.send(API_STATUS_CODE.ok(`获取/更新ck成功，当前CK数量：${cookieCount}`, {
                    cookieCount,
                    cookie: cookie
                }))
            } else {
                response.send(API_STATUS_CODE.failData(`获取/更新ck成功，但更新失败，原因：${errorMsg}`, {
                    cookie: cookie
                }))
            }

        }
    } catch (e) {
        console.log(e);
        response.send(API_STATUS_CODE.fail("系统错误", 0, e.message));
    }
});


/**
 * 更新已经存在的cookie & 自动添加新用户
 *
 * {"cookie":"","userMsg":""}
 * */
app.post('/openApi/updateCookie', function (request, response) {
    try {
        response.send(API_STATUS_CODE.okData(updateCookie({
            ck: request.body.cookie,
            remarks: request.body.userMsg,
            phone: request.body.phone
        })));
    } catch (e) {
        response.send(API_STATUS_CODE.fail(e.message));
    }

});

/**
 * 删除CK
 * {"ptPins":[]}
 */
app.post('/openApi/cookie/delete', function (request, response) {
    try {
        response.send(API_STATUS_CODE.okData(removeCookie(request.body.ptPins)));
    } catch (e) {
        response.send(API_STATUS_CODE.fail(e.message));
    }
});

/**
 * 添加或者更新账号
 * {"ptPin":"",ptKey:"",wsKey:"","remarks":""}
 * ptPin 必填
 * */
app.post('/openApi/addOrUpdateAccount', function (request, response) {
    try {
        let {
            ptPin,
            ptKey,
            wsKey,
            remarks,
            phone
        } = request.body;
        response.send(API_STATUS_CODE.okData(updateAccount({
            ptPin: ptPin,
            ptKey: ptKey,
            wsKey: wsKey,
            remarks: remarks,
            phone: phone
        })))
    } catch (e) {
        response.send(API_STATUS_CODE.fail(e.message));
    }

});

/**
 * 获取ck数量
 * */
app.get('/openApi/count', function (request, response) {
    try {
        response.send(API_STATUS_CODE.okData(getCount()))
    } catch (e) {
        response.send(API_STATUS_CODE.fail(e.message));
    }
});

/**
 * CK 回调
 * Body 内容为 {
            ck: "",
            remarks: "",
            phone: ""
        }
 其中 ck为必须项，remarks和phone为非必须
 */
app.post('/openApi/cookie/webhook', function (request, response) {
    try {
        let {
            ck,
            remarks = '',
            phone
        } = request.body;
        response.send(API_STATUS_CODE.webhookok(updateCookie({
            ck: ck,
            remarks: remarks,
            phone: phone
        })));
    } catch (e) {
        response.send(API_STATUS_CODE.webhookfail(e.message));
    }
});

checkConfigFile();

// 调用自定义api
try {
    require.resolve(extraServerFile);
    const extraServer = require(extraServerFile);
    if (typeof extraServer === 'function') {
        extraServer(app);
        console.log('用户自定义API => 初始化成功');
    }
} catch (e) {
}

app.listen(5678, '0.0.0.0', () => {
    console.log('应用正在监听 5678 端口!');
});