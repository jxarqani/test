/**
 * 自定义api功能
 * 修改此文件不会立即生效，需要执行 taskctl panel on 面板
 */

var path = require('path');
var fs = require('fs');

var rootPath = process.env.JD_DIR;
// 京东到家果园日志文件夹
var jddjFruitLogDir = path.join(rootPath, 'log/jddj_fruit/');


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

// 获取京东到家果园互助码列表
function getJddjFruitCodes() {
  const lastLogPath = getLastModifyFilePath(jddjFruitLogDir);
  const lastLogContent = getFileContentByName(lastLogPath);
  const lastLogContentArr = lastLogContent.split('\n');
  const shareCodeLineArr = lastLogContentArr.filter(item => item.match(/京东到家果园互助码:JD_/g));
  console.log(shareCodeLineArr);
  const shareCodeStr = shareCodeLineArr[0] || '';
  const shareCodeArr = shareCodeStr.replace(/京东到家果园互助码:/, '').split(',').filter(code => code.includes('JD_'));
  return shareCodeArr;
}

// 生成京东到家果园互助码文本
function createJddjFruitCodeTxt(page, size) {
  const shareCodeArr = getJddjFruitCodes();
  if (shareCodeArr.length > size * (page -1)) {
    const filtered = shareCodeArr.filter((code, index) => index + 1 > size * (page - 1) && index + 1 <= size * page);
    return filtered.join(',');
  }
  return '';
}


function diyServer(app) {
  /**
   * 获取京东到家果园互助码
   */
  app.get('/api/sharecode/jddj_fruit', function(req, res) {
    const page = req.query.page || '1';
    const size = req.query.size || '5';
    const content = createJddjFruitCodeTxt(Number(page), Number(size));
    console.log(`京东到家果园互助码: ${content}`);
    res.setHeader("Content-Type", "text/plain");
    res.send(content);
  });
}


module.exports = diyServer;