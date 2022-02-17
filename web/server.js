var express = require('express');
var session = require('express-session');
var FileStore = require('session-file-store')(session);
var compression = require('compression');
var bodyParser = require('body-parser');
var got = require('got');
var path = require('path');
var fs = require('fs');
var svgCaptcha = require('svg-captcha');
var {
    execSync,
    exec
} = require('child_process');
const {
    createProxyMiddleware
} = require('http-proxy-middleware');
const random = require('string-random');
const util = require('./util');


var rootPath = path.resolve(__dirname, '..')
// config.sh 文件所在目录
var confFile = path.join(rootPath, 'config/config.sh');
// config.sample.sh 文件所在目录
var sampleFile = path.join(rootPath, 'sample/config.sample.sh');
// crontab.list 文件所在目录
var crontabFile = path.join(rootPath, 'config/crontab.list');
// config.sh 文件备份目录
var confBakDir = path.join(rootPath, 'config/bak/');
// auth.json 文件目录
var authConfigFile = path.join(rootPath, 'config/auth.json');
// account.json 文件目录
var accountFile = path.join(rootPath, 'config/account.json');
// bot.json 文件所在目录
var botFile = path.join(rootPath, 'config/bot.json');
// extra.sh 文件目录
var extraFile = path.join(rootPath, 'config/extra.sh');
// extra_server.js 文件目录
var extraServerFile = path.join(rootPath, 'config/extra_server.js');
// 日志目录
var logPath = path.join(rootPath, 'log/');
// 脚本目录
var ScriptsPath = path.join(rootPath, 'scripts/');
// own目录
var OwnPath = path.join(rootPath, 'own/');

var authError = '错误的用户名密码，请重试';

var configString = 'config sample crontab extra bot account';

var s_token, cookies, guid, lsid, lstoken, okl_token, token, userCookie = '', errorCount = 1;

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

function praseSetCookies(response) {
    s_token = response.body.s_token
    guid = response.headers['set-cookie'][0]
    guid = guid.substring(guid.indexOf('=') + 1, guid.indexOf(';'))
    lsid = response.headers['set-cookie'][2]
    lsid = lsid.substring(lsid.indexOf('=') + 1, lsid.indexOf(';'))
    lstoken = response.headers['set-cookie'][3]
    lstoken = lstoken.substring(lstoken.indexOf('=') + 1, lstoken.indexOf(';'))
    cookies = 'guid=' + guid + '; lang=chs; lsid=' + lsid + '; lstoken=' + lstoken + '; '
}

function getCookie(response) {
    var TrackerID = response.headers['set-cookie'][0]
    TrackerID = TrackerID.substring(TrackerID.indexOf('=') + 1, TrackerID.indexOf(';'))
    var pt_key = response.headers['set-cookie'][1]
    pt_key = pt_key.substring(pt_key.indexOf('=') + 1, pt_key.indexOf(';'))
    var pt_pin = response.headers['set-cookie'][2]
    pt_pin = pt_pin.substring(pt_pin.indexOf('=') + 1, pt_pin.indexOf(';'))
    var pt_token = response.headers['set-cookie'][3]
    pt_token = pt_token.substring(pt_token.indexOf('=') + 1, pt_token.indexOf(';'))
    var pwdt_id = response.headers['set-cookie'][4]
    pwdt_id = pwdt_id.substring(pwdt_id.indexOf('=') + 1, pwdt_id.indexOf(';'))
    var s_key = response.headers['set-cookie'][5]
    s_key = s_key.substring(s_key.indexOf('=') + 1, s_key.indexOf(';'))
    var s_pin = response.headers['set-cookie'][6]
    s_pin = s_pin.substring(s_pin.indexOf('=') + 1, s_pin.indexOf(';'))
    cookies = 'TrackerID=' + TrackerID + '; pt_key=' + pt_key + '; pt_pin=' + pt_pin + '; pt_token=' + pt_token + '; pwdt_id=' + pwdt_id + '; s_key=' + s_key + '; s_pin=' + s_pin + '; wq_skey='
    var userCookie = 'pt_key=' + pt_key + ';pt_pin=' + pt_pin + ';';
    console.log('\n############  登录成功，获取到 Cookie  #############\n\n');
    console.log('Cookie1="' + userCookie + '"\n');
    console.log('\n####################################################\n\n');
    return userCookie;
}

