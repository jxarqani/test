var {
    execSync
} = require('child_process');



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

module.exports = {
    getLocalIp
}
