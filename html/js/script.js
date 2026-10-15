/* ==========================================================================
   retro_phone UI
   Structure:
     state -> helpers -> screen router -> screens -> menu registry -> NUI messages
   Adding a feature = write a screen function + registerMenuItem (see bottom).
   Keypad navigation on list screens: 2 = up, 8 = down, 5 = select, * = back
   ========================================================================== */

const NUI = 'https://retro_phone/';

let interval = null;
let missing_call_number = 'no_misscall';
let own_number = '';
let dial_val = '';
let contacts = [];

/* ---------- helpers ---------- */

const post = (name, data, cb) =>
    $.post(NUI + name, JSON.stringify(data || {}), cb, cb ? 'json' : undefined);

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

const trunc = (s, n) => (String(s).length > n ? String(s).slice(0, n - 2) + '..' : String(s));

const fmtTime = (s) => `${Math.floor(s / 60)}:${String(Math.floor(s % 60)).padStart(2, '0')}`;

const nameFor = (number) => {
    const c = contacts.find((c) => String(c.phone_number) === String(number));
    return c ? c.name : String(number);
};

const loadContacts = (cb) =>
    post('GetContacts', {}, (d) => {
        contacts = Array.isArray(d) ? d : [];
        if (cb) cb();
    });

const flash = (msg) => {
    $('.flash').remove();
    $('.phone-green-screen').append(`<div class="flash">${esc(msg)}</div>`);
    setTimeout(() => $('.flash').remove(), 1500);
};

/* Typing in a text field: tell the game to stop receiving key presses */
let inputFocused = false;
const setInputFocus = (state) => {
    if (inputFocused !== state) {
        inputFocused = state;
        post('InputFocus', { state });
    }
};
$(document).on('focusin', 'input', () => setInputFocus(true));
$(document).on('focusout', 'input', () => setInputFocus(false));

/* ---------- screen router ---------- */

let currentRender = null;
let stack = [];
let handlers = {};
let current = '';
let list = { items: [], index: 0 };

/* Render a screen. keys = { left: [label, fn], mid: [label, fn], right: [label, fn] } */
function screen(name, body, keys = {}) {
    setInputFocus(false);
    current = name;
    handlers = {};

    let softkeys = '';
    for (const pos of ['left', 'mid', 'right']) {
        if (!keys[pos]) continue;
        handlers[pos] = keys[pos][1];
        softkeys += `<h3 class="softkey sk-${pos}" data-k="${pos}">${esc(keys[pos][0])}</h3>`;
    }
    $('.phone-green-screen').html(body + softkeys);
}

$(document).on('click', '.softkey', function () {
    const fn = handlers[$(this).attr('data-k')];
    if (fn) fn();
});

/* Navigation: open() pushes the current screen so back() can return to it */
function open(fn) {
    if (currentRender) stack.push(currentRender);
    currentRender = fn;
    fn();
}

function back() {
    const prev = stack.pop();
    if (prev) {
        currentRender = prev;
        prev();
    } else {
        reset(() => Home(false));
    }
}

function reset(fn) {
    stack = [];
    currentRender = fn;
    fn();
}

/* Scrollable list with a highlighted row. items = [{ label, fn }] */
function listScreen(items, keys) {
    list = { items, index: 0 };
    const rows = items
        .map((it, i) => `<div class="item${i === 0 ? ' selected' : ''}" data-i="${i}">${esc(it.label)}</div>`)
        .join('');
    screen('list', `<div class="list">${rows}</div>`, keys || {
        left: ['Select', activate],
        right: ['Back', back],
    });
}

function activate() {
    const it = list.items[list.index];
    if (it && it.fn) it.fn();
}

function moveSelection(delta) {
    const n = list.items.length;
    if (!n) return;
    keyBeep();
    list.index = (list.index + delta + n) % n;

    const rows = $('.list .item');
    rows.removeClass('selected');
    const el = rows.eq(list.index).addClass('selected')[0];
    const box = $('.list')[0];
    if (el && box) {
        if (el.offsetTop < box.scrollTop) box.scrollTop = el.offsetTop;
        else if (el.offsetTop + el.offsetHeight > box.scrollTop + box.clientHeight)
            box.scrollTop = el.offsetTop + el.offsetHeight - box.clientHeight;
    }
}