let LOGIN_UA = process.env.LOGIN_UA ? process.env.LOGIN_UA : "jdapp;iPhone;10.1.2;14.7.1;${randomString(40)};network/wifi;model/iPhone10,2;addressid/4091160336;appBuild/167802;jdSupportDarkMode/0;Mozilla/5.0 (iPhone; CPU iPhone OS 14_7_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148;supportJDSHWK/1";

async function step1() {
    try {
        s_token,
            cookies,
            guid,
            lsid,
            lstoken,
            okl_token,
            token = ''
        let timeStamp = (new Date()).getTime()
        let url = 'https://plogin.m.jd.com/cgi-bin/mm/new_login_entrance?lang=chs&appid=300&returnurl=https://wq.jd.com/passport/LoginRedirect?state=' + timeStamp + '&returnurl=https://home.m.jd.com/myJd/newhome.action?sceneval=2&ufc=&/myJd/home.action&source=wq_passport'
        const response = await got(url, {
            responseType: 'json',
            headers: {
                'Connection': 'Keep-Alive',
                'Content-Type': 'application/x-www-form-urlencoded',
                'Accept': 'application/json, text/plain, */*',
                'Accept-Language': 'zh-cn',
                'Referer': 'https://plogin.m.jd.com/login/login?appid=300&returnurl=https://wq.jd.com/passport/LoginRedirect?state=' + timeStamp + '&returnurl=https://home.m.jd.com/myJd/newhome.action?sceneval=2&ufc=&/myJd/home.action&source=wq_passport',
                'User-Agent': LOGIN_UA,
                'Host': 'plogin.m.jd.com'
            }
        });

        praseSetCookies(response)
    } catch (error) {
        cookies = '';
        console.log(error.response.body);
    }
};

async function step2() {
    try {
        if (cookies == '') {
            return 0;
        }
        let timeStamp = (new Date()).getTime()
        let url = 'https://plogin.m.jd.com/cgi-bin/m/tmauthreflogurl?s_token=' + s_token + '&v=' + timeStamp + '&remember=true'
        const response = await got.post(url, {
            responseType: 'json',
            json: {
                'lang': 'chs',
                'appid': 300,
                'returnurl': 'https://wqlogin2.jd.com/passport/LoginRedirect?state=' + timeStamp + '&returnurl=//home.m.jd.com/myJd/newhome.action?sceneval=2&ufc=&/myJd/home.action',
                'source': 'wq_passport'
            },
            headers: {
                'Connection': 'Keep-Alive',
                'Content-Type': 'application/x-www-form-urlencoded; Charset=UTF-8',
                'Accept': 'application/json, text/plain, */*',
                'Cookie': cookies,
                'Referer': 'https://plogin.m.jd.com/login/login?appid=300&returnurl=https://wqlogin2.jd.com/passport/LoginRedirect?state=' + timeStamp + '&returnurl=//home.m.jd.com/myJd/newhome.action?sceneval=2&ufc=&/myJd/home.action&source=wq_passport',
                'User-Agent': LOGIN_UA,
                'Host': 'plogin.m.jd.com',
            }
        });
        token = response.body.token
        okl_token = response.headers['set-cookie'][0]
        okl_token = okl_token.substring(okl_token.indexOf('=') + 1, okl_token.indexOf(';'))
        var qrUrl = 'https://plogin.m.jd.com/cgi-bin/m/tmauth?appid=300&client_type=m&token=' + token;
        return qrUrl;
    } catch (error) {
        console.log(error.response.body);
        return 0;
    }
}

var i = 0;

