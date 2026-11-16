module.exports = async function smokeTest(contents, home) {
    const run = async (test) => {
        const error = await contents.executeJavaScript(`(() => {
            try { (${test.toString()})(); return null; }
            catch (error) { return error.stack; }
        })()`);
        if (error) throw new Error(error);
    };
    await run(() => {
        const check = (condition, message) => { if (!condition) throw new Error(message); };
        const get = (selector) => document.querySelector(selector);
        check(get('#page-title').textContent === '今日运势', 'Daily page did not open.');
        get('#next-day').click();
        check(get('#page-title').textContent === '每日运势', 'Date did not advance.');
        get('#today').click();
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
    await run(() => {
        if (document.querySelector('#profile-title').textContent !== '体验命盘') {
            throw new Error('Sample profile was not restored.');
        }
    });
};
