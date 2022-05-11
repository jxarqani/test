$(document).ready(function () {
    var timer = 0, curScript = {key: "task list 2>&1 | tee log/tasklist.log", value: "tasklist"},
        $runCmd = $('#runCmd'),
        $runCmdConc = $('#runCmdConc');
    editor = CodeMirror.fromTextArea(document.getElementById("code"), {
        minimap: minimapVal,
        lineNumbers: true,
        lineWrapping: true,
        styleActiveLine: false,
        matchBrackets: true,
        viewportMargin: viewportMargin,
        readOnly: true,
        cursorHeight: 0,
        mode: 'text',
        theme: themeChange.getAndUpdateEditorTheme(),
    });

    /**
     * 执行cmd
     * @param jsName js 文件名称
     * @param cmd 命令
     * @param refreshLog 是否刷新日志 默认不刷新
     */
    function runCmd(jsName, cmd, refreshLog = true) {
        if (!jsName || !cmd) {
            panelUtils.showError('未选择脚本', '请在上方下拉菜单选择您需要执行的脚本');
            return;
        }
        if (timer) {
            panelUtils.showError('点击太快了', '请先等待上一条任务执行完毕或刷新页面');
            return;
        }
        editor.setValue('');

        panelRequest.post("/api/runCmd", {
            cmd: cmd
        }, function (res) {

            editor.setValue(res.data);
            if (jsName) {
                //将光标和滚动条设置到文本区最下方
                editor.execCommand('goDocEnd');
            }
            clearInterval(timer);
            timer = 0;
        })
        timer = 1;
        if (refreshLog) {
            const timeout = jsName === 'tasklist' ? 100 : 1000;
            // 1s后开始查日志
            setTimeout(() => {
                jsName && getLogInterval(jsName);
            }, timeout);
        }

    }

    runCmd(curScript.value, curScript.key, curScript.refreshLog);
    curScript = {};

    function initSearch(list) {
        let $jdScript = $(".jdScript");
        $jdScript.MultiFunctionSelect({
            suffixIcon: "chevron",
            selectList: list,
            keyField: "key",
            valueField: "value",
            // 输入查询相关配置
            searchSupportOption: {
                // 是否支持输入查询，默认支持，默认值true
                support: true,
                // 是否区分大小写进行匹配, 默认区分，默认值true
                sensitive: true,
                // 匹配方式
                // start: 检测字符串是否以指定的子字符串开始
                // end：检测字符串是否以指定的子字符串结束
                // all: 检索字符串在整个查询中存在
                matchedCondition: "all",
                // 输入为空时是否显示下拉选项
                isViewItemsWhenNoInput: true,
            },
            enterSelectSupportOption: {
                // 是否支持回车选中， 默认支持，默认值true
                support: true,
                // 支持回车选中情况下定义的选中规则， 默认值 part
                // 目前提供complete(完全匹配) 和 part(部分匹配)两种模式，已存在键盘上、下移键选中
                // complete情况下会根据当前输入文本完全匹配下拉选项的文本，当存在多个选项匹配时，默认选中第一个
                // part情况下会根据当前输入文本模糊匹配，当存在多个选项匹配时，默认选中第一个
                // 优先级：已存在通过键盘上、下键选中的选项 > methods
                methods: "part",
            },
        }).change((function (val, obj) {
            if (obj.$curSelect) {
                curScript = obj.$curSelect;
            }
        }))
    }

    panelRequest.get('/api/scripts', {filterDir: true, onlyRunJs: true}, function (res) {
        let list = [];
        res.data.map((item) => {
            list = list.concat(item.files.map((file) => {
                //let fileName = file.fileName;
                // let name = fileName.substring(0, fileName.indexOf("."));
                return {key: `bash task ${file.filePath}`, value: file.filePath, refreshLog: true}
            }));
        })
        initSearch(list)
    })


    $('.cmd-btn').click(function () {
        const jsName = $(this).attr("data-name");
        const cmd = $(this).attr("data-cmd");
        const refreshLog = $(this).attr("data-refresh-log") !== 'false'
        runCmd(jsName, cmd, refreshLog);
    });

    $runCmd.click(function () {
        runCmd(curScript.value, `${curScript.key} now`, curScript.refreshLog);


    });
    $runCmdConc.click(function () {
        runCmd(curScript.value, `${curScript.key} conc`, false);
    });

    function getLogInterval(jsName) {
        timer && clearInterval(timer);

        // 先执行一次
        getLog(jsName);
        timer = setInterval(() => {
            getLog(jsName);
        }, 1000);
    }

    function getLog(jsName) {
        panelRequest.get(`/api/runLog`, {jsName}, function (res) {
            let data = res.data;
            if (data !== 'no logs') {
                editor.setValue(data);
            }
            !userAgentTools.mobile(navigator.userAgent) && $(".CodeMirror-scroll").css("width", `calc(100% - ${$(".CodeMirror-minimap").width() + 5}px)`);
            //将光标和滚动条设置到文本区最下方
            editor.execCommand('goDocEnd');
        });
    }

    $('#wrap').click(function () {
        var lineWrapping = editor.getOption('lineWrapping');
        editor.setOption('lineWrapping', !lineWrapping);
    });

    $('#move-bottom').click(function () {
        editor.execCommand('goDocEnd');
    })

});
