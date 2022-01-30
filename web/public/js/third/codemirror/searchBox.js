/* global CodeMirror */
/* global define */

(function (mod) {
    'use strict';

    if (typeof exports === 'object' && typeof module === 'object') // CommonJS
        mod(require('../../lib/codemirror'));
    else if (typeof define === 'function' && define.amd) // AMD
        define(['../../lib/codemirror'], mod);
    else
        mod(CodeMirror);
})(function (CodeMirror) {
    'use strict';

    var Search;

    CodeMirror.defineOption('searchbox', false, function (cm) {
        cm.addKeyMap({
            'Ctrl-F': function () {
                if (!Search)
                    Search = new SearchBox(cm);

                Search.show();
            },

            'Esc': function () {
                if (Search && Search.isVisible()) {
                    Search.hide();

                    if (typeof event !== 'undefined')
                        event.stopPropagation();
                }

                return false;
            },

            'Cmd-F': function () {
                if (!Search)
                    Search = new SearchBox(cm);

                Search.show();
            }
        });
    });

    function SearchBox(cm) {
        var self = this;

        init();

        function initElements(el) {
            self.searchBox = el.querySelector('.ace_search_form');
            self.replaceBox = el.querySelector('.ace_replace_form');
            self.searchOptions = el.querySelector('.ace_search_options');

            self.searchPrevBtn = el.querySelector('.ace_searchbtn_prev');
            self.searchNextBtn = el.querySelector('.ace_searchbtn_next');
            self.searchReplaceBtn = el.querySelector('.ace_replacebtn.single');
            self.searchReplaceAllBtn = el.querySelector('.ace_replacebtn.all');

            self.regExpOption = el.querySelector('[action=toggleRegexpMode]');
            self.caseSensitiveOption = el.querySelector('[action=toggleCaseSensitive]');
            self.wholeWordOption = el.querySelector('[action=toggleWholeWords]');

            self.searchInput = self.searchBox.querySelector('.ace_search_field');
            self.replaceInput = self.replaceBox.querySelector('.ace_search_field');

            self.btnDisabledClass = "btn-disabled"
        }

        function init() {
            var el = self.element = addHtml();

            initElements(el);
            bindKeys();

            el.addEventListener('mousedown', function (e) {
                setTimeout(function () {
                    self.activeInput.focus();
                }, 0);

                e.stopPropagation();
            });

            el.addEventListener('click', function (e) {
                var t = e.target || e.srcElement;
                var action = t.getAttribute('action');
                if(action && (!t.classList.contains(self.btnDisabledClass) ||( t.parentNode && !t.parentNode.classList.contains(self.btnDisabledClass)))){
                    if (self[action])
                        self[action]();
                    else if (self.commands[action])
                        self.commands[action]();
                }
                e.stopPropagation();
            });

            self.searchInput.addEventListener('input', function () {
                let searchVal = self.searchInput.value;
                if(searchVal && searchVal !== ""){
                    setCssClass(self.searchNextBtn,self.btnDisabledClass ,false)
                    setCssClass(self.searchPrevBtn,self.btnDisabledClass  ,false)
                    setCssClass(self.searchReplaceBtn,self.btnDisabledClass  ,false)
                    setCssClass(self.searchReplaceAllBtn,self.btnDisabledClass  ,false)
                }else {
                    setCssClass(self.searchNextBtn,self.btnDisabledClass ,true)
                    setCssClass(self.searchPrevBtn,self.btnDisabledClass  ,true)
                    setCssClass(self.searchReplaceBtn,self.btnDisabledClass  ,true)
                    setCssClass(self.searchReplaceAllBtn,self.btnDisabledClass  ,true)
                }
                self.$onChange.schedule(20);
            });

            self.searchInput.addEventListener('focus', function () {
                self.activeInput = self.searchInput;
            });

            self.replaceInput.addEventListener('focus', function () {
                self.activeInput = self.replaceInput;
            });

            self.$onChange = delayedCall(function () {
                self.find(false, false);
            });
        }

        function bindKeys() {
            var sb = self,
                obj = {
                    'Ctrl-F|Cmd-F|Ctrl-H|Command-Alt-F': function () {
                        var isReplace = sb.isReplace = !sb.isReplace;
                        sb.replaceBox.style.display = isReplace ? '' : 'none';
                        sb[isReplace ? 'replaceInput' : 'searchInput'].focus();
                    },
                    'Ctrl-G|Cmd-G': function () {
                        sb.findNext();
                    },
                    'Ctrl-Shift-G|Cmd-Shift-G': function () {
                        sb.findPrev();
                    },
                    'Esc': function () {
                        setTimeout(function () {
                            sb.hide();
                        });
                    },
                    'Enter': function () {
                        if (sb.activeInput === sb.replaceInput)
                            sb.replace();
                        sb.findNext();
                    },
                    'Shift-Enter': function () {
                        if (sb.activeInput === sb.replaceInput)
                            sb.replace();
                        sb.findPrev();
                    },
                    'Alt-Enter': function () {
                        if (sb.activeInput === sb.replaceInput)
                            sb.replaceAll();
                        sb.findAll();
                    },
                    'Tab': function () {
                        if (self.activeInput === self.replaceInput)
                            self.searchInput.focus();
                        else
                            self.replaceInput.focus();
                    }
                };

            self.element.addEventListener('keydown', function (event) {
                Object.keys(obj).some(function (name) {
                    var is = key(name, event);

                    if (is) {
                        event.stopPropagation();
                        event.preventDefault();
                        obj[name](event);
                    }

                    return is;
                });
            });
        }

        this.commands = {
            toggleRegexpMode: function () {
                self.regExpOption.checked = !self.regExpOption.checked;
                self.$syncOptions();
            },

            toggleCaseSensitive: function () {
                self.caseSensitiveOption.checked = !self.caseSensitiveOption.checked;
                self.$syncOptions();
            },

            toggleWholeWords: function () {
                self.wholeWordOption.checked = !self.wholeWordOption.checked;
                self.$syncOptions();
            }
        };

        this.$syncOptions = function () {
            setCssClass(this.regExpOption, 'checked', this.regExpOption.checked);
            setCssClass(this.wholeWordOption, 'checked', this.wholeWordOption.checked);
            setCssClass(this.caseSensitiveOption, 'checked', this.caseSensitiveOption.checked);

            this.find(false, false);
        };

        this.find = function (skipCurrent, backwards) {
            var value = this.searchInput.value,
                options = {
                    skipCurrent: skipCurrent,
                    backwards: backwards,
                    regExp: this.regExpOption.checked,
                    caseSensitive: this.caseSensitiveOption.checked,
                    wholeWord: this.wholeWordOption.checked
                };

            find(value, options, function (searchCursor) {
                var current = searchCursor.matches(false, searchCursor.from());
                cm.setSelection(current.from, current.to);
            });
        };

        function find(value, options, callback) {
            var done,
                noMatch, searchCursor, next, prev, matches, cursor,
                position,
                o = options,
                is = true,
                caseSensitive = o.caseSensitive,
                regExp = o.regExp,
                wholeWord = o.wholeWord;

            if (regExp || wholeWord) {
                if (options.wholeWord)
                    value = '\\b' + value + '\\b';

                value = RegExp(value);
            }

            if (o.backwards)
                position = o.skipCurrent ? 'from' : 'to';
            else
                position = o.skipCurrent ? 'to' : 'from';

            cursor = cm.getCursor(position);
            searchCursor = cm.getSearchCursor(value, cursor, !caseSensitive);

            next = searchCursor.findNext.bind(searchCursor),
                prev = searchCursor.findPrevious.bind(searchCursor),
                matches = searchCursor.matches.bind(searchCursor);

            if (o.backwards && !prev()) {
                is = next();

                if (is) {
                    cm.setCursor(cm.doc.size - 1, 0);
                    find(true, true, callback);
                    done = true;
                }
            } else if (!o.backwards && !next()) {
                is = prev();

                if (is) {
                    cm.setCursor(0, 0);
                    find(true, false, callback);
                    done = true;
                }
            }

            noMatch = !is && self.searchInput.value;
            setCssClass(self.searchBox, 'ace_nomatch', noMatch);

            if (!done && is)
                callback(searchCursor);
        }

        this.findNext = function () {
            this.find(true, false);
        };

        this.findPrev = function () {
            this.find(true, true);
        };

        this.findAll = function () {
            /*
            var range = this.editor.findAll(this.searchInput.value, {
                regExp: this.regExpOption.checked,
                caseSensitive: this.caseSensitiveOption.checked,
                wholeWord: this.wholeWordOption.checked
            });
            */

            var value = this.searchInput.value,
                range,
                noMatch = !range && this.searchInput.value;

            setCssClass(this.searchBox, 'ace_nomatch', noMatch);

            if (cm.showMatchesOnScrollbar)
                cm.showMatchesOnScrollbar(value);

            this.hide();
        };

        this.replace = function () {
            if (!cm.getOption('readOnly'))
                cm.replaceSelection(this.replaceInput.value, 'start');
        };

        this.replaceAndFindNext = function () {
            if (!cm.getOption('readOnly')) {
                this.replace();
                this.findNext();
            }
        };

        this.replaceAll = function () {
            var value,
                cursor,
                from = this.searchInput.value,
                to = this.replaceInput.value,
                reg = RegExp(from, 'g');

            if (!cm.getOption('readOnly')) {
                cursor = cm.getCursor();
                value = cm.getValue();
                value = value.replace(reg, to);

                cm.setValue(value);
                cm.setCursor(cursor);
            }
        };

        this.hide = function () {
            this.element.style.display = 'none';
            cm.focus();
        };

        this.isVisible = function () {
            var is = this.element.style.display === '';

            return is;
        };

        this.show = function (value, isReplace) {
            this.element.style.display = '';
            this.replaceBox.style.display = isReplace ? '' : 'none';

            this.isReplace = isReplace;

            if (value)
                this.searchInput.value = value;

            this.searchInput.focus();
            this.searchInput.select();
        };

        this.isFocused = function () {
            var el = document.activeElement;
            return el === this.searchInput || el === this.replaceInput;
        };


        function addHtml() {
            var elSearch,
                el = document.querySelector('.CodeMirror'),
                div = document.createElement('div'),
                html = [
                    '<div class="ace_search right">',
                    '<div class="ace_search_form">',
                    '<input class="ace_search_field" placeholder="查找" spellcheck="false"></input>',
                    '<div class="ace_search button">',
                    '<span action="toggleCaseSensitive" class="ace_button" title="区分大小写">𝖠𝖺</span>',
                    '<span action="toggleWholeWords" class="ace_button" title="全字匹配">全</span>',
                    '<span action="toggleRegexpMode" class="ace_button" title="使用正则表达式">.*</span>',
                    '</div>',
                    '<div class="ace_search button">',
                    '<button type="button" action="findPrev" class="ace_searchbtn_prev btn-disabled" title="上一个匹配项"><i action="findPrev" class="fa fa-chevron-left" style="font-size:15px;"></i></button>',
                    '<button type="button" action="findNext" class="ace_searchbtn_next btn-disabled" title="下一个匹配项"><i action="findNext" class="fa fa-chevron-right" style="font-size:15px;"></i></button>',
                    '<button type="button" action="hide" class="ace_searchbtn_close" title="关闭"><i action="hide" class="fa fa-close" style="font-size:17px;"></i></button>',
                    '</div>',
                    '</div>',
                    '<div class="ace_replace_form">',
                    '<input class="ace_search_field" placeholder="替换" spellcheck="false"></input>',
                    '<div class="ace_search replace">',
                    '<button type="button" action="replaceAndFindNext" class="ace_replacebtn single btn-disabled" title="单处替换">⠀</button>',
                    '<button type="button" action="replaceAll" class="ace_replacebtn all btn-disabled" title="全部替换">⠀</button>',
                    '</div>',
                    '</div>',
                    '</div>',
                    '</div>',
                ].join('');

            div.innerHTML = html;

            elSearch = div.firstChild;

            el.parentElement.appendChild(elSearch);

            return elSearch;
        }
    }

    function setCssClass(el, className, condition) {
        var list = el.classList;

        list[condition ? 'add' : 'remove'](className);
    }

    function delayedCall(fcn, defaultTimeout) {
        var timer,
            callback = function () {
                timer = null;
                fcn();
            },

            _self = function (timeout) {
                if (!timer)
                    timer = setTimeout(callback, timeout || defaultTimeout);
            };

        _self.delay = function (timeout) {
            timer && clearTimeout(timer);
            timer = setTimeout(callback, timeout || defaultTimeout);
        };
        _self.schedule = _self;

        _self.call = function () {
            this.cancel();
            fcn();
        };

        _self.cancel = function () {
            timer && clearTimeout(timer);
            timer = null;
        };

        _self.isPending = function () {
            return timer;
        };

        return _self;
    }

    /* https://github.com/coderaiser/key */
    function key(str, event) {
        var right,
            KEY = {
                BACKSPACE: 8,
                TAB: 9,
                ENTER: 13,
                ESC: 27,

                SPACE: 32,
                PAGE_UP: 33,
                PAGE_DOWN: 34,
                END: 35,
                HOME: 36,
                UP: 38,
                DOWN: 40,

                INSERT: 45,
                DELETE: 46,

                INSERT_MAC: 96,

                ASTERISK: 106,
                PLUS: 107,
                MINUS: 109,

                F1: 112,
                F2: 113,
                F3: 114,
                F4: 115,
                F5: 116,
                F6: 117,
                F7: 118,
                F8: 119,
                F9: 120,
                F10: 121,

                SLASH: 191,
                TRA: 192, /* Typewritten Reverse Apostrophe (`) */
                BACKSLASH: 220
            };

        keyCheck(str, event);

        right = str.split('|').some(function (combination) {
            var wrong;

            wrong = combination.split('-').some(function (key) {
                var right;

                switch (key) {
                    case 'Ctrl':
                        right = event.ctrlKey;
                        break;

                    case 'Shift':
                        right = event.shiftKey;
                        break;

                    case 'Alt':
                        right = event.altKey;
                        break;

                    case 'Cmd':
                        right = event.metaKey;
                        break;

                    default:
                        if (key.length === 1)
                            right = event.keyCode === key.charCodeAt(0);
                        else
                            Object.keys(KEY).some(function (name) {
                                var up = key.toUpperCase();

                                if (up === name)
                                    right = event.keyCode === KEY[name];
                            });
                        break;
                }

                return !right;
            });

            return !wrong;
        });

        return right;
    }

    function keyCheck(str, event) {
        if (typeof str !== 'string')
            throw(Error('str should be string!'));

        if (typeof event !== 'object')
            throw(Error('event should be object!'));
    }

});