$(document).on('click', '.list .item', function () {
    list.index = parseInt($(this).attr('data-i'), 10);
    activate();
});

/* ---------- ESC closes the phone (not while a call is ringing/active) ---------- */

const LOCKED_SCREENS = ['ringing', 'calling', 'incall'];

$(document).on('keydown', function (e) {
    if (!$('.phone-frame').is(':visible')) return;

    if (e.key === 'Escape' || e.keyCode === 27) {
        if (LOCKED_SCREENS.includes(current)) return;
        e.preventDefault();
        post('close');
        return;
    }

    // arrow keys / enter drive the list (not while typing in a field)
    if (current === 'list' && !$(e.target).is('input')) {
        if (e.key === 'ArrowUp') { e.preventDefault(); moveSelection(-1); }
        else if (e.key === 'ArrowDown') { e.preventDefault(); moveSelection(1); }
        else if (e.key === 'Enter') { e.preventDefault(); activate(); }
    }
});

/* mouse wheel moves the highlighted row (passive:false so we can cancel native scroll) */
document.addEventListener('wheel', function (e) {
    if (current !== 'list' || !$('.phone-frame').is(':visible')) return;
    e.preventDefault();
    moveSelection(e.deltaY > 0 ? 1 : -1);
}, { passive: false });

/* the page must never scroll sideways/up (drag-selecting or focus can do it) */
const lockScroll = () => {
    window.scrollTo(0, 0);
    document.documentElement.scrollLeft = 0;
    document.body.scrollLeft = 0;
    const box = $('.box')[0];
    if (box) { box.scrollLeft = 0; box.scrollTop = 0; }
};
window.addEventListener('scroll', lockScroll);
$(document).on('scroll', '.box', lockScroll);

/* ---------- keypad ---------- */

$(document).on('click', '.dial', function () {
    const key = String($(this).attr('data-num'));
    keyBeep();

    if (current === 'dial') {
        if (dial_val.length < 12) {
            dial_val += key;
            $('.dials-input').text(dial_val);
        }
    } else if (current === 'list') {
        if (key === '2') moveSelection(-1);
        else if (key === '8') moveSelection(1);
        else if (key === '5') activate();
        else if (key === '*') back();
    }
});

/* ---------- screens: home / dialer ---------- */

const Home = (missed = false) => {
    const text = missed
        ? `Missed call from ${trunc(nameFor(missing_call_number), 9)}`
        : 'No activity to display';

    screen('home',
        `<h3 class="line row"><span class="material-icons icon-sm">notifications</span>${esc(text)}</h3>`,
        {
            left: ['Call', () => open(Dials)],
            mid: ['Menu', () => open(Menu)],
            right: ['Close', () => post('close')],
        });
};

const Dials = () => {
    screen('dial', `<h3 class="line dials-input">${esc(dial_val)}</h3>`, {
        left: ['Call', callNow],
        mid: ['Back', back],
        right: ['Delete', () => {
            dial_val = dial_val.slice(0, -1);
            $('.dials-input').text(dial_val);
        }],
    });
};

const callNow = () => {
    if (!dial_val) return;
    post('CallPerson', { number: dial_val }, (d) => OnCallingAPerson(d.person));
};

const dialAndCall = (number) => {
    dial_val = String(number);
    callNow();
};

/* ---------- screens: call states ---------- */

const OnSomeoneCalling = (number) => {
    screen('ringing',
        `<h3 class="line">${esc(trunc(nameFor(number), 14))} Calling You...</h3>`,
        {
            left: ['Answer', () => post('AnswerCall')],
            right: ['Decline', () => post('DeclineCall')],
        });
};

const OnCallingAPerson = (person) => {
    $('.phone-frame').css('display', 'block');
    screen('calling',
        `<h3 class="line">You Calling ${esc(trunc(nameFor(person || ''), 14))}...</h3>`,
        { left: ['Cancel', () => post('CancelCall')] });
};

const InCall = () => {
    if (interval) clearInterval(interval);
    screen('incall',
        `<h3 class="line row"><span class="material-icons icon-sm">phone</span>In call <span id="time">0:00</span></h3>`,
        { left: ['Close Call', () => post('CloseCall')] });

    const start = Date.now();
    interval = setInterval(() => $('#time').text(fmtTime((Date.now() - start) / 1000)), 1000);
};

