let BASE_API_PATH = location.origin;
let BASE_PATH = location.href;
let BASE_PATH_NAME = location.pathname;
let editor, lastLoginInfo;

function copyToClip(content, message) {
    var aux = document.createElement("input");
    aux.setAttribute("value", content);
    document.body.appendChild(aux);
    aux.select();
    document.execCommand("copy");
    document.body.removeChild(aux);
}

function showLastLoginInfo() {
    lastLoginInfo = JSON.parse(localStorage.getItem("lastLoginInfo") || "{}");

    if (lastLoginInfo && lastLoginInfo.loginIp) {
        panelUtils.showAlert({
            position: 'top-end',
            //title: '登录成功',
            //icon:'info',
            backdrop: false,
            toast: true,
            timer: 10000,
            grow: 'row',
            showConfirmButton: true,
            confirmButtonText: '知道了',
            timerProgressBar: true,
            html:
                `<div class="login-toast"><div><b>上次登录时间</b>：${lastLoginInfo.loginTime}</div>` +
                `<div><b>上次登录IP</b>：${lastLoginInfo.loginIp || '未知'}</div>` +
                `<div><b>上次登录地点</b>：${lastLoginInfo.loginAddress || '未知'}</div></div>`
        })
        localStorage.removeItem("lastLoginInfo");
    }
}


let themeChange = {
    THEMES: {
        DARK: "DARK", LIGHT: "LIGHT"
    },
    THEME_CACHE_KEY: "LOCAL_THEME",
    getCurTheme() {
        return localStorage.getItem(this.THEME_CACHE_KEY) || this.THEMES.LIGHT
    },
    saveTheme(theme) {
        localStorage.setItem(this.THEME_CACHE_KEY, theme || this.THEMES.LIGHT)
    },
    getAndUpdateEditorTheme(theme) {
        if (!theme) {
            theme = this.getCurTheme();
        }
        let isLight = theme === this.THEMES.LIGHT;
        let editorTheme = isLight ? "juejin" : "panda-syntax";
        if (editor) {
            this.changeEditorTheme(editor, editorTheme);
        }
        let $mobileMenu = $("nav[id=mobile-menu]");
        if ($mobileMenu) {
            if (isLight) {
                $mobileMenu.removeClass("mm--dark")
            } else {
                $mobileMenu.addClass("mm--dark")
            }
        }
        return editorTheme
    },
    changeEditorTheme(editor, editorTheme) {
        try {
            if (editor.wrap) {
                this.changeEditorTheme(editor.editor(), editorTheme)
            }
            if (editor.right) {
                this.changeEditorTheme(editor.right.orig, editorTheme)
            }
            let $editor = $(editor.getWrapperElement());
            $editor.hide();
            editor.setOption("theme", editorTheme);
            $editor.fadeIn(500)

        } catch (e) {
        }

    },
    updatePageTheme(theme) {
        let isLight = theme === this.THEMES.LIGHT;
        let $container = $(".container");
        if ($container) {
            if (isLight) {
                $container.removeClass("dark").addClass("light")
            } else {
                $container.removeClass("light").addClass("dark")
            }
        }
    },
    loadTheme(theme) {
        if (!this.THEMES.hasOwnProperty(theme)) {
            console.warn("当前仅支持 DARK/LIGHT 切换")
            theme = this.getCurTheme();
        }
        this.getAndUpdateEditorTheme(theme);
        this.updatePageTheme(theme);
        this.saveTheme(theme);
    }
}

