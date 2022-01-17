'use strict';

var placeholders = document.querySelectorAll('.styled-input__placeholder-text'),
    inputs = document.querySelectorAll('.styled-input__input');

placeholders.forEach(function (el, i) {
    var value = el.innerText,
        html = '';
    for (var _iterator = value, _isArray = Array.isArray(_iterator), _i = 0, _iterator = _isArray ? _iterator : _iterator[Symbol.iterator](); ;) {
        var _ref;

        if (_isArray) {
            if (_i >= _iterator.length) break;
            _ref = _iterator[_i++];
        } else {
            _i = _iterator.next();
            if (_i.done) break;
            _ref = _i.value;
        }

        var w = _ref;

        if (!value) value = '&nbsp;';
        html += '<span class="letter">' + w + '</span>';
    }
    el.innerHTML = html;
});

inputs.forEach(function (el) {
    var parent = el.parentNode;
    el.addEventListener('focus', function () {
        parent.classList.add('filled');
        //placeholderAnimationIn(parent, true);
    }, false);
    el.addEventListener('blur', function () {
        if (el.value.length) return;
        parent.classList.remove('filled');
        //placeholderAnimationIn(parent, false);
    }, false);
});

function placeholderAnimationIn(parent, action) {
    var act = action ? 'add' : 'remove';
    var letters = parent.querySelectorAll('.letter');
    letters = [].slice.call(letters, 0);
    if (!action) letters = letters.reverse();
    letters.forEach(function (el, i) {
        setTimeout(function () {
            var contains = parent.classList.contains('filled');
            if (action && !contains || !action && contains) return;
            el.classList[act]('active');
        }, 50 * i);
    });
}

setTimeout(function () {
   $(document.body).addClass('on-start');
}, 100);

setTimeout(function () {
    $(document.body).addClass('document-loaded');
}, 1800);

const $passwordInput = $('#password');
const $rePasswordInput = $('#confirm-password');
const $togglePasswordButton = $('#toggle-password');
$passwordInput.addClass('input-password');
$rePasswordInput.removeClass('d-none');

$togglePasswordButton.click(togglePassword);

function togglePassword() {
    if ($passwordInput.attr('type') === 'password') {
        $passwordInput.attr('type', 'text');
        $rePasswordInput.attr('type', 'text');
        $togglePasswordButton.attr('aria-label', 'Hide password.').addClass('hide-password');
    } else {
        $passwordInput.attr('type', 'password');
        $rePasswordInput.attr('type', 'password');
        $togglePasswordButton.attr(
            'aria-label',
            'Show password as plain text. Warning: this will display your password on the screen.'
        ).removeClass('hide-password');
    }
}

let showCaptcha = false;

function checkNeedCaptcha(flag = false) {
    let $captchaInput = $('.captcha-input');
    let $captchaImage = $('#captcha-image');
    if (flag) {
        $captchaImage.click();
        $captchaInput.show();
        showCaptcha = true;
        return;
    }
    panelRequest.get('/api/captcha/flag', function (res) {
        showCaptcha = res.data.showCaptcha;
        if (showCaptcha) {
            $captchaInput.show();
            $captchaImage.click();
        } else {
            $captchaInput.hide();
        }
    })
}

$(document).ready(function () {
    localStorage.removeItem('lastLoginInfo');
    let $captchaImage = $('#captcha-image');

    $captchaImage.click(function () {
        $(this).attr('src', BASE_API_PATH + '/api/captcha?t=' + new Date().getTime())
    })

    checkNeedCaptcha();
    $('#login').click(function () {
        let $user = $('#username').val();
        let $password = $('#password').val();
        let $captcha = $('#captcha').val();
        if (!$user || !$password) return;
        if (showCaptcha && !$captcha) return;
        panelUtils.showLoading('登录中...')
        panelRequest.post('/api/auth', {
            username: $user,
            password: $password,
            captcha: $captcha,
        }, function (res) {
            let data = res.data;
            if (res.code === 1) {
                if (data.lastLoginInfo) {
                    localStorage.setItem('lastLoginInfo', JSON.stringify(data.lastLoginInfo))
                }
                if (data.newPwd) {
                    panelUtils.showWarning('温馨提示', `系统检测到您的密码为初始密码，已修改为随机密码：${data.newPwd}，请重新登录`, '复制新密码并重新登录').then((isConfirm) => {
                        if (isConfirm.value) {
                            copyToClip(data.newPwd);
                        }
                    });
                } else {
                    window.location.href = BASE_API_PATH + data['redirect'];
                }
            }
        }, (res) => {
            checkNeedCaptcha(res.data.showCaptcha);
        });
        return false;
    });
})
