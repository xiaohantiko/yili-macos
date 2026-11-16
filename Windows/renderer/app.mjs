import { chartFor, dayPillarFor, solarTermsAround } from './core/bazi.mjs';
import { dailyFor, natalFor, natalMethod, dailyMethod } from './core/interpretation.mjs';
import { drawBagua } from './bagua.mjs';

const sample = { year: 1990, month: 5, day: 17, hour: 10, minute: 30, timeZoneID: 'Asia/Shanghai' };
const storageKey = 'localBirthProfile.v1';
const commonZones = new Map([
    ['Asia/Shanghai', '中国大陆（上海）'], ['Asia/Hong_Kong', '中国香港'],
    ['Asia/Macau', '中国澳门'], ['Asia/Taipei', '中国台北'], ['Asia/Singapore', '新加坡'],
    ['Asia/Tokyo', '东京'], ['Asia/Seoul', '首尔'], ['Australia/Sydney', '悉尼'],
    ['Europe/London', '伦敦'], ['America/New_York', '纽约'], ['America/Los_Angeles', '洛杉矶'],
    ['UTC', '协调世界时（UTC）'],
]);
const elements = { 木: 'wood', 火: 'fire', 土: 'earth', 金: 'metal', 水: 'water' };
const pages = { daily: '今日运势', natal: '生辰命盘', methods: '排盘说明' };
const fields = ['year', 'month', 'day', 'hour', 'minute'];
const weekFormat = new Intl.DateTimeFormat('zh-CN', { weekday: 'long' });
const percentFormat = new Intl.NumberFormat('zh-CN', { style: 'percent', maximumFractionDigits: 2 });
const localZone = () => new Intl.DateTimeFormat().resolvedOptions().timeZone;
const zoneName = (id) => commonZones.get(id) ?? id.replaceAll('_', ' ');
const pad = (value) => String(value).padStart(2, '0');
const get = (id) => document.getElementById(id);
const write = (id, string) => { get(id).textContent = string; };
const show = (id, visible) => { get(id).hidden = !visible; };
const field = (name) => form.elements.namedItem(name);
const zoneSearch = get('zone-search');
const zoneOptions = get('zone-options');
const dialog = get('birth-dialog');
const form = get('birth-form');
const navigation = [...document.querySelectorAll('[data-page]')];

function node(tag, text = '', classes = '') {
    const element = document.createElement(tag);
    element.textContent = text;
    if (classes) element.className = classes;
    return element;
}

function initialProfile() {
    try {
        const data = localStorage.getItem(storageKey);
        if (data) {
            const birth = JSON.parse(data);
            return { birth, chart: chartFor(birth), isSample: false };
        }
    } catch {
        // An unreadable profile still leaves an editable example.
    }
    return { birth: sample, chart: chartFor(sample), isSample: true };
}

let profile = initialProfile();
let page = 'daily';
let previewDate = null;
let zoneID = localZone();
let selectedOption = -1;
let lastDailyState = '';

function stamp(birth) {
    return `${birth.year}.${pad(birth.month)}.${pad(birth.day)}  ·  ${pad(birth.hour)}:${pad(birth.minute)}`;
}

