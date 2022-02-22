let path = require('path');
var fs = require('fs');
var rootPath = path.resolve(__dirname, '../../../');
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

var os = require('os');

var {
    execSync
} = require('child_process');

const CONFIG_FILE_KEY = {
    CONFIG: "config",
    SAMPLE: "sample",
    CRONTAB: "crontab",
    EXTRA: "extra",
    BOT: "bot",
    ACCOUNT: "account",
    AUTH: "auth"
}

/**
 * 检查 config/bak/ 备份目录是否存在，不存在则创建
 */
function mkdirConfigBakDir() {
    if (!fs.existsSync(confBakDir)) {
        fs.mkdirSync(confBakDir);
    }
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

function checkConfigSave(oldContent) {
    if (os.type() == 'Linux') {
        //判断格式是否正确
        try {
            execSync(`bash ${confFile} \2>${logPath}.check`, {encoding: 'utf8'});
        } catch (e) {
            fs.writeFileSync(confFile, oldContent);
            let errorMsg, line;
            try {
                errorMsg = /(?<=line\s[0-9]*:)([^"]+)/.exec(e.message)[0];
                line = /(?<=line\s)[0-9]*/.exec(e.message)[0]
            } catch (e) {
            }
            throw new Error("<p>" + (errorMsg && line ? `第 ${line} 行:${errorMsg}` : e.message) + "</p>");
        }
    }

}

/**
 * 将 post 提交内容写入 config.sh 文件（同时备份旧的 config.sh 文件到 bak 目录）
 * @param file
 * @param content
 * @param isBak 是否备份 默认为true
 */
function saveNewConf(file, content, isBak = true) {
    let oldContent = isBak ? bakConfFile(file) : "";
    switch (file) {
        case CONFIG_FILE_KEY.CONFIG:
        case 'config.sh':
            fs.writeFileSync(confFile, content);
            isBak && checkConfigSave(oldContent);
            break;
        case CONFIG_FILE_KEY.CRONTAB:
        case 'crontab.list':
            fs.writeFileSync(crontabFile, content);
            execSync('crontab ' + crontabFile);
            break;
        case CONFIG_FILE_KEY.EXTRA:
        case 'extra.sh':
            fs.writeFileSync(extraFile, content);
            break;
        case CONFIG_FILE_KEY.AUTH:
        case 'auth.json':
            fs.writeFileSync(authConfigFile, content);
            break;
        case CONFIG_FILE_KEY.BOT:
        case 'bot.json':
            fs.writeFileSync(botFile, content);
            break;
        case CONFIG_FILE_KEY.ACCOUNT:
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

/**
 * 获取文件内容
 * @param fileKey
 * @return string
 */
function getFile(fileKey) {
    let content = "";
    switch (fileKey) {
        case CONFIG_FILE_KEY.CONFIG:
            content = getFileContentByName(confFile);
            break;
        case CONFIG_FILE_KEY.SAMPLE:
            content = getFileContentByName(sampleFile);
            break;
        case CONFIG_FILE_KEY.CRONTAB:
            content = getFileContentByName(crontabFile);
            break;
        case CONFIG_FILE_KEY.EXTRA:
            content = getFileContentByName(extraFile);
            break;
        case CONFIG_FILE_KEY.BOT:
            content = getFileContentByName(botFile);
            break;
        case CONFIG_FILE_KEY.ACCOUNT:
            content = getFileContentByName(accountFile);
            break;
        case CONFIG_FILE_KEY.AUTH:
            content = getFileContentByName(authConfigFile);
            break;
        default:
            content = getFileContentByName(fileKey);
            break;
    }
    return content;
}

/**
 * 加载日志文件目录
 * @param keywords
 * @return {*[]}
 */
function loadLogTree(keywords) {
    let fileList = fs.readdirSync(logPath, 'utf-8');
    let dirs = [], rootFiles = [];
    let excludeRegExp = /(.tmp)/;
    fileList.map((name, index) => {
        if ((keywords === '' || name.indexOf(keywords) > -1) && !excludeRegExp.test(name)) {
            let stat = fs.lstatSync(logPath + name);
            // 是目录，需要继续
            if (stat.isDirectory()) {
                let fileListTmp = fs.readdirSync(logPath + '/' + name, 'utf-8');
                fileListTmp.reverse();
                let dirMap = {
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
    return dirs;
}

function loadFileTree(loadPath, dirName, keywords, onlyRunJs) {
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
                let dirPathFiles = loadFileTree(dirPath, name, keywords, onlyRunJs)
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
 * 加载脚本文件
 * @param keywords 关键字
 * @param onlyRunJs 是否只返回可运行的脚本文件
 * @return {*[]}
 */
function loadScripts(keywords, onlyRunJs) {
    let rootFiles = [], scriptsDir = 'scripts', ownDir = 'own', dirList = [scriptsDir];
    if (!onlyRunJs) {
        dirList.push(ownDir);
    }
    dirList.forEach((dirName) => {
        rootFiles.push({
            dirName: dirName,
            dirPath: dirName,
            files: loadFileTree(dirName, dirName, keywords, onlyRunJs),
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
                    files: loadFileTree(ownDir + "/" + name, name, keywords, onlyRunJs),
                })
            }
        })
    }
    return rootFiles;
}

/**
 * 保存文件
 * @param file
 * @param content
 */
function saveFile(file, content) {
    fs.writeFileSync(path.join(rootPath, file), content);
}

module.exports = {
    mkdirConfigBakDir,
    getNeatContent,
    checkConfigFile,
    bakConfFile,
    saveFile,
    checkConfigSave,
    saveNewConf,
    getFileContentByName,
    getLastModifyFilePath,
    getFile,
    CONFIG_FILE_KEY,
    loadLogTree,
    loadFileTree,
    loadScripts,
    logPath,
    ScriptsPath,
    extraServerFile
}