async function checkLogin() {
    try {
        if (cookies == '') {
            return 0;
        }
        let timeStamp = (new Date()).getTime()
        let url = 'https://plogin.m.jd.com/cgi-bin/m/tmauthchecktoken?&token=' + token + '&ou_state=0&okl_token=' + okl_token;
        const response = await got.post(url, {
            responseType: 'json',
            form: {
                lang: 'chs',
                appid: 300,
                returnurl: 'https://wqlogin2.jd.com/passport/LoginRedirect?state=1100399130787&returnurl=//home.m.jd.com/myJd/newhome.action?sceneval=2&ufc=&/myJd/home.action',
                source: 'wq_passport',
            },
            headers: {
                'Referer': 'https://plogin.m.jd.com/login/login?appid=300&returnurl=https://wqlogin2.jd.com/passport/LoginRedirect?state=' + timeStamp + '&returnurl=//home.m.jd.com/myJd/newhome.action?sceneval=2&ufc=&/myJd/home.action&source=wq_passport',
                'Cookie': cookies,
                'Connection': 'Keep-Alive',
                'Content-Type': 'application/x-www-form-urlencoded; Charset=UTF-8',
                'Accept': 'application/json, text/plain, */*',
                'User-Agent': LOGIN_UA,
            }
        });

        return response;
    } catch (error) {
        console.log(error.response.body);
        let res = {};
        res.body = {
            check_ip: 0,
            errcode: 222,
            message: '出错'
        };
        res.headers = {};
        return res;
    }
}

/**
 * 检查 config.sh 以及 config.sample.sh 文件是否存在
 */
function checkConfigFile() {
    if (!fs.existsSync(confFile)) {
        console.error(rootPath);
        console.error('脚本启动失败，config.sh 文件不存在！');
        process.exit(1);
    }
    if (!fs.existsSync(sampleFile)) {
        console.error('脚本启动失败，config.sample.sh 文件不存在！');
        process.exit(1);
    }
}

/**
 * 检查 config/bak/ 备份目录是否存在，不存在则创建
 */
function mkdirConfigBakDir() {
    if (!fs.existsSync(confBakDir)) {
        fs.mkdirSync(confBakDir);
    }
}

function panelSendNotify(title, content) {
    execSync(`task notify "${title}" "${content}"`);
}

/**
 * 备份 config.sh 文件 并返回旧的文件内容
 */
function bakConfFile(file) {
    mkdirConfigBakDir();
    let date = new Date();
    let bakConfFile =
        confBakDir +
        file +
        '_' +
        date.getFullYear() +
        '-' +
        (date.getMonth() + 1) +
        '-' +
        date.getDate() +
        '-' +
        date.getHours() +
        '-' +
        date.getMinutes() +
        '-' +
        date.getMilliseconds();
    let oldConfContent = '';
    switch (file) {
        case 'config.sh':
            oldConfContent = getFileContentByName(confFile);
            fs.writeFileSync(bakConfFile, oldConfContent);
            break;
        case 'crontab.list':
            oldConfContent = getFileContentByName(crontabFile);
            fs.writeFileSync(bakConfFile, oldConfContent);
            break;
        case 'extra.sh':
            oldConfContent = getFileContentByName(extraFile);
            fs.writeFileSync(bakConfFile, oldConfContent);
            break;
        case 'bot.json':
            oldConfContent = getFileContentByName(botFile);
            fs.writeFileSync(bakConfFile, oldConfContent);
            break;
        case 'account.json':
            oldConfContent = getFileContentByName(accountFile);
            fs.writeFileSync(bakConfFile, oldConfContent);
            break;
        default:
            break;
    }
    return oldConfContent;
}

