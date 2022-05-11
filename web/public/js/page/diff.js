let origLeft, origRight;

function initUI() {
    editor = CodeMirror.MergeView(document.getElementById('compare'), {
        value: origLeft,
        minimap: false,
        origLeft: null,
        orig: origRight,
        lineNumbers: true,
        styleActiveLine: true,
        lineWrapping: true,
        mode: 'shell',
        viewportMargin: viewportMargin,
        theme: themeChange.getAndUpdateEditorTheme(),
        keyMap: 'sublime',
        highlightDifferences: true,
        connect: null,
        collapseIdentical: false
    });
}

$(document).ready(function () {
    panelRequest.get('/api/config/config', {}, (config) => {
        origLeft = config.data;
        panelRequest.get('/api/config/sample', {}, (sample) => {
            origRight = sample.data;
            initUI();
        })
    })
    $('#prev').click(function () {
        editor.editor().execCommand('goPrevDiff');
    });

    $('#next').click(function () {
        editor.editor().execCommand('goNextDiff');
    });

    $('#wrap').click(function () {
        var lineWrapping = editor.editor().getOption('lineWrapping');
        editor.editor().setOption('lineWrapping', !lineWrapping);
        editor.rightOriginal().setOption('lineWrapping', !lineWrapping);
    });

    $('#save').click(function () {
        var confContent = editor.editor().getValue();
        panelRequest.post('/api/save', {
            content: confContent,
            name: "config.sh"
        }, function (res) {
            res.code === 1 && panelUtils.showSuccess(res.msg);
        });
    });

})
