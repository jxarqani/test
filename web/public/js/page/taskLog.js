var qrcode, userCookie, curDir = "", cruFile = "";
$(document).ready(function () {
    editor = CodeMirror.fromTextArea(document.getElementById("code"), {
        minimap: !userAgentTools.mobile(navigator.userAgent),
        lineNumbers: true,
        lineWrapping: true,
        styleActiveLine: false,
        matchBrackets: true,
        viewportMargin: viewportMargin,
        readOnly: true,
        cursorHeight: 0,
        mode: 'shell',
        theme: themeChange.getAndUpdateEditorTheme(),
    });
    let metisMenu, $menuTree = $('#menuTree');

    function loadData(keywords = '') {
        panelRequest.get('/api/logs', {keywords}, function (res) {
            var dirs = res.data;
            var navHtml = "";
            for (let index in dirs) {
                var dirName = dirs[index].dirName;
                // 文件在log/目录时
                if (dirName === '@') {
                    var row = `<li class="nav-item">`;
                    for (let filesKey in dirs[index].files) {
                        var fileName = dirs[index].files[filesKey];
                        row +=
                            `<a class="nav-link" href="javascript:logDetail('${dirName}', '${fileName}');">${fileName}</a>`
                    }
                    row += `</li>`;
                } else {
                    var row = `<li class="nav-item">
                                <a class="nav-link text-dark has-arrow" href="#">${dirName}</a>
                                <ul class="nav flex-column pl-1">
                                    <li class="nav-item">`;
                    for (let filesKey in dirs[index].files) {
                        var fileName = dirs[index].files[filesKey];
                        row +=
                            `<a class="nav-link" style="padding-left: 2rem;" href="javascript:logDetail('${dirName}', '${fileName}');">${fileName}</a>`
                    }
                    row += `</li>
                                    </ul>
                                </li>`;
                }

                navHtml += row;
            }

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
    $("#refresh").click(function () {
        logDetail(curDir, cruFile, true);
    })
    window.logDetail = function logDetail(dir, file, toEnd) {
        curDir = dir;
        cruFile = file;
        if (window.innerWidth < 993 && !toEnd) {
            dispatch(document.getElementById('toggleIcon'), 'click');
        }

        panelRequest.get(`/api/logs/${dir}/${file}`, function (res) {
            if (res.code === 1) {
                editor.setValue(res.data);
                !userAgentTools.mobile(navigator.userAgent) && $(".CodeMirror-scroll").css("width", `calc(100% - ${$(".CodeMirror-minimap").width() + 5}px)`);
            }
            if (toEnd) {
                //将光标和滚动条设置到文本区最下方
                editor.execCommand('goDocEnd');
            }
        });
    }

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

    }
});