let MenuTools = {
    menuList: [{
        title: "编辑配置",
        faIcon: "fa-pencil-square-o",
        path: "#",
        customClass: "highlight",
        subMenuCustomClass: "double",
        bottomContent: '<div class="content">' +
            // '<div class="item bottom-left" ><img class="qr-img" src="/icon/jx.png"/><a target="_blank" href="https://"><span class="title red-font">打开京东/微信扫码，每日可领取三次红包！</span></a></div>' +
            '<div class="item bottom-right"><span class="title"><i class="fa fa-comments"></i> 关注官方 Telegram 频道获取最新消息 </span><a class="link-btn" href="https://t.me/jdhelloworld">立即关注</a></div></div>',
        children: [
            // {
            //     title: "京东1111红包",
            //     faIcon: "fa-thumbs-up",
            //     titleFaIcon: "fa-hand-o-right",
            //     subText: "京东1111红包",
            //     platform: "mobile",
            //     customClass: 'red-font',
            //     path: "https://",
            // },
            {
                title: "环境变量",
                faIcon: "fa-home",
                titleFaIcon: "fa-arrow-right",
                subText: "编辑主配置文件",
                customClass: 'gb a',
                path: "/config"
            }, {
                title: "账号配置",
                faIcon: "fa-user-circle",
                titleFaIcon: "fa-arrow-right",
                subText: "编辑账号配置文件",
                customClass: 'gb e',
                path: "/remarks"
            }, {
                title: "定时任务",
                faIcon: "fa-clock-o",
                titleFaIcon: "fa-arrow-right",
                subText: "配置 Crontab 定时任务",
                customClass: 'gb d',
                path: "/crontab"
            }, {
                title: "对比工具",
                faIcon: "fa-columns",
                titleFaIcon: "fa-arrow-right",
                subText: "将配置文件与最新模板进行比较",
                customClass: 'gb g',
                path: "/diff"
            }, {
                title: "机器人配置",
                faIcon: "fa-telegram",
                titleFaIcon: "fa-arrow-right",
                subText: "编辑 Bot 配置文件",
                customClass: 'gb',
                path: "/bot"
            }, {
                title: "自定义脚本",
                faIcon: "fa-file-text-o",
                titleFaIcon: "fa-arrow-right",
                subText: "编辑 Extra 脚本",
                customClass: 'gb h',
                path: "/extra"
            }]
    }, {
        title: "执行工具",
        faIcon: "fa-list-alt",
        path: "#",
        customClass: "",
        subMenuCustomClass: "",
        bottomContent: '',
        children: [{
            title: "快速执行",
            faIcon: "fa-play-circle",
            titleFaIcon: "fa-arrow-right",
            subText: "执行相关命令或运行指定脚本",
            customClass: 'gb i',
            path: "/run"
        }, {
            title: "命令行",
            faIcon: "fa-terminal",
            titleFaIcon: "fa-arrow-right",
            subText: "网页共享终端",
            customClass: 'gb b',
            path: "/terminal"
        }, {
            title: "官方文档",
            faIcon: "fa fa-tv",
            titleFaIcon: "fa-external-link",
            subText: "关于本项目的所有文档内容",
            customClass: 'gb c',
            path: "javascript:window.open('https://supermanito.github.io/Helloworld')"
        }]
    }, {
        title: "文件浏览",
        faIcon: "fa-folder",
        path: "#",
        customClass: "",
        subMenuCustomClass: "",
        bottomContent: '',
        children: [{
            title: "查询日志",
            faIcon: "fa-history",
            titleFaIcon: "fa-arrow-right",
            subText: "查看脚本运行日志",
            customClass: 'gb d',
            path: "/taskLog"
        }, {
            title: "脚本管理",
            faIcon: "fa-file-code-o",
            titleFaIcon: "fa-arrow-right",
            subText: "浏览或编辑脚本内容",
            customClass: 'gb e',
            path: "/viewScripts"
        }]
    }, {
        title: "选项设置",
        faIcon: "fa-cog",
        path: "#",
        customClass: "",
        subMenuCustomClass: "",
        bottomContent: '',
        children: [{
            title: "修改密码",
            faIcon: "fa-lock",
            titleFaIcon: "fa-arrow-right",
            subText: "Change Password",
            customClass: 'gb l',
            path: "/changePwd"
        }, {
            title: "退出登陆",
            faIcon: "fa-sign-out",
            titleFaIcon: "fa-hand-o-right",
            subText: "Sign Out",
            customClass: 'gb r',
            path: "/logout"
        }, {
            title: "切换主题",
            faIcon: "fa-delicious",
            titleFaIcon: "fa-sliders",
            subText: "浅色模式 | 深色模式",
            customClass: 'gb k',
            path: "#",
            mobileCustom: {
                customClass: 'mobile-daynight',
                customContent: '<span class="title">切换主题</span>'
            },
            customContent: '<div class="toggle toggle--daynight">\n' +
                '                                    <input type="checkbox" id="toggle--daynight" class="toggle--checkbox">\n' +
                '                                    <label class="toggle--btn" for="toggle--daynight">\n' +
                '                                        <span class="toggle--feature"></span>\n' +
                '                                    </label>\n' +
                '                                </div>'
        }]
    }],
    getMenuDom() {
        return document.getElementById("menu");
    },
    getMobileMenuDom() {
        return document.getElementById("mobile-menu");
    },
    resolveMobileMenu() {
        let menuDom = this.getMobileMenuDom();
        if (!menuDom) {
            return;
        }
        let content = "<ul>";
        this.menuList.map((menu, i) => {
            menu.children.map((child, index) => {
                if (!child.platform || (child.platform && child.platform === 'mobile')) {
                    content = content.concat(
                        `<li class="'${child.customClass}' ${child.mobileCustom && child.mobileCustom.customClass || ''}">`,
                        child.mobileCustom ? child.mobileCustom.customContent : `<a href="${child.path || '#'}"><i class="fa ${child.faIcon}"></i> ${child.title}</a>`,
                        child.customContent || '',
                        `</li>`
                    )
                }
            });
        });
        content = content.concat('</ul>');
        menuDom.innerHTML = content;
        this.resolveEvent();
        mobileNavInit();
    },
    resolveMenu() {
        let menuDom = this.getMenuDom();
        if (!menuDom) {
            MenuTools.resolveMobileMenu();
            return;
        }
        let content = "";
        this.menuList.map((menu, i) => {
            content = content.concat(
                `<div class="menu-item ${menu.customClass}">`,
                `<div class="menu-text"><a href="${menu.path || '#'}"><i class="fa ${menu.faIcon}"></i> ${menu.title}</a></div>`,
                `<div class="sub-menu ${menu.subMenuCustomClass}">`)
            menu.children.map((child, index) => {
                if (!child.platform || (child.platform && child.platform === 'pc')) {
                    content = content.concat(
                        `<a href="${child.path || '#'}"><div class="icon-box ${child.customClass} ${child.path === BASE_PATH_NAME && 'active'}">`,
                        `<div class="icon"><i class="fa ${child.faIcon}"></i></div>`,
                        `<div class="text"><div class="title">${child.title} <i class="fa ${child.path === BASE_PATH_NAME && child.titleFaIcon === 'fa-arrow-right' ? 'fa-map-marker' : child.titleFaIcon}"></i></div><div class="sub-text">${child.subText}</div></div>`,
                        `${child.customContent || ''}`,
                        `</div></a>`
                    )
                    if (menu.bottomContent && menu.children.length === index + 1) {
                        content = content.concat('<div class="bottom-container">', menu.bottomContent, '</div>');
                    }
                }
            });
            content = content.concat('</div></div>');
        });
        content = content.concat('<!--container--><div id="sub-menu-container"><div id="sub-menu-holder"><div id="sub-menu-bottom"></div></div></div>');
        menuDom.innerHTML = content;
        this.resolveEvent();
    },
    resolveEvent() {
        let $toggle_daynight = $("#toggle--daynight");
        $toggle_daynight.attr("checked", themeChange.getCurTheme() === themeChange.THEMES.LIGHT);
        let theme = themeChange.getCurTheme();
        themeChange.updatePageTheme(theme);
        $toggle_daynight.change(function () {
            themeChange.loadTheme($(this).is(':checked') ? themeChange.THEMES.LIGHT : themeChange.THEMES.DARK)
        })
    }
}