function checkConfigSave(oldContent){
    //判断格式是否正确
    try {
        execSync(`bash ${confFile} 2> ${logPath}.check`, {encoding: 'utf8'});
    } catch (e) {
        fs.writeFileSync(confFile, oldContent);
        let errorMsg,line;
        try {
            errorMsg = /(?<=line\s[0-9]*:)([^"]+)/.exec(e.message)[0];
            line = /(?<=line\s)[0-9]*/.exec(e.message)[0]
        }catch (e){}
        throw new Error("<p>" + (errorMsg && line ? `第 ${line} 行:${errorMsg}` : e.message) + "</p>");
    }
}

/**
 * 将 post 提交内容写入 config.sh 文件（同时备份旧的 config.sh 文件到 bak 目录）
 * @param file
 * @param content
 */
function saveNewConf(file, content) {
    let oldContent = bakConfFile(file);
    switch (file) {
        case 'config.sh':
            fs.writeFileSync(confFile, content);
            checkConfigSave(oldContent);
            break;
        case 'crontab.list':
            fs.writeFileSync(crontabFile, content);
            execSync('crontab ' + crontabFile);
            break;
        case 'extra.sh':
            fs.writeFileSync(extraFile, content);
            break;
        case 'bot.json':
            fs.writeFileSync(botFile, content);
            break;
        case 'account.json':
            fs.writeFileSync(accountFile, content);
            break;
        default:
            break;
    }
}

/**
 * 获取文件内容
 * @param fileName 文件路径
 * @returns {string}
 */
function getFileContentByName(fileName) {
    if (fs.existsSync(fileName)) {
        return fs.readFileSync(fileName, 'utf8');
    }
    return '';
}

/**
 * 获取目录中最后修改的文件的路径
 * @param dir 目录路径
 * @returns {string} 最新文件路径
 */
function getLastModifyFilePath(dir) {
    var filePath = '';

    if (fs.existsSync(dir)) {
        var lastmtime = 0;

        var arr = fs.readdirSync(dir);

        arr.forEach(function (item) {
            var fullpath = path.join(dir, item);
            var stats = fs.statSync(fullpath);
            if (stats.isFile()) {
                if (stats.mtimeMs >= lastmtime) {
                    filePath = fullpath;
                }
            }
        });
    }
    return filePath;
}

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
};

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
    res.header("Access-Control-Allow-Headers", "content-type");
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
        cookie: {maxAge: fileStoreOptions.ttl * 1000},
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
                let authFile = fs.readFileSync(authConfigFile, 'utf8');
                let authFileJson = JSON.parse(authFile);
                let token = req.headers["api-token"]
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
                    req.session.originalUrl = req.originalUrl ? req.originalUrl : null;  // 记录用户原始请求路径
                    res.redirect('/auth');  // 将用户重定向到登录页面
                }
            } else if (arr[1] === "api") {
                if ((arr[2] === 'captcha' || arr[2] === 'auth' || arr[2] === 'sharecode')) {
                    next();
                } else {
                    res.send(API_STATUS_CODE.API.NEED_LOGIN);
                }
            } else {
                // API拦截
                req.session.originalUrl = req.originalUrl ? req.originalUrl : null;  // 记录用户原始请求路径
                res.redirect('/auth');  // 将用户重定向到登录页面
            }
        }
    }
});

// 获取本机内网ip
function getLocalIp() {
    try {
        const res = execSync(`ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6|awk '{print $2}'|tr -d "addr:"`, {encoding: 'utf8'});
        const ipArr = res.split('\n');
        console.log(ipArr);
        return ipArr[0] || '';
    } catch (e) {
        console.log(e.message)
    }
    return "127.0.0.1"

}

/**
 * 根目录
 */
app.get('/', function (request, response) {
    response.redirect(`./run`);
});


