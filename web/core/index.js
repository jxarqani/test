var {
    execSync
} = require('child_process');

// 获取本机内网ip
function getLocalIp() {
    try {
        const res = execSync(`ifdata -pa eth0`, {encoding: 'utf8'});
        const ipArr = res.split('\n');
        //console.log(ipArr);
        return ipArr[0] || '';
    } catch (e) {
        console.log(e.message)
    }
    return "127.0.0.1"
}

module.exports = {
    getLocalIp
}