/* ---------- screens: menu ---------- */

const MENU_ITEMS = [
    { label: 'Contacts', run: () => open(Contacts) },
    { label: 'Call history', run: () => open(History) },
    { label: 'My number', run: () => open(MyNumber) },
    { label: 'Give my number', run: () => post('GivePhoneNumber') },
];

const registerMenuItem = (item) => MENU_ITEMS.push(item); // { label, run }

const Menu = () => listScreen(MENU_ITEMS.map((m) => ({ label: m.label, fn: m.run })));

const MyNumber = () => {
    screen('mynumber',
        `<h3 class="line">Your number</h3><h3 class="line">${esc(own_number)}</h3>`,
        { right: ['Back', back] });
};

/* ---------- screens: contacts ---------- */

const Contacts = () => {
    const items = [
        { label: '+ New contact', fn: () => open(() => AddContact()) },
        ...contacts.map((c) => ({
            label: c.name,
            fn: () => open(() => NumberScreen(c.phone_number)),
        })),
    ];
    listScreen(items);
};

/* Shows one number: Call, and Save/Delete depending on whether it is a contact */
const NumberScreen = (number) => {
    const c = contacts.find((c) => String(c.phone_number) === String(number));
    screen('number',
        `<h3 class="line">${esc(c ? c.name : 'Unknown')}</h3><h3 class="line">${esc(number)}</h3>`,
        {
            left: ['Call', () => dialAndCall(number)],
            mid: c
                ? ['Delete', () => deleteContact(c)]
                : ['Save', () => open(() => AddContact(number))],
            right: ['Back', back],
        });
};

const AddContact = (prefill = '') => {
    screen('add',
        `<input class="field" id="c-name" maxlength="14" placeholder="Name" autocomplete="off">
         <input class="field" id="c-number" maxlength="12" placeholder="Number" autocomplete="off" value="${esc(prefill)}">`,
        { left: ['Save', saveContact], right: ['Back', back] });
    $('#c-name').focus();
};

const saveContact = () => {
    const name = $('#c-name').val().trim();
    const number = $('#c-number').val().replace(/\D/g, '');
    if (!name || !number) return flash('Fill all fields');

    post('AddContact', { name, number }, (r) => {
        if (r && r.ok) {
            contacts = r.contacts;
            back();
        } else {
            flash((r && r.error) || 'Error');
        }
    });
};

const deleteContact = (c) => {
    post('DeleteContact', { id: c.id }, (r) => {
        if (r && r.ok) {
            contacts = r.contacts;
            back();
        }
    });
};

/* ---------- screens: call history ---------- */

const HISTORY_TAG = { outgoing: 'Out', incoming: 'In', missed: 'Miss' };

const History = () => {
    post('GetHistory', {}, (rows) => {
        if (currentRender !== History) return; // user already navigated away
        const items = (Array.isArray(rows) ? rows : []).map((r) => ({
            label: `${HISTORY_TAG[r.call_type] || '?'} ${trunc(nameFor(r.phone_number), 11)}`,
            fn: () => open(() => NumberScreen(r.phone_number)),
        }));
        listScreen(items.length ? items : [{ label: 'No calls yet', fn: () => { } }]);
    });
};

/* ---------- open / close ---------- */

const OpenPhone = (data) => {
    $('.phone-frame').show();
    loadContacts();

    if (data.type === 'NoNotificationToDisplay' || data.type === 'MissingCall') {
        SlideUpAnimation('.phone-frame', [{ y: 65 }, { y: 4 }]);
        if (dial_val) reset(Dials);
        else reset(() => Home(data.type === 'MissingCall'));
    } else if (data.type === 'OnSomeoneCalling') {
        SlideUpAnimation('.phone-frame', [{ y: 65 }, { y: 50 }]);
        reset(() => OnSomeoneCalling(data.number));
    } else if (data.type === 'InCall') {
        InCall();
    } else if (data.type === 'Dials') {
        reset(Dials);
    }
};

const ClosePhone = () => {
    dial_val = '';
    setInputFocus(false);

    if (interval) {
        clearInterval(interval);
        interval = null;
    }

    SlideUpAnimation('.phone-frame', [{ y: 65 }, { y: 120 }], function () {
        $('.phone-frame').hide();
        $('.phone-frame').css('transform', 'translateY(0)');
        reset(() => Home(false));
    });
};