app.get(`/:page`, (request, response) => {
    let page = request.params.page;
    const pageList = ['bot', 'crontab', 'config', 'diff', 'extra', 'changePwd', 'remarks', 'run', 'taskLog', 'terminal', 'viewScripts'];
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
    fs.readFile(authConfigFile, 'utf8', function (err, data) {
        if (err) console.log(err);
        var con = JSON.parse(data);
        let authErrorCount = con['authErrorCount'] || 0;
        response.send(API_STATUS_CODE.okData({showCaptcha: authErrorCount >= errorCount}));
    })
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
                response.send(API_STATUS_CODE.okData({qrCode: qrUrl}));
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
            if (cookie.body.errcode == 0) {
                let ucookie = getCookie(cookie);
                let autoReplace = request.query.autoReplace && request.query.autoReplace === 'true';
                if (autoReplace) {
                    updateCookie(ucookie);
                }
                response.send(API_STATUS_CODE.okData({cookie: ucookie}))
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

    let content = "";
    if (configString.indexOf(request.params.key) > -1) {
        switch (request.params.key) {
            case 'config':
                content = getFileContentByName(confFile);
                break;
            case 'bot':
                content = getFileContentByName(botFile);
                break;
            case 'sample':
                content = getFileContentByName(sampleFile);
                break;
            case 'crontab':
                content = getFileContentByName(crontabFile);
                break;
            case 'extra':
                content = getFileContentByName(extraFile);
                break;
            case 'account':
                content = getFileContentByName(accountFile);
                break;
            default:
                break;
        }
        response.setHeader('Content-Type', 'text/plain');
        response.send(API_STATUS_CODE.okData(content));
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
    var captcha = svgCaptcha.createMathExpr({width: 120, height: 50});
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
        const {body} = await got.get(`https://ip.cn/api/index?ip=${ip}&type=1`, {
            encoding: 'utf-8',
            responseType: 'json',
            timeout: 2000,
        });
        if (body.code === 0 && body.address) {
            let address = body.address;
            if (address.indexOf("内网IP") > -1) {
                return {ip: ip, address: "局域网"};
            }
            let type = address.substring(address.lastIndexOf(" "));
            address = address.replace(type, '').replace(/\s*/g, '');
            return {ip: ip, address: address + type};
        }
    } catch (e) {
        console.error("IP 转为地址失败", e);
    }
    return {ip: ip, address: "未知"};
}

/**
 * auth
 */
app.post('/api/auth', async function (request, response) {
    let {username, password, captcha = ''} = request.body;
    let data = fs.readFileSync(authConfigFile, 'utf8');
    let con = JSON.parse(data);
    let authErrorCount = con['authErrorCount'] || 0;
    if (authErrorCount >= 30) {
        //错误次数超过30次，直接禁止登录
        response.send(API_STATUS_CODE.failData('面板错误登录次数到达30次，已禁止登录!', {showCaptcha: true}))
        return;
    }
    let showCaptcha = authErrorCount >= errorCount;
    if (captcha === '' && showCaptcha) {
        response.send(API_STATUS_CODE.failData('请输入验证码!', {showCaptcha: true}))
        return;
    }
    if (showCaptcha && captcha !== request.session.captcha) {
        response.send(API_STATUS_CODE.failData('验证码不正确!', {showCaptcha: showCaptcha}))
        return;
    }
    if (username && password) {
        if (username === con.user && password === con.password) {
            request.session.loggedin = true;
            request.session.username = username;
            const result = {err: 0, lastLoginInfo: {}, redirect: '/run'};
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
            await ip2Address(getClientIP(request)).then(({ip, address}) => {
                con.lastLoginInfo = {
                    loginIp: ip,
                    loginAddress: address,
                    loginTime: util.dateFormat("YYYY-mm-dd HH:MM:SS", new Date())
                }
                console.log(`${username} 用户登录成功，登录IP：${ip}，登录地址：${address}`);
                fs.writeFileSync(authConfigFile, JSON.stringify(con));
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
            fs.writeFileSync(authConfigFile, JSON.stringify(con));
            response.send(API_STATUS_CODE.failData(authError, {showCaptcha: authErrorCount >= errorCount}))
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
        fs.writeFile(authConfigFile, JSON.stringify(config), function (err) {
            if (err) {
                response.send(API_STATUS_CODE.fail("修改错误，请重试!"));
            } else {
                response.send(API_STATUS_CODE.ok("修改成功！"));
            }
        });
    } else {
        response.send(API_STATUS_CODE.fail("请输入用户名密码!"));
    }

});

/**
 * save config
 */

app.post('/api/save', function (request, response) {
    let postContent = request.body.content;
    let postfile = request.body.name;
    try {
        saveNewConf(postfile, postContent);
        response.send(API_STATUS_CODE.ok("保存成功", {}, `将自动刷新页面查看修改后的 ${postfile} 文件<br>每次保存都会生成备份`));
    } catch (e) {
        response.send(API_STATUS_CODE.fail("保存失败", 0, e.message));
    }

});


/**
 * 日志列表
 */
app.get('/api/logs', function (request, response) {

    let keywords = request.query.keywords || '';
    var fileList = fs.readdirSync(logPath, 'utf-8');
    var dirs = [];
    var rootFiles = [];
    let excludeRegExp = /(.tmp)/;
    fileList.map((name, index) => {
        if ((keywords === '' || name.indexOf(keywords) > -1) && !excludeRegExp.test(name)) {
            let stat = fs.lstatSync(logPath + name);
            // 是目录，需要继续
            if (stat.isDirectory()) {
                var fileListTmp = fs.readdirSync(logPath + '/' + name, 'utf-8');
                fileListTmp.reverse();
                var dirMap = {
                    dirName: name,
                    files: fileListTmp,
                };
                dirs.push(dirMap);
            } else {
                rootFiles.push(name);
            }
        }
    })
    dirs.push({
        dirName: '@',
        files: rootFiles,
    });
    response.send(API_STATUS_CODE.okData(dirs));
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
    var content = getFileContentByName(filePath);
    response.setHeader('Content-Type', 'text/plain');
    response.send(API_STATUS_CODE.okData(getNeatContent(content)));

});

function loadFile(loadPath, dirName, keywords, onlyRunJs) {
    let arrFiles = [], arrDirs = [];
    let excludeRegExp = /(.git)|(.github)|(node_modules)|(icon)/;
    let fileRegExp = /.*?/g;
    if (onlyRunJs) {
        excludeRegExp = /(.git)|(.github)|(node_modules)|(icon)|AGENTS|Cookie|cookie|Token|ShareCodes|sendNotify|JDJR|validate|ZooFaker|MovementFaker|tencentscf|api_test|app.|main.|jd_update.js|jd_env_copy.js|index.js|.json|ql.js|jdEnv|(.json)|(.jpg)|(.png)|(.gif)|(.jpeg)/
        fileRegExp = /(.js)|(.ts)|(.py)/
    }
    const files = fs.readdirSync(rootPath + "/" + loadPath, {withFileTypes: true})
    files.map((item, index) => {
        let name = item.name;
        let dirPath = loadPath + '/' + name;
        let filter = (!excludeRegExp.test(name) && fileRegExp.test(name)) && (keywords === '' || name.indexOf(keywords) > -1);
        if (filter || item.isDirectory()) {
            if (item.isDirectory()) {
                let dirPathFiles = loadFile(dirPath, name, keywords, onlyRunJs)
                if (filter || (keywords !== "" && dirPathFiles.length > 0)) {
                    if (onlyRunJs) {
                        arrFiles = arrFiles.concat(dirPathFiles)
                    } else {
                        arrDirs.push({
                            dirName: name,
                            dirPath: dirPath,
                            files: dirPathFiles,
                        })
                    }
                }
            } else if (!item.isDirectory()) {
                arrFiles.push({
                    fileName: name,
                    filePath: dirPath,
                })
            }
        }

    })
    return arrDirs.concat(arrFiles);
}

/**
 * 脚本列表
 */
app.get('/api/scripts', function (request, response) {

    let keywords = request.query.keywords || '';
    let onlyRunJs = request.query.onlyRunJs || 'false';
    onlyRunJs = onlyRunJs === 'true';
    let rootFiles = [], scriptsDir = 'scripts', ownDir = 'own', dirList = [scriptsDir];
    if (!onlyRunJs) {
        dirList.push(ownDir);
    }
    dirList.forEach((dirName) => {
        rootFiles.push({
            dirName: dirName,
            dirPath: dirName,
            files: loadFile(dirName, dirName, keywords, onlyRunJs),
        })
    })
    if (onlyRunJs) {
        let ownFileList = fs.readdirSync(OwnPath, {withFileTypes: true});
        ownFileList.forEach((item) => {
            let name = item.name;
            if (item.isDirectory()) {
                rootFiles.push({
                    dirName: name,
                    dirPath: ownDir + "/" + name,
                    files: loadFile(ownDir + "/" + name, name, keywords, onlyRunJs),
                })
            }
        })
    }
    response.send(API_STATUS_CODE.okData(rootFiles));

});

/**
 * save scripts
 */

app.post('/api/scripts/save', function (request, response) {
    let postContent = request.body.content;
    let postFile = request.body.name;
    fs.writeFileSync(path.join(rootPath, postFile), postContent);
    response.send(API_STATUS_CODE.ok("保存成功!", {}, '注意：脚本库更新可能会导致修改的内容丢失'));
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

function updateCookie(cookie, userMsg = '无', response) {
    if (cookie) {
        const content = getFileContentByName(confFile);
        const lines = content.split('\n');
        const pt_pin = cookie.match(/pt_pin=.+?;/)[0];
        let updateFlag = false;
        let lastIndex = 0;
        let maxCookieCount = 0;
        let CK_AUTO_ADD = false
        if (content.match(/CK_AUTO_ADD=".+?"/)) {
            CK_AUTO_ADD = content.match(/CK_AUTO_ADD=".+?"/)[0].split('"')[1]
        }
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i];
            if (line.startsWith('Cookie')) {
                maxCookieCount = Math.max(
                    Number(line.split('=')[0].split('Cookie')[1]),
                    maxCookieCount
                );
                lastIndex = i;
                if (line.match(/pt_pin=.+?;/) && line.match(/pt_pin=.+?;/)[0] === pt_pin) {
                    const head = line.split('=')[0];
                    lines[i] = [head, '=', '"', cookie, '"'].join('');
                    updateFlag = true;
                    var lineNext = lines[i + 1];
                    if (
                        lineNext.match(/上次更新：/)
                    ) {
                        const bz = lineNext.split('备注：')[1];
                        lines[i + 1] = ['## ', pt_pin, ' 上次更新：', util.dateFormat("YYYY-mm-dd HH:MM:SS", new Date()), ' 备注：', bz ? bz : userMsg].join('');
                    } else {
                        const newLine = ['## ', pt_pin, ' 上次更新：', util.dateFormat("YYYY-mm-dd HH:MM:SS", new Date()), ' 备注：', userMsg].join('');
                        lines.splice(lastIndex + 1, 0, newLine);
                    }
                }
            }
        }
        let CookieCount = Number(maxCookieCount) + 1;
        if (!updateFlag && CK_AUTO_ADD === 'true') {
            lastIndex++;
            let newLine = [
                'Cookie',
                CookieCount,
                '=',
                '"',
                cookie,
                '"',
            ].join('');
            //提交备注
            lines.splice(lastIndex + 1, 0, newLine);
            newLine = ['## ', pt_pin, ' 上次更新：', util.dateFormat("YYYY-mm-dd HH:MM:SS", new Date()), ' 备注：', userMsg].join('');
            lines.splice(lastIndex + 2, 0, newLine);
        }
        saveNewConf('config.sh', lines.join('\n'));
        if (response) {
            response.send(API_STATUS_CODE.ok(updateFlag ?
                `[更新成功]\n当前用户量:(${maxCookieCount})` : CK_AUTO_ADD === 'true' ? `[新的Cookie]\n当前用户量:(${CookieCount})` : `服务器配置不自动添加Cookie\n如需启用请添加export CK_AUTO_ADD="true"`));
        }
    } else {
        if (response) {
            response.send(API_STATUS_CODE.fail("参数错误"))
        }
    }
}

/**
 * 更新已经存在的人的cookie & 自动添加新用户
 *
 * {"cookie":"","userMsg":""}
 * */
app.post('/openApi/updateCookie', function (request, response) {
    updateCookie(request.body.cookie, request.body.userMsg, response);
});

function updateAccount(body, response) {
    let {ptPin, ptKey, wsKey, remarks} = body;
    if (!ptPin || ptPin === '') {
        response && response.send(API_STATUS_CODE.fail("ptPin不能为空"))
        console.log("ptPin不能为空");
        return;
    }
    if (ptPin === '%2A%2A%2A%2A%2A%2A') {
        response && response.send(API_STATUS_CODE.fail("ptPin不正确"))
        console.log("ptPin不正确");
        return;
    }
    let data = fs.readFileSync(accountFile, 'utf8');
    let accounts = JSON.parse(data) || [], isUpdate = false;
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
    if (ptKey && ptKey !== '') {
        updateCookie(`pt_key=${ptKey};pt_pin=${ptPin};`, remarks, response);
    }
    console.log(`ptPin：${ptPin} 更新完成`)

}

/**
 * 添加或者更新账号
 * {"ptPin":"",ptKey:"",wsKey:"","remarks":""}
 * ptPin 必填
 * */
app.post('/openApi/addOrUpdateAccount', function (request, response) {
    updateAccount(request.body, response)
});


checkConfigFile();

// 调用自定义api
try {
    require.resolve(extraServerFile);
    const extraServer = require(extraServerFile);
    if (typeof extraServer === 'function') {
        extraServer(app);
        console.log('调用自定义api成功');
    }
} catch (e) {
    console.error('调用自定义api失败');
}

// codemirror中去除解析不了的颜色标记
function getNeatContent(origin) {
    return (origin || '').replace(/\033\[0m/g, '')
        .replace(/\033\[1m/g, '')
        .replace(/\033\[31m/g, '')
        .replace(/\033\[32m/g, '')
        .replace(/\033\[33m/g, '')
        .replace(/\033\[34m/g, '')
        .replace(/\033\[35m/g, '')
        .replace(/\033\[36m/g, '');
}


app.listen(5678, '0.0.0.0', () => {
    console.log('应用正在监听 5678 端口!');
});

