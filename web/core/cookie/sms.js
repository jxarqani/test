//短信验证码获取CK
const got = require('got');
const crypto = require('crypto');
const md5 = function (str) {
    const encode = crypto.createHash('md5');
    return encode.update(str).digest('hex');
};

async function sendSms(phone) {
    let appid = 959;
    let version = '1.0.0';
    let countryCode = 86;
    let timestamp = new Date().getTime();
    let subCmd = 1;
    let gsalt = 'sb2cwlYyaCSN1KUv5RHG3tmqxfEb8NKN';
    let gsign = md5('' + appid + version + timestamp + '36' + subCmd + gsalt);
    let res = await got.post('https://qapplogin.m.jd.com/cgi-bin/qapp/quick', {
        method: 'post',
        headers: {
            'user-agent':
                'Mozilla/5.0 (Linux; Android 10; V1838T Build/QP1A.190711.020; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/98.0.4758.87 Mobile Safari/537.36 hap/1.9/vivo com.vivo.hybrid/1.9.6.302 com.jd.crplandroidhap/1.0.3 ({packageName:com.vivo.hybrid,type:deeplink,extra:{}})',
            'accept-language': 'zh-CN,zh;q=0.9,en;q=0.8',
            'content-type': 'application/x-www-form-urlencoded; charset=utf-8',
            'accept-encoding': '',
            cookie: '',
        },
        body:
            'client_ver=' +
            version +
            '&gsign=' +
            gsign +
            '&appid=' +
            appid +
            '&return_page=https%3A%2F%2Fcrpl.jd.com%2Fn%2Fmine%3FpartnerId%3DWBTF0KYY%26ADTAG%3Dkyy_mrqd%26token%3D&cmd=36&sdk_ver=1.0.0&sub_cmd=' +
            subCmd +
            '&qversion=' +
            version +
            '&ts=' +
            timestamp,
        dataType: 'json',
    });
    let data = JSON.parse(res.body).data;
    subCmd = 2;
    timestamp = new Date().getTime();
    gsalt = data.gsalt;
    gsign = md5('' + appid + version + timestamp + '36' + subCmd + gsalt);
    let sign = md5(
        '' +
        appid +
        version +
        countryCode +
        phone +
        '4dtyyzKF3w6o54fJZnmeW3bVHl0$PbXj'
    );
    let ck =
        'guid=' +
        data.guid +
        ';lsid=' +
        data.lsid +
        ';gsalt=' +
        data.gsalt +
        ';rsa_modulus=' +
        data.rsa_modulus +
        ';';
    res = await got.post('https://qapplogin.m.jd.com/cgi-bin/qapp/quick', {
        method: 'post',
        headers: {
            'user-agent':
                'Mozilla/5.0 (Linux; Android 10; V1838T Build/QP1A.190711.020; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/98.0.4758.87 Mobile Safari/537.36 hap/1.9/vivo com.vivo.hybrid/1.9.6.302 com.jd.crplandroidhap/1.0.3 ({packageName:com.vivo.hybrid,type:deeplink,extra:{}})',
            'accept-language': 'zh-CN,zh;q=0.9,en;q=0.8',
            'content-type': 'application/x-www-form-urlencoded; charset=utf-8',
            'accept-encoding': '',
            cookie: ck,
        },
        body:
            'country_code=' +
            countryCode +
            '&client_ver=' +
            version +
            '&gsign=' +
            gsign +
            '&appid=' +
            appid +
            '&mobile=' +
            phone +
            '&sign=' +
            sign +
            '&cmd=36&sub_cmd=' +
            subCmd +
            '&qversion=' +
            version +
            '&ts=' +
            timestamp,
        dataType: 'json',
    });
    data = JSON.parse(res.body).data;
    return {err_code: data.err_code, err_msg: data.err_msg, ck: ck, gsalt: gsalt}
}

async function checkCode(phone, code, gsalt, ck) {
    let appid = 959;
    let version = '1.0.0';
    let countryCode = 86;
    let timestamp = new Date().getTime();
    let subCmd = 3;
    let gsign = md5('' + appid + version + timestamp + '36' + subCmd + gsalt);
    let body =
        'country_code=' +
        countryCode +
        '&client_ver=' +
        version +
        '&gsign=' +
        gsign +
        '&smscode=' +
        code +
        '&appid=' +
        appid +
        '&mobile=' +
        phone +
        '&cmd=36&sub_cmd=' +
        subCmd +
        '&qversion=' +
        version +
        '&ts=' +
        timestamp;
    let res = await got.post('https://qapplogin.m.jd.com/cgi-bin/qapp/quick', {
        method: 'post',
        headers: {
            'user-agent':
                'Mozilla/5.0 (Linux; Android 10; V1838T Build/QP1A.190711.020; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/98.0.4758.87 Mobile Safari/537.36 hap/1.9/vivo com.vivo.hybrid/1.9.6.302 com.jd.crplandroidhap/1.0.3 ({packageName:com.vivo.hybrid,type:deeplink,extra:{}})',
            'accept-language': 'zh-CN,zh;q=0.9,en;q=0.8',
            'content-type': 'application/x-www-form-urlencoded; charset=utf-8',
            'accept-encoding': '',
            cookie: ck,
        },
        body: body,
        dataType: 'json',
    });
    return JSON.parse(res.body);
}


module.exports = {
    sendSms, checkCode
}