function SlideUpAnimation(el, v, cb) {
    $(v[0]).animate(v[1], {
        duration: 500,
        step: function (val) {
            $(el).css('transform', `translateY(${val}%)`);
        },
        done: function () {
            if (cb) cb();
        },
    });
}

/* ---------- sounds (html/assets/sounds/<name>.ogg) ---------- */

const SOUNDS = ['call_receiver', 'call_transmitter', 'call_cant_reach', 'call_ended'];
const playing = new Set();
const reported = new Set();

/* --- generated tones (WebAudio): used for key beeps, and as a fallback when an .ogg is missing --- */
let audioCtx = null;
const tones = (seq, volume = 0.3) => {
    try {
        audioCtx = audioCtx || new (window.AudioContext || window.webkitAudioContext)();
        let t = audioCtx.currentTime;
        for (const [freq, ms] of seq) {
            if (freq > 0) {
                const osc = audioCtx.createOscillator();
                const gain = audioCtx.createGain();
                osc.type = 'square';
                osc.frequency.value = freq;
                gain.gain.value = volume * 0.25;
                osc.connect(gain).connect(audioCtx.destination);
                osc.start(t);
                osc.stop(t + ms / 1000);
            }
            t += ms / 1000;
        }
    } catch (e) { /* no audio available */ }
};

const FALLBACK = {
    call_transmitter: [[425, 900]],
    call_receiver: [[880, 150], [0, 80], [880, 150], [0, 80], [880, 150]],
    call_cant_reach: [[950, 200], [0, 100], [950, 200], [0, 100], [950, 200]],
    call_ended: [[480, 350]],
};

const KEY_SOUNDS = true;                         // beep on keypad / menu navigation
const keyBeep = () => { if (KEY_SOUNDS) tones([[1100, 40]], 0.25); };

const playSound = (name, volume) => {
    if (!SOUNDS.includes(name)) return;
    const vol = Math.min(1, Math.max(0, Number(volume) || 0.5));

    const fail = () => {
        tones(FALLBACK[name], vol);               // still make a sound
        if (!reported.has(name)) {                // tell the F8 console once
            reported.add(name);
            post('SoundError', { sound: name });
        }
    };

    const audio = new Audio(`assets/sounds/${name}.ogg`);
    audio.volume = vol;
    audio.onerror = fail;
    audio.onended = () => playing.delete(audio);
    playing.add(audio);
    audio.play().catch(fail);
};

const stopSounds = () => {
    playing.forEach((a) => { a.pause(); a.currentTime = 0; });
    playing.clear();
};

/* ---------- messages from Lua ---------- */

window.addEventListener('message', function (e) {
    const event = e.data;
    switch (event.action) {
        case 'ACTION_DISPLAY':
            if (event.value.show) {
                $('.phone-frame').css('display', 'block');
                OpenPhone({ type: event.value.type, number: event.value.number || '' });
            } else {
                ClosePhone();
            }
            break;
        case 'ACTION_SET_MISSINGCALL':
            if (event.value.misscall) missing_call_number = String(event.value.misscall);
            break;
        case 'ACTION_INCOMING_CALL':
            // phone is already open: switch straight to the ringing screen
            if ($('.phone-frame').is(':visible') && current !== 'incall') {
                reset(() => OnSomeoneCalling(event.value.number));
            }
            break;
        case 'ACTION_PLAY_SOUND':
            playSound(event.value.sound, event.value.volume);
            break;
        case 'ACTION_STOP_SOUNDS':
            stopSounds();
            break;
        case 'ACTION_SET_OWNNUMBER':
            own_number = String(event.value || '');
            break;
        case 'INSERT_DIAL_INFO':
            dial_val = String(event.value || '');
            break;
        default:
            break;
    }
});

/* ---------- extending the phone ----------
   Example of a future feature (notes app):

   const Notes = () => screen('notes', '<h3 class="line">Notes</h3>', { right: ['Back', back] });
   registerMenuItem({ label: 'Notes', run: () => open(Notes) });
   ---------------------------------------------------------------------- */
window.RetroPhone = { screen, listScreen, open, back, post, esc, registerMenuItem };
