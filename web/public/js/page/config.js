var qrcode, userCookie;
$(document).ready(function () {
    editor = CodeMirror.fromTextArea(document.getElementById("code"), {
        minimap: !userAgentTools.mobile(navigator.userAgent),
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

    $('#save').click(function () {
        var confContent = editor.getValue();
        panelRequest.post( '/api/save', {
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
