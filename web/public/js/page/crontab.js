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
    panelRequest.get('/api/config/crontab', function (res) {
        editor.setValue(res.data);
        !userAgentTools.mobile(navigator.userAgent) && $(".CodeMirror-scroll").css("width", `calc(100% - ${$(".CodeMirror-minimap").width() + 5}px)`);
    });

    $('#save').click(function () {
        var confContent = editor.getValue();
        panelRequest.post('/api/save', {
            content: confContent,
            name: "crontab.list"
        }, function (res) {
            res.code === 1 && panelUtils.showSuccess(res.msg, '已同步更新定时任务');
        });
    });

    $('#wrap').click(function () {
        var lineWrapping = editor.getOption('lineWrapping');
        editor.setOption('lineWrapping', !lineWrapping);
    });
});
