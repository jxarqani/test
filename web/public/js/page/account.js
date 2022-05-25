$(document).ready(function () {
    editor = CodeMirror.fromTextArea(document.getElementById("code"), {
        minimap: minimapVal,
        lineNumbers: true,
        lineWrapping: true,
        styleActiveLine: true,
        matchBrackets: true,
        viewportMargin: viewportMargin,
        mode: 'application/json',
        theme: themeChange.getAndUpdateEditorTheme(),
        keyMap: 'sublime'
    });
    panelRequest.get('/api/config/account', {}, function (res) {
        try {
            let accountArr = JSON.parse(res.data);
            for (const account of accountArr) {
                if (account && !account.config) {
                    account['config'] = {"ep": {}};
                }
            }
            editor.setValue(JSON.stringify(accountArr, null, 2));
        } catch (e) {

        }

        !userAgentTools.mobile(navigator.userAgent) && $(".CodeMirror-scroll").css("width", `calc(100% - ${$(".CodeMirror-minimap").width() + 5}px)`);
    });

    $('#save').click(function () {
        var confContent = editor.getValue();
        let timeStamp = (new Date()).getTime()
        try {
            let accountArr = JSON.parse(confContent);
            let pt_pins = [];
            for (const account of accountArr) {
                if (account.ws_key && account.ws_key !== "" && new RegExp("[`~!@#$^&*()=|{}':;',\\[\\].<>《》/?~！@#￥……&*（）|{}【】‘；：”“'。，、？ ]").test(account.ws_key)) {
                    panelUtils.showError(`${account.pt_pin} ${account.remarks}的 ws_key 格式不正确`)
                    return;
                }
                if (pt_pins.indexOf(account.pt_pin) > -1) {
                    panelUtils.showError(`${account.pt_pin} 存在重复`)
                    return;
                }
                pt_pins.push(account.pt_pin);
            }
        } catch (e) {
            panelUtils.showError("格式出现问题，请仔细检查")
            return;
        }
        panelRequest.post('/api/save?t=' + timeStamp, {
            content: confContent,
            name: "account.json"
        }, function (res) {
            res.code === 1 && panelUtils.showSuccess(res.msg)
        });
    });

    $('#wrap').click(function () {
        var lineWrapping = editor.getOption('lineWrapping');
        editor.setOption('lineWrapping', !lineWrapping);
    });

    $("#create").click(() => {
        let confContent = editor.getValue();
        try {
            let accountArr = JSON.parse(confContent);
            accountArr.push({
                "pt_pin": "ptpin的值",
                "ws_key": "wskey的值",
                "phone": "手机号",
                "remarks": "备注内容",
                "config": {
                    "ep": {}
                }
            })
            editor.setValue(JSON.stringify(accountArr, null, 2));
            editor.execCommand('goDocEnd');
        }catch (e) {
            panelUtils.showError("创建失败，请检查当前配置的格式是否正确")
        }
    })

    let openTools = (value = '') => {
        Swal.fire({
            customClass: {
                container: "mini-tool"
            },
            inputValue: value,
            input: 'textarea',
            inputPlaceholder: '在此输入内容',
            inputLabel: 'URL编码/解码',
            width: userAgentTools.mobile(navigator.userAgent) ? "95%" : "40%",
            denyButtonText: "解码",
            confirmButtonText: "编码",
            showDenyButton: true,
            showConfirmButton: true,
            showCloseButton: true,
            allowOutsideClick: false,
            returnInputValueOnDeny: true,
            preConfirm: () => {
                const value = document.getElementById('swal2-input').value;
                document.getElementById('swal2-input').value = encodeURIComponent(value);
                return false;
            },
            preDeny: () => {
                const value = document.getElementById('swal2-input').value;
                document.getElementById('swal2-input').value = decodeURIComponent(value);
                return false;
            },
        });
    }

    $("#urlDecodeEncode").click(async function () {
        openTools();
    })

    $('#checkAccount').click(async function () {
        Swal.fire({
            title: "检测 wskey 有效性",
            input: "text",
            inputAttributes: {
                autocapitalize: "off",
            },
            width: 800,
            html: "请在下方输入 <strong>Cookie</strong> 内容或 <strong>JSON</strong> 格式内容，也可以直接输入 <strong>wskey</strong> 的值",
            confirmButtonText: "检测",
            confirmButtonColor: "#2D70F9",
            showLoaderOnConfirm: true,
            allowOutsideClick: false,
            showCancelButton: true,
            showCloseButton: true,
            cancelButtonText: "取消",
            preConfirm: async (key) => {
                Swal.showLoading(Swal.getCancelButton())
                if (key == "") {
                    Swal.update({
                        showCloseButton: true,
                        showConfirmButton: false,
                        cancelButtonText: "关闭",
                        cancelButtonColor: "#dc3545",
                    });
                    Swal.disableInput()
                    Swal.showValidationMessage(`不能检测空气！`);
                } else {
                    if ((RegExp(/wskey=.*/).test(key)) == true) {
                        key = key.match(/(wskey=)([^;]+)/)[0].split("=")[1];
                    } else if ((RegExp(/\"ws_key\"\:/).test(key)) == true) {
                        key = key.split("\"")[3];
                    }
                    var key_type = "unknown";
                    var judge_wskey_length = key.length == 96 || key.length == 118;
                    var judge_key_type = RegExp(/[^A-Za-z0-9-_]/).test(key);
                    var judge_key_format = RegExp(/^AAJ[a-z].*/).test(key) || RegExp(/^app_openAAJ[a-z].*/).test(key);
                    if (judge_key_format == true && judge_key_type == false) {
                        if (judge_wskey_length == true) {
                            key_type = "wskey";
                        }
                    }
                    if (key_type == "unknown") {
                        Swal.update({
                            showCloseButton: true,
                            showConfirmButton: false,
                            cancelButtonText: "关闭",
                            cancelButtonColor: "#dc3545",
                        });
                        Swal.disableInput()
                        Swal.showValidationMessage(`格式有误，请验证后重试`);
                    } else {
                        var myHeaders = new Headers();
                        myHeaders.append("Content-Type", "application/json");
                        var raw = JSON.stringify({
                            "cookie": "wskey=" + key + ";"
                        });
                        var requestOptions = {
                            method: 'POST',
                            headers: myHeaders,
                            body: raw,
                            redirect: 'follow'
                        };
                        const response = await fetch("/api/checkCookie", requestOptions);
                        const data = await response.text();
                        var code = JSON.parse(data).code;
                        if (code == "1") {
                            var status = JSON.parse(data).status;
                            if (status == "1") {
                                Swal.fire({
                                    icon: "success",
                                    title: "帐号有效",
                                    allowOutsideClick: false,
                                });
                            } else if (status == "0") {
                                Swal.update({
                                    showCloseButton: true,
                                    showConfirmButton: false,
                                    cancelButtonText: "关闭",
                                    cancelButtonColor: "#dc3545",
                                });
                                Swal.disableInput()
                                Swal.showValidationMessage("账号无效");
                            }
                        } else {
                            Swal.showValidationMessage("网络环境异常")
                        }
                    }
                }
            },
        })
    });

});