$(document).ready(function () {
    $.ajaxSetup({
        cache: false
    });
    MenuTools.resolveMenu();
    showLastLoginInfo();
    themeChange.loadTheme();
})

let panelUtils = {
    showLoading(text) {
        panelUtils.showAlert({
            text: text || "加载中...",
            showConfirmButton: false,
            imageUrl: "../icon/loading.gif",
            imageWidth: 160,
            width: 300,
            imageHeight: 120,
            background: "#fff",
            showCancelButton: false,
        });
    },
    hideLoading() {
        Swal.hideLoading();
    },
    showAlert(opts) {
        return Swal.fire(opts)
    },
    showSuccess(msg = "", desc = "", reload = false) {
        panelUtils.showAlert({
            title: msg,
            html: desc,
            icon: 'success'
        }).then((result) => {
            reload && window.location.reload(true);
        })
    },
    showError(title, text, desc) {
        let options = {
            text: title,
            icon: 'error'
        }
        if (text) {
            options.text = text;
            options.title = title
        }
        if (desc) {
            options.title = text
            options['html'] = desc;
        }
        this.showAlert(options)
    },
    showWarning(title, text, confirmButtonText) {
        return panelUtils.showAlert({
            title: title,
            text: text,
            icon: "warning",
            //confirmButtonColor: "#DD6B55",
            confirmButtonText: confirmButtonText,
        })
    }
}

