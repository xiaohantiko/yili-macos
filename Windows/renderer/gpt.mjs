const responseSections = [
    ['overview', '整体解读'],
    ['reasoning', '推演依据'],
    ['guidance', '今日建议'],
    ['limits', '解读边界'],
];

function element(tag, text = '', className = '') {
    const result = document.createElement(tag);
    result.textContent = text;
    if (className) result.className = className;
    return result;
}

export function createGPTPanel(bridge = window.yiliGPT) {
    const get = id => document.getElementById(id);
    const settings = get('gpt-settings');
    const form = get('gpt-settings-form');
    const keyInput = get('gpt-key');
    let context = null;
    let contextKey = '';
    let requestNumber = 0;
    let activeRequest = null;
    let keyOperation = 0;
    let configured = false;
    let settingsBusy = false;
    let available = Boolean(bridge);
    let model = 'gpt-5.4-mini';

    function updateControls() {
        get('gpt-generate').disabled = !available || !configured || !context || activeRequest !== null || settingsBusy;
        get('gpt-generate').textContent = activeRequest !== null ? '正在生成…' : '生成所选日期解读';
        get('gpt-cancel').hidden = activeRequest === null;
        get('gpt-key-state').textContent = !available ? '当前运行环境无法连接 GPT 服务' : configured ? '已设置本次运行的 API Key' : '请先设置 OpenAI API Key';
        get('gpt-model').textContent = model;
        get('gpt-key-status').textContent = configured ? '已设置密钥，可替换或清除。退出应用后自动清除。' : '密钥仅保存到本次应用退出。';
        get('gpt-save-key').textContent = configured ? '替换本次密钥' : '保存本次密钥';
        get('gpt-save-key').disabled = settingsBusy || !available;
        get('gpt-clear-key').disabled = settingsBusy || !configured;
        get('gpt-clear-key').hidden = !configured;
        get('gpt-close-settings').disabled = settingsBusy;
        keyInput.disabled = settingsBusy || !available;
    }

    function status(message = '', isError = false) {
        const output = get('gpt-status');
        output.textContent = message;
        output.classList.toggle('error', isError);
    }

    function clearResponse() {
        get('gpt-result').replaceChildren();
        get('gpt-result').hidden = true;
    }

    function invalidate() {
        requestNumber += 1;
        const pending = activeRequest;
        activeRequest = null;
        if (pending !== null) void bridge.cancel(pending).catch(() => {});
        clearResponse();
        status();
        get('gpt-panel').setAttribute('aria-busy', 'false');
        updateControls();
    }

    function setContext(next) {
        const fingerprint = JSON.stringify(next);
        if (contextKey === fingerprint) return;
        context = next;
        contextKey = fingerprint;
        invalidate();
        if (!context) {
            get('gpt-context').replaceChildren();
            return;
        }
        const facts = [
            ['所选日期', context.date],
            ['日运时区', context.timeZone],
            ['节气', context.solarTerm],
            ['本命四柱', context.pillars.join(' · ')],
            ['日主', context.dayMaster],
            ['五行分布', Object.entries(context.fiveElements).map(([name, value]) => `${name} ${Number(value.toFixed(2))}%`).join(' · ')],
            ['流日', context.dailyPillar],
            ['卦象与方位', `${context.trigram}卦 · ${context.direction}`],
            ['本地推演依据', context.basis],
        ];
        get('gpt-context').replaceChildren(...facts.flatMap(([label, value]) => [
            element('dt', label), element('dd', value),
        ]));
    }

    async function generate() {
        if (!available || !configured || !context || activeRequest !== null || settingsBusy) return;
        const requestId = ++requestNumber;
        activeRequest = requestId;
        const fingerprint = contextKey;
        clearResponse();
        status('正在根据本地排盘生成详细解读…');
        get('gpt-panel').setAttribute('aria-busy', 'true');
        updateControls();
        try {
            const response = await bridge.generate({ requestId, context });
            if (requestId !== requestNumber || activeRequest !== requestId || fingerprint !== contextKey) return;
            if (response.requestId !== requestId || !responseSections.every(([key]) => typeof response.result?.[key] === 'string' && response.result[key].trim())) {
                throw new Error('服务返回的解读格式不完整，请重试。');
            }
            const sections = responseSections.map(([key, title]) => {
                const section = element('section');
                section.append(element('h3', title), element('p', response.result[key]));
                return section;
            });
            get('gpt-result').replaceChildren(...sections);
            get('gpt-result').hidden = false;
            status(`${context.date} 的详细解读已生成。`);
        } catch (error) {
            if (requestId !== requestNumber || activeRequest !== requestId) return;
            status(error?.message || '生成失败，请检查网络和 API Key 后重试。', true);
        } finally {
            if (activeRequest === requestId) {
                activeRequest = null;
                get('gpt-panel').setAttribute('aria-busy', 'false');
                updateControls();
            }
        }
    }

    async function changeKey(clear = false) {
        if (!available || settingsBusy) return;
        const key = keyInput.value.trim();
        if (!clear && !key) {
            get('gpt-key-error').textContent = '请输入 OpenAI API Key。';
            get('gpt-key-error').hidden = false;
            keyInput.focus();
            return;
        }
        const operation = ++keyOperation;
        invalidate();
        settingsBusy = true;
        get('gpt-key-error').hidden = true;
        updateControls();
        try {
            const state = clear ? await bridge.clearKey() : await bridge.setKey(key);
            if (operation !== keyOperation) return;
            configured = state.hasKey;
            model = state.model;
            keyInput.value = '';
            settings.close();
            status(clear ? '已清除本次运行的 API Key。' : 'API Key 已保存到本次应用退出。');
        } catch (error) {
            if (operation !== keyOperation) return;
            get('gpt-key-error').textContent = error?.message || '无法更新 API Key，请重试。';
            get('gpt-key-error').hidden = false;
        } finally {
            if (operation === keyOperation) {
                keyInput.value = '';
                settingsBusy = false;
                updateControls();
            }
        }
    }

    get('gpt-open-settings').addEventListener('click', () => {
        keyInput.value = '';
        get('gpt-key-error').hidden = true;
        updateControls();
        settings.showModal();
    });
    get('gpt-close-settings').addEventListener('click', () => settings.close());
    settings.addEventListener('close', () => { keyInput.value = ''; });
    settings.addEventListener('cancel', event => {
        if (settingsBusy) event.preventDefault();
    });
    form.addEventListener('submit', event => {
        event.preventDefault();
        void changeKey();
    });
    keyInput.addEventListener('input', () => { get('gpt-key-error').hidden = true; });
    get('gpt-clear-key').addEventListener('click', () => { void changeKey(true); });
    get('gpt-generate').addEventListener('click', () => { void generate(); });
    get('gpt-cancel').addEventListener('click', () => {
        invalidate();
        status('已取消生成。');
    });
    updateControls();
    if (bridge) {
        const operation = keyOperation;
        void bridge.status().then(state => {
            if (operation !== keyOperation) return;
            configured = state.hasKey;
            model = state.model;
            updateControls();
        }).catch(() => {
            if (operation !== keyOperation) return;
            available = false;
            updateControls();
        });
    }

    return { setContext };
}