function civilKey(date) {
    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

function renderProfile() {
    write('profile-title', profile.isSample ? '体验命盘' : '我的出生资料');
    write('profile-stamp', stamp(profile.birth));
    get('edit-birth').textContent = profile.isSample ? '输入我的出生资料' : '编辑出生资料';
}

function renderDaily() {
    const now = new Date();
    const date = previewDate ?? now;
    const isToday = civilKey(date) === civilKey(now);
    if (isToday) previewDate = null;
    const timeZone = localZone();
    const term = solarTermsAround(isToday ? now : date, timeZone)?.current.term;
    const state = `${civilKey(date)}|${isToday}|${timeZone}|${term}`;
    if (lastDailyState === state) return;
    lastDailyState = state;

    const reading = dailyFor(profile.chart, dayPillarFor(date, timeZone));
    const { trigram } = reading;
    write('page-title', isToday ? '今日运势' : '每日运势');
    show('today', !isToday);
    get('today-date').dateTime = civilKey(date);
    write('today-date', civilKey(date).replaceAll('-', '.'));
    write('weekday', weekFormat.format(date));
    write('day-pillar', `${reading.pillar.text}日`);
    write('solar-term', term ?? '');
    show('solar-term', Boolean(term));
    write('daily-headline', reading.headline);
    write('daily-summary', reading.summary);
    write('trigram-prompt', trigram.prompt);
    write('trigram-label', `${trigram.name}卦 · ${trigram.image} · ${trigram.direction}`);
    write('basis', reading.basis);
    drawBagua(get('bagua'), trigram);
    get('favors').replaceChildren(...reading.favors.map((item) => node('li', item)));
    get('ease-back').replaceChildren(...reading.easeBack.map((item) => node('li', item)));
    get('daily-notes').replaceChildren(...reading.notes.map((note) => {
        const card = node('article', '', 'panel');
        card.append(node('h3', note.title), node('p', note.text));
        return card;
    }));
}

function renderNatal() {
    const reading = natalFor(profile.chart);
    write('natal-stamp', `${stamp(profile.birth)}  ·  ${zoneName(profile.birth.timeZoneID)}${profile.isSample ? '  ·  体验' : ''}`);
    const titles = ['年柱', '月柱', '日柱', '时柱'];
    get('pillars').replaceChildren(...profile.chart.pillars.map((pillar, index) => {
        const card = node('article', '', index === 2 ? 'panel pillar day' : 'panel pillar');
        const pair = node('div', '', 'pair');
        pair.setAttribute('aria-label', pillar.text);
        for (const [entry, label] of [[pillar.stem, '天干'], [pillar.branch, '地支']]) {
            const column = node('div');
            column.append(node('strong', entry.text, `symbol ${elements[entry.element]}`), node('small', `${label} · ${entry.element}`));
            pair.append(column);
        }
        const hidden = node('div', '', 'hidden-stems');
        hidden.append(node('span', '藏干'), ...pillar.branch.hiddenStems.map((stem) => node('span', stem.text, `symbol ${elements[stem.element]}`)));
        card.append(node('h2', titles[index]), pair, hidden);
        return card;
    }));

    const meter = node('canvas');
    meter.width = 1600;
    meter.height = 20;
    const ctx = meter.getContext('2d');
    const colors = getComputedStyle(document.documentElement);
    let offset = 0;
    for (const share of reading.elements) {
        const end = offset + share.fraction * meter.width;
        ctx.fillStyle = colors.getPropertyValue(`--${elements[share.element]}`);
        ctx.fillRect(Math.round(offset), 0, Math.round(end) - Math.round(offset), meter.height);
        offset = end;
    }
    get('element-meter').replaceChildren(meter);
    get('element-legend').replaceChildren(...reading.elements.map((share) => {
        const item = node('span', '', `legend-item ${elements[share.element]}`);
        item.append(node('span', share.element), node('span', percentFormat.format(share.fraction), 'percent'));
        return item;
    }));
    write('natal-headline', reading.headline);
    get('natal-headline').className = `symbol ${elements[reading.dayMaster.element]}`;
    write('natal-summary', reading.summary);
    get('observations').replaceChildren(...reading.observations.map((note) => {
        const row = node('p', '', 'observation');
        row.append(node('strong', note.title), node('span', note.text));
        return row;
    }));
}

function selectPage(target) {
    page = target;
    for (const button of navigation) {
        const active = button.dataset.page === page;
        if (active) button.setAttribute('aria-current', 'page');
        else button.removeAttribute('aria-current');
        show(`${button.dataset.page}-page`, active);
    }
    show('day-control', page === 'daily');
    show('edit-birth', page === 'natal' || (page === 'daily' && profile.isSample));
    write('page-title', pages[page]);
    get('content').scrollTop = 0;
    if (page === 'daily') {
        lastDailyState = '';
        renderDaily();
    } else if (page === 'natal') renderNatal();
}

function moveDay(offset) {
    const date = new Date(previewDate ?? Date.now());
    date.setHours(12, 0, 0, 0);
    date.setDate(date.getDate() + offset);
    previewDate = date;
    renderDaily();
}

function displayError(message = '') {
    write('birth-error', message);
    show('birth-error', Boolean(message));
}

function chooseZone(id) {
    zoneID = id;
    zoneSearch.value = zoneName(id);
    displayError();
    closeZones();
}

function openZones(query = '') {
    const ids = new Set([...commonZones.keys(), localZone(), ...Intl.supportedValuesOf('timeZone')]);
    const term = query.trim().toLowerCase();
    const matches = [...ids].filter((id) => id.toLowerCase().includes(term) || zoneName(id).toLowerCase().includes(term));
    const options = matches.map((id, index) => {
        const option = node('button', zoneName(id));
        option.append(node('small', id));
        option.id = `zone-option-${index}`;
        option.dataset.zone = id;
        option.type = 'button';
        option.tabIndex = -1;
        option.setAttribute('role', 'option');
        option.setAttribute('aria-selected', String(id === zoneID));
        option.addEventListener('mousedown', (event) => event.preventDefault());
        option.addEventListener('click', () => chooseZone(id));
        return option;
    });
    zoneOptions.replaceChildren(...(options.length ? options : [node('p', '没有匹配的时区')]));
    zoneOptions.hidden = false;
    zoneSearch.setAttribute('aria-expanded', 'true');
    zoneSearch.removeAttribute('aria-activedescendant');
    selectedOption = -1;
}

function closeZones() {
    zoneOptions.hidden = true;
    zoneSearch.setAttribute('aria-expanded', 'false');
    zoneSearch.removeAttribute('aria-activedescendant');
}

function openEditor() {
    for (const name of fields) field(name).value = profile.isSample ? '' : pad(profile.birth[name]);
    chooseZone(profile.isSample ? localZone() : profile.birth.timeZoneID);
    show('clear-birth', !profile.isSample);
    show('local-label', profile.isSample);
    dialog.showModal();
}

function saveProfile(event) {
    event.preventDefault();
    const birth = { timeZoneID: zoneID };
    for (const name of fields) {
        const value = field(name).value.normalize('NFKC').trim();
        birth[name] = /^\d+$/.test(value) ? Number(value) : Number.NaN;
    }
    let chart;
    try {
        if (!Number.isInteger(birth.year)) throw new Error('请填写有效的公历出生日期。');
        if (!birth.timeZoneID) throw new Error('请从列表中选择出生时区。');
        chart = chartFor(birth);
    } catch (error) {
        displayError(error.message);
        return;
    }
    try {
        localStorage.setItem(storageKey, JSON.stringify(birth));
    } catch {
        displayError('无法保存出生资料，请检查本机存储后重试。');
        return;
    }
    profile = { birth, chart, isSample: false };
    dialog.close();
    renderProfile();
    selectPage('natal');
}

for (const button of navigation) button.addEventListener('click', () => selectPage(button.dataset.page));
get('prev-day').addEventListener('click', () => moveDay(-1));
get('next-day').addEventListener('click', () => moveDay(1));
get('today').addEventListener('click', () => { previewDate = null; renderDaily(); });
get('profile-button').addEventListener('click', openEditor);
get('edit-birth').addEventListener('click', openEditor);
get('cancel-birth').addEventListener('click', () => dialog.close());
get('clear-birth').addEventListener('click', () => {
    try {
        localStorage.removeItem(storageKey);
    } catch {
        displayError('无法清除出生资料，请检查本机存储后重试。');
        return;
    }
    profile = initialProfile();
    dialog.close();
    renderProfile();
    selectPage(page);
});
form.addEventListener('submit', saveProfile);
form.addEventListener('input', () => displayError());
zoneSearch.addEventListener('focus', () => { zoneSearch.select(); openZones(); });
zoneSearch.addEventListener('click', () => { if (zoneOptions.hidden) openZones(); });
zoneSearch.addEventListener('blur', () => {
    closeZones();
    if (zoneID) zoneSearch.value = zoneName(zoneID);
});
zoneSearch.addEventListener('input', () => {
    zoneID = null;
    openZones(zoneSearch.value);
});
zoneSearch.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && !zoneOptions.hidden) {
        event.preventDefault();
        closeZones();
        return;
    }
    if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
        event.preventDefault();
        if (zoneOptions.hidden) openZones(zoneID ? '' : zoneSearch.value);
        const options = [...zoneOptions.querySelectorAll('button')];
        if (!options.length) return;
        const change = event.key === 'ArrowDown' ? 1 : -1;
        selectedOption = Math.max(0, Math.min(options.length - 1, selectedOption + change));
        options.forEach((option, index) => option.setAttribute('aria-selected', String(index === selectedOption)));
        const option = options[selectedOption];
        zoneSearch.setAttribute('aria-activedescendant', option.id);
        option.scrollIntoView({ block: 'nearest' });
    } else if (event.key === 'Enter' && !zoneOptions.hidden) {
        event.preventDefault();
        const option = zoneOptions.querySelectorAll('button')[Math.max(0, selectedOption)];
        if (option) chooseZone(option.dataset.zone);
    }
});
window.addEventListener('focus', () => { if (page === 'daily') renderDaily(); });
setInterval(() => { if (page === 'daily') renderDaily(); }, 15_000);
write('natal-method', natalMethod);
write('daily-method', dailyMethod);
renderProfile();
selectPage('daily');
