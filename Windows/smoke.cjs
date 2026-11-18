module.exports = async function smokeTest(contents, home) {
    const run = async (test) => {
        const error = await contents.executeJavaScript(`(async () => {
            try { await (${test.toString()})(); return null; }
            catch (error) { return error.stack; }
        })()`);
        if (error) throw new Error(error);
    };
    await run(async () => {
        const check = (condition, message) => { if (!condition) throw new Error(message); };
        const get = selector => document.querySelector(selector);
        const waitFor = async predicate => {
            const deadline = Date.now() + 5000;
            while (!predicate()) {
                if (Date.now() > deadline) throw new Error('GPT UI state timed out.');
                await new Promise(resolve => setTimeout(resolve, 10));
            }
        };
        const saveKey = async key => {
            get('#gpt-open-settings').click();
            get('#gpt-key').value = key;
            get('#gpt-save-key').click();
            await waitFor(() => !get('#gpt-settings').open);
        };

        await waitFor(() => get('#gpt-key-state').textContent.includes('请先设置'));
        check(get('#gpt-generate').disabled, 'GPT generation accepted a missing key.');
        check(get('#gpt-context').textContent.includes('本命四柱'), 'GPT facts preview is missing.');
        get('#gpt-open-settings').click();
        check(get('#gpt-key').type === 'password', 'API key is not masked.');
        get('#gpt-save-key').click();
        check(!get('#gpt-key-error').hidden, 'An empty API key was accepted.');
        get('#gpt-close-settings').click();
        await saveKey('sk-smoke-yili-offline-1234567890');
        check(get('#gpt-key').value === '', 'API key was left in the input.');

        get('#gpt-generate').click();
        check(get('#gpt-panel').getAttribute('aria-busy') === 'true', 'GPT loading was not shown.');
        await waitFor(() => !get('#gpt-result').hidden);
        check(get('#gpt-result').children.length === 4, 'GPT response sections are incomplete.');
        check(get('#gpt-result').textContent.includes('推演依据'), 'GPT response lost its grounds.');
        check(!JSON.stringify(localStorage).includes('sk-smoke'), 'API key was persisted to local storage.');

        get('#next-day').click();
        check(get('#gpt-result').hidden, 'Date change retained stale GPT content.');
        get('#gpt-generate').click();
        get('#next-day').click();
        await new Promise(resolve => setTimeout(resolve, 350));
        check(get('#gpt-result').hidden && !get('#gpt-generate').disabled, 'Cancelled date request replaced the current state.');
        get('#gpt-generate').click();
        get('#gpt-cancel').click();
        await new Promise(resolve => setTimeout(resolve, 350));
        check(get('#gpt-result').hidden && get('#gpt-status').textContent.includes('取消'), 'Explicit cancellation failed.');

        await saveKey('sk-smoke-failure-1234567890');
        get('#gpt-generate').click();
        await waitFor(() => get('#gpt-status').classList.contains('error'));
        check(get('#gpt-result').hidden && !get('#gpt-generate').disabled, 'GPT failure could not be retried.');
        await saveKey('sk-smoke-yili-offline-1234567890');
        get('#gpt-generate').click();
        await waitFor(() => !get('#gpt-result').hidden);
        get('#today').click();
    });
    await run(async () => {
        const check = (condition, message) => { if (!condition) throw new Error(message); };
        const get = (selector) => document.querySelector(selector);
        check(get('#page-title').textContent === '今日运势', 'Daily page did not open.');
        get('#next-day').click();
        check(get('#page-title').textContent === '每日运势', 'Date did not advance.');
        get('#today').click();
        get('#gpt-generate').click();
        get('#profile-button').click();
        check(get('#birth-dialog').open, 'Birth editor did not open.');
        get('#save-birth').click();
        check(get('#birth-error').textContent.includes('日期'), 'Empty date was accepted.');
        for (const [name, value] of Object.entries({ year: '2024', month: '02', day: '04', hour: '16', minute: '28' })) {
            get(`[name="${name}"]`).value = value;
        }
        get('#zone-search').value = '香港';
        get('#zone-search').dispatchEvent(new Event('input'));
        get('[data-zone="Asia/Hong_Kong"]').click();
        get('#save-birth').click();
        check(get('#page-title').textContent === '生辰命盘', get('#birth-error').textContent || 'Natal page did not open.');
        check(get('#pillars [aria-label="甲辰"]') && get('#pillars [aria-label="丙寅"]'), 'Unexpected pillars.');
        check(get('#element-legend').children.length === 5, 'Five elements did not render.');
        await new Promise(resolve => setTimeout(resolve, 350));
        check(get('#gpt-result').hidden, 'Profile change retained stale GPT content.');
    });
    await contents.loadURL(home);
    await run(() => {
        const get = (selector) => document.querySelector(selector);
        get('#profile-button').click();
        if (get('[name="year"]').value !== '2024' || !get('#zone-search').value.includes('香港')) {
            throw new Error('Birth profile did not persist.');
        }
        get('#clear-birth').click();
        get('[data-page="methods"]').click();
        if (get('#page-title').textContent !== '排盘说明') throw new Error('Methods page did not open.');
    });
    await contents.loadURL(home);
    await run(async () => {
        if (document.querySelector('#profile-title').textContent !== '体验命盘') {
            throw new Error('Sample profile was not restored.');
        }
        const get = selector => document.querySelector(selector);
        const deadline = Date.now() + 5000;
        while (get('#gpt-generate').disabled) {
            if (Date.now() > deadline) throw new Error('Session API key did not survive renderer reload.');
            await new Promise(resolve => setTimeout(resolve, 10));
        }
        get('#gpt-generate').click();
        get('#gpt-open-settings').click();
        if (get('#gpt-key').value !== '') throw new Error('Session API key was exposed in the form.');
        get('#gpt-clear-key').click();
        while (get('#gpt-settings').open) {
            if (Date.now() > deadline) throw new Error('API key was not cleared.');
            await new Promise(resolve => setTimeout(resolve, 10));
        }
        await new Promise(resolve => setTimeout(resolve, 350));
        if (!get('#gpt-generate').disabled || !get('#gpt-result').hidden) {
            throw new Error('Clearing the API key retained an active or stale GPT reading.');
        }
    });
};