var userAgentTools = {
    Android: function (userAgent) {
        return (/android/i.test(userAgent.toLowerCase()));
    },
    BlackBerry: function (userAgent) {
        return (/blackberry/i.test(userAgent.toLowerCase()));
    },
    iOS: function (userAgent) {
        return (/iphone|ipad|ipod/i.test(userAgent.toLowerCase()));
    },
    iPhone: function (userAgent) {
        return (/iphone/i.test(userAgent.toLowerCase()));
    },
    iPad: function (userAgent) {
        return (/ipad/i.test(userAgent.toLowerCase()));
    },
    iPod: function (userAgent) {
        return (/ipod/i.test(userAgent.toLowerCase()));
    },
    Opera: function (userAgent) {
        return (/opera mini/i.test(userAgent.toLowerCase()));
    },
    Windows: function (userAgent) {
        return (/iemobile/i.test(userAgent.toLowerCase()));
    },
    Pad: function (userAgent) {
        return (/pad|m2105k81ac/i.test(userAgent.toLowerCase()));
    },
    mobile: function (userAgent) {
        if (userAgentTools.Pad(userAgent)) {
            return false;
        }
        return (userAgentTools.Android(userAgent) || userAgentTools.iPhone(userAgent) || userAgentTools.BlackBerry(userAgent));
    }
};

let panelRequest = {
    resultCallback(success, result, fail) {
        if (result.code === 1) {
            success && success(result);
        } else if (result.code === 403) {
            panelUtils.showAlert({
                title: "请求出错",
                html: result.msg,
                icon: "error"
            }).then((result) => {
                location.href = "/auth";
            })
        } else {
            if (result.desc) {
                panelUtils.showError(result.msg, result.msg, result.desc)
            } else {
                panelUtils.showError("请求出错", result.msg)
            }

            fail && fail(result);
        }
    },
    get(url, params = {}, success) {
        if (arguments.length === 2 && typeof params === 'function') {
            $.get(BASE_API_PATH + url, {}, (result) => {
                this.resultCallback(params, result);
            }, "json");
        } else {
            $.get(BASE_API_PATH + url, params, (result) => {
                this.resultCallback(success, result);
            }, "json");
        }

    },
    post(url, data = {}, success, fail) {
        $.post(BASE_API_PATH + url, data, (result) => {
            this.resultCallback(success, result, fail);
        }, "json");
    }
}

// codeMirror指定当前滚动到视图中内容上方和下方要渲染的行数，pc端适当调大，便于文本搜索
var viewportMargin = userAgentTools.mobile(navigator.userAgent) ? 10 : 1000;
let minimapVal = !userAgentTools.mobile(navigator.userAgent) ? {scale: 5} : false;
// window.onresize = function(){
//     window.location.reload();
// }
