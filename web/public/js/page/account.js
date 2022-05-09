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
            res.code === 1 && panelUtils.showSuccess(res.msg, res.desc)
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
            inputPlaceholder: '请输入需要编码/解码的url',
            title: 'URL编码/解码',
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
});
