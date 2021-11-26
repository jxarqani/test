var qrcode, userCookie, curPath;
$(document).ready(function () {
    editor = CodeMirror.fromTextArea(document.getElementById("code"), {
        minimap: minimapVal,
        lineNumbers: true,
        lineWrapping: true,
        styleActiveLine: true,
        matchBrackets: true,
        viewportMargin: viewportMargin,
        readOnly: false,
        mode: 'javascript',
        theme: themeChange.getAndUpdateEditorTheme(),
    });
    let metisMenu, $menuTree = $('#menuTree'), $scriptsSaveBtn = $('#save');
    $scriptsSaveBtn.hide();

    function createFileTree(dirs) {
        let navHtml = ``
        dirs.map((item, index) => {
            if (typeof item === 'object' && item.dirName) {
                navHtml += `<li class="nav-item ${item.dirPath === 'scripts' ? 'mm-active' : ''}">`
                navHtml += `<a class="nav-link text-dark has-arrow" href="#">${item.dirName}</a>`
                navHtml += `<ul class="nav flex-column pl-1">${createFileTree(item.files)}</ul>`
            } else {
                navHtml += `<li class="nav-item">`
                navHtml += `<a class="nav-link" href="javascript:viewScript('${item.filePath}');">${item.fileName}</a>`
            }
            navHtml += `</li>`;
        })

        return navHtml;
    }

    function loadData(keywords = '') {
        panelRequest.get('/api/scripts', {keywords}, function (res) {
            let navHtml = createFileTree(res.data);
            $menuTree.metisMenu('dispose')
            $menuTree.html(navHtml);
            metisMenu = $menuTree.metisMenu();
        });
    }

    loadData();
    $("#submitSearch").click(function () {
        loadData($("#searchInput").val())
    })
    $('#searchInput').bind('keypress', function (event) {
        if (event.keyCode === 13) {
            $("#submitSearch").click();
        }
    });
    window.viewScript = function viewScript(path) {
        if (window.innerWidth < 993) {
            dispatch(document.getElementById('toggleIcon'), 'click');
        }

        panelRequest.get(`/api/scripts/content`, {path: path}, function (res) {
            editor.setValue(res.data);
            curPath = path;
            $scriptsSaveBtn.show();
            !userAgentTools.mobile(navigator.userAgent) && $(".CodeMirror-scroll").css("width", `calc(100% - ${$(".CodeMirror-minimap").width() + 5}px)`);
        });
    }
    $scriptsSaveBtn.click(function () {
        panelRequest.post('/api/scripts/save', {
            content: editor.getValue(),
            name: curPath
        }, function (res) {
            res.code === 1 && panelUtils.showSuccess(res.msg, res.desc,false);
        });
    });

    $('#toggleIcon').click(() => {
        setTimeout(() => {
            !userAgentTools.mobile(navigator.userAgent) && $(".CodeMirror-scroll").css("width", `calc(100% - ${$(".CodeMirror-minimap").width() + 5}px)`);
        }, 100);
    });

    $('#wrap').click(function () {
        var lineWrapping = editor.getOption('lineWrapping');
        editor.setOption('lineWrapping', !lineWrapping);
    });


    //自动触发事件
    function dispatch(ele, type) {
        try {
            if (ele.dispatchEvent) { //标准浏览器

                var evt = document.createEvent('Event');
                evt.initEvent(type, true, true);
                ele.dispatchEvent(evt);
            } else {
                ele.fireEvent('on' + type);
            }
        } catch (e) {
        }
        ;

    }
});
