var qrcode, userCookie, sendSmsData;
$(document).ready(function () {
    editor = CodeMirror.fromTextArea(document.getElementById("code"), {
        minimap: minimapVal,
        lineNumbers: true,
        lineWrapping: true,
        styleActiveLine: true,
        matchBrackets: true,
        viewportMargin: viewportMargin,
        mode: 'shell',
        theme: themeChange.getAndUpdateEditorTheme(),
        keyMap: 'sublime'
    });

    function loadConfig(callback) {
        panelRequest.get('/api/config/config', function (res) {
            editor.setValue(res.data);
            !userAgentTools.mobile(navigator.userAgent) && $(".CodeMirror-scroll").css("width", `calc(100% - ${$(".CodeMirror-minimap").width() + 5}px)`);
            callback && callback();
        });
    }

    loadConfig();

    // 勾选记忆
    if (sessionStorage.getItem('autoReplaceCookie') === 'false') {
        $('#autoReplace').prop('checked', false);
    }
    $('#autoReplace').on('change', function () {
        sessionStorage.setItem('autoReplaceCookie', $(this).prop('checked'));
    });

    qrcode = new QRCode(document.getElementById("qrcode"), {
        text: "sample",
        correctLevel: QRCode.CorrectLevel.L
    });


    function autoReplace(cookie) {
        var value = editor.getValue();
        var ptPin = /pt_pin=[\S]+;/.exec(cookie)[0];
        var cookieReg = new RegExp(`pt_key=[\\S]+;${ptPin}`);
        if (cookieReg.test(value)) {
            var newValue = value.replace(cookieReg, cookie);
            editor.setValue(newValue);
            return true;
        } else {
            return false;
        }
    }


    function checkLogin() {
        var isAutoReplace = $('#autoReplace').prop('checked');
        var timeId = setInterval(() => {
            panelRequest.get('/api/cookie', {autoReplace: isAutoReplace}, function (res) {
                if (res.code === 1) {
                    clearInterval(timeId);
                    $("#qrcontainer").addClass("hidden");
                    $("#refresh_qrcode").addClass("hidden");
                    userCookie = res.data.cookie
                    loadConfig(() => {
                        if (isAutoReplace) {
                            if (autoReplace(userCookie)) {
                                panelUtils.showAlert({
                                    title: "cookie已获取(2s后自动替换)",
                                    html: '<div class="cookieCon" style="font-size:12px;">' +
                                        userCookie + '</div>',
                                    icon: "success",
                                    showConfirmButton: false,
                                });

                                setTimeout(() => {
                                    $('#save').trigger('click');
                                }, 2000);
                            } else {
                                panelUtils.showAlert({
                                    title: "cookie已获取",
                                    html: '<div class="cookieCon" style="font-size:16px;font-weight: bold;">自动替换失败，请复制Cookie后手动更新。</div>' +
                                        '<div class="cookieCon" style="font-size:12px;">' +
                                        userCookie + '</div>',
                                    icon: "success",
                                    confirmButtonText: "复制Cookie",
                                }).then((result) => {
                                    copyToClip(userCookie);
                                });
                            }
                        } else {
                            panelUtils.showAlert({
                                title: "cookie已获取",
                                html: '<div class="cookieCon" style="font-size:12px;">' +
                                    userCookie + '</div>',
                                icon: "success",
                                confirmButtonText: "复制Cookie",
                            }).then((result) => {
                                copyToClip(userCookie);
                            });
                        }
                    })

                } else if (res.code === 21) {
                    clearInterval(timeId);
                    $("#refresh_qrcode").removeClass("hidden");
                }
            })
        }, 3000)

    }

    function get_code() {
        panelRequest.get('/api/qrcode', function (res) {
            if (res.code === 1) {
                $("#qrcontainer").removeClass("hidden")
                $("#refresh_qrcode").addClass("hidden")
                qrcode.clear();
                qrcode.makeCode(res.data.qrCode);
                checkLogin();
            } else {
                panelUtils.showError(res.msg)
            }
        });
    }


    $('.refresh').click(get_code);

    $('#cookieTools').click(get_code);

    $('.qframe-close').click(function () {
        $("#qrcontainer").addClass("hidden");
        $("#refresh_qrcode").addClass("hidden");
    });

    function sendBtnStatus(ele, i = 60) {
        if (i < 1) {
            ele.removeAttribute("disabled");
            ele.innerText = "发送验证码";
            return;
        }
        ele.setAttribute("disabled", true);
        ele.innerText = i;
        setTimeout(() => {
            i--;
            sendBtnStatus(ele, i)
        }, 1000)
    }

    $('#smsLogin').click(async function () {
        const {value: formValues} = await Swal.fire({
            title: '短信验证码登录',
            html:
                '<div class="sms-login">' +
                '   <div><input id="smsLoginPhone" maxlength="11" autofocus="true" placeholder="请输入11位手机号" class="swal2-input"></div>' +
                '   <div class="swal2-html-container red-font" id="tips-mobile"></div>' +
                '   <div><input id="smsLoginCode" maxlength="6" placeholder="6位验证码" class="swal2-input check-code"><button class="swal2-confirm swal2-styled send-sms-btn" id="sendSmsBtn">发送验证码</button></div>' +
                '   <div class="swal2-html-container red-font" id="tips-check"></div>' +
                '</div>',
            focusConfirm: true,
            cancelButtonText: "取消",
            showCloseButton: true,
            confirmButtonText: "确认获取COOKIE",
            showCancelButton: false,
            allowOutsideClick: false,
            confirmButtonColor: "#7066e0",
            didOpen: () => {
                let tipsMobileEle = document.getElementById('tips-mobile');
                let sendSmsBtnEle = document.getElementById('sendSmsBtn');
                let smsLoginPhoneEle = document.getElementById('smsLoginPhone');
                sendSmsBtnEle.addEventListener('click', function () {
                    let phone = smsLoginPhoneEle.value;
                    if (!new RegExp('\\d{11}').test(phone)) {
                        tipsMobileEle.innerText = "手机号码格式不正确"
                    } else {
                        tipsMobileEle.innerText = "";
                        //发送验证码
                        panelRequest.get('/api/sms/send', {phone: phone}, function (res) {
                            if (res.code === 1) {
                                sendSmsData = res.data;
                                sendBtnStatus(sendSmsBtnEle);
                            } else {
                                tipsMobileEle.innerText = res.msg
                            }
                        }, (res) => {
                            tipsMobileEle.innerText = res.msg
                        }, false);
                    }
                })
            },
            preConfirm: () => {
                let phone = document.getElementById('smsLoginPhone').value;
                let code = document.getElementById('smsLoginCode').value;
                let tipsMobileEle = document.getElementById('tips-mobile');
                let tipsCheckEle = document.getElementById('tips-check');
                if (!new RegExp('\\d{11}').test(phone)) {
                    tipsMobileEle.innerText = "手机号码格式不正确"
                    return false;
                } else {
                    tipsMobileEle.innerText = "";
                }
                if (!new RegExp('\\d{6}').test(code)) {
                    tipsCheckEle.innerText = "请输入6位验证码"
                    return false;
                } else {
                    tipsMobileEle.innerText = "";
                }
                panelRequest.post('/api/sms/checkCode', {phone, code, ...sendSmsData}, function (res) {
                    tipsCheckEle.innerText = res.msg;
                    let {cookieCount, cookie} = res.data;

                    panelUtils.showAlert({
                        title: "cookie已获取",
                        text: res.msg,
                        icon: "success",
                        confirmButtonText: "复制Cookie",
                    }).then((result) => {
                        copyToClip(cookie);
                    });
                    //重新加载一下配置
                    loadConfig();

                }, (res) => {
                    tipsCheckEle.innerText = res.msg;
                }, false);
                return false;
            }
        })

    })

    $('#save').click(function () {
        var confContent = editor.getValue();
        panelRequest.post('/api/save', {
            content: confContent,
            name: "config.sh"
        }, function (res) {
            res.code === 1 && panelUtils.showSuccess(res.msg, res.desc)
        });
    });

    $('#wrap').click(function () {
        var lineWrapping = editor.getOption('lineWrapping');
        editor.setOption('lineWrapping', !lineWrapping);
    });
});
