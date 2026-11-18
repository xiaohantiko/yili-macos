import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { setImmediate } from 'node:timers/promises';
import vm from 'node:vm';
import test from 'node:test';
import { createGPTClient, GPTError, validateContext, smokeTransport } from '../openai.cjs';

const key = 'sk-offline-test-1234567890';
const context = {
    date: '2026-11-18', timeZone: 'Asia/Shanghai', solarTerm: '立冬',
    pillars: ['庚午', '辛巳', '壬午', '乙巳'], dayMaster: '壬水',
    fiveElements: { 木: 12.5, 火: 35, 土: 15, 金: 25, 水: 12.5 },
    dailyPillar: '丙申', trigram: '乾', direction: '西北', basis: '本命日主壬水，流日丙申。',
};
const reading = { overview: '整体', reasoning: '依据', guidance: '建议', limits: '边界' };
const complete = (result = reading) => ({
    status: 'completed', output: [
        { type: 'reasoning', summary: [] },
        { type: 'message', status: 'completed', role: 'assistant', content: [
            { type: 'output_text', text: JSON.stringify(result) },
        ] },
    ],
});
const request = (requestId = 1) => ({ requestId, context });

test('GPT sends only the bounded local context to the official Responses endpoint', async () => {
    let outgoing;
    const client = createGPTClient({ initialKey: key, fetchImpl: async (url, options) => {
        outgoing = { url, ...options, body: JSON.parse(options.body) };
        return Response.json(complete());
    } });
    assert.deepEqual(await client.generate(request()), { requestId: 1, result: reading });
    const contract = JSON.parse(await readFile(new URL('../core/fortune-contract.json', import.meta.url), 'utf8'));
    assert.equal(outgoing.url, 'https://api.openai.com/v1/responses');
    assert.equal(outgoing.method, 'POST');
    assert.equal(outgoing.redirect, 'error');
    assert.equal(outgoing.headers.Authorization, `Bearer ${key}`);
    assert.deepEqual(outgoing.body, {
        model: contract.model, instructions: contract.instructions, input: JSON.stringify(context),
        text: { format: contract.format }, store: false, max_output_tokens: contract.max_output_tokens,
        reasoning: { effort: 'low' },
    });
    assert.equal(outgoing.body.input.includes(key), false);
    assert.deepEqual(client.status(), { hasKey: true, model: contract.model });
});

test('keys remain session-only and explicit clear suppresses the environment fallback', async () => {
    const client = createGPTClient({ initialKey: key, fetchImpl: () => { throw Error('Unexpected network call'); } });
    assert.equal(client.status().hasKey, true);
    assert.equal(client.clearKey().hasKey, false);
    await assert.rejects(client.generate(request()), /请先填写/);
    assert.throws(() => client.setKey('bad key\r\nAuthorization: injected'), /有效/);
    assert.throws(() => client.setKey(`sk-${'a'.repeat(501)}`), /有效/);
    const status = client.setKey(` ${key} `);
    assert.equal(status.hasKey, true);
    assert.equal(JSON.stringify(status).includes(key), false);
});

test('invalid dates, time zones, pillars, percentages and extra data are rejected before fetch', async () => {
    const client = createGPTClient({ initialKey: key, fetchImpl: () => { throw Error('Unexpected network call'); } });
    for (const changes of [
        { date: '2026-02-30' }, { date: '2100-01-01' }, { timeZone: 'Not/A_Zone' },
        { solarTerm: '伪造节气' }, { pillars: ['甲丑', ...context.pillars.slice(1)] },
        { dayMaster: '甲木' }, { dailyPillar: '甲丑' }, { trigram: '坎水' },
        { fiveElements: { 木: 0, 火: 0, 土: 0, 金: 0, 水: 0 } },
        { fiveElements: { 木: NaN, 火: 35, 土: 15, 金: 25, 水: 12.5 } },
        { basis: 'a'.repeat(1501) }, { direction: '任意位置' }, { apiKey: key },
    ]) {
        await assert.rejects(client.generate({ requestId: 1, context: { ...context, ...changes } }), GPTError);
    }
    await assert.rejects(client.generate({ requestId: 0, context }), GPTError);
    await assert.rejects(client.generate({ requestId: '1', context }), GPTError);
    assert.deepEqual(validateContext(context), context);
});

test('API status and network failures never expose response bodies or credentials', async () => {
    for (const status of [401, 403, 429, 500]) {
        const client = createGPTClient({ initialKey: key, fetchImpl: async () => new Response(key, { status }) });
        await assert.rejects(client.generate(request()), (error) => error instanceof GPTError && !error.message.includes(key));
    }
    const client = createGPTClient({ initialKey: key, fetchImpl: async () => { throw Error(`Private network error ${key}`); } });
    await assert.rejects(client.generate(request()), (error) => error instanceof GPTError && !error.message.includes(key));
});

test('incomplete, refused, malformed or oversized model output cannot become a reading', async () => {
    const message = complete().output[1];
    for (const payload of [
        { ...complete(), status: 'incomplete' },
        { status: 'completed', output: [{ ...message, status: 'in_progress' }] },
        { status: 'completed', output: [{ ...message, content: [{ type: 'refusal', refusal: 'refused' }] }] },
        complete({ ...reading, limits: '' }), complete({ ...reading, overview: key }),
        complete({ ...reading, guidance: 'a'.repeat(4001) }), complete({ ...reading, extra: true }),
        null,
    ]) {
        const client = createGPTClient({ initialKey: key, fetchImpl: async () => Response.json(payload) });
        await assert.rejects(client.generate(request()), GPTError);
    }
    const oversized = createGPTClient({ initialKey: key, fetchImpl: async () => new Response('a'.repeat(200_001)) });
    await assert.rejects(oversized.generate(request()), /过长/);
});

test('cancel, replacement and key clearing abort pending work without returning stale data', async () => {
    const client = createGPTClient({ initialKey: key, fetchImpl: smokeTransport });
    const canceled = client.generate(request(1));
    const canceledCheck = assert.rejects(canceled, /取消/);
    client.cancel(1);
    await canceledCheck;

    const replaced = client.generate(request(2));
    const replacedCheck = assert.rejects(replaced, /取消/);
    const latest = client.generate(request(3));
    await replacedCheck;
    assert.equal((await latest).requestId, 3);

    const cleared = client.generate(request(4));
    const clearedCheck = assert.rejects(cleared, /取消/);
    client.clearKey();
    await clearedCheck;
    assert.equal(client.status().hasKey, false);
});

test('timeout aborts the transport and presents a retryable message', async () => {
    const client = createGPTClient({ initialKey: key, fetchImpl: smokeTransport, timeoutMs: 5 });
    await assert.rejects(client.generate(request()), /超时/);
});

test('privileged IPC accepts only the app window and its trusted top-level page', async () => {
    const handlers = new Map();
    let keyUpdates = 0;
    const contents = {
        mainFrame: { url: 'yili://almanac/index.html' },
        on() {}, setWindowOpenHandler() {},
    };
    const electron = {
        app: {
            setName() {}, setAppUserModelId() {}, enableSandbox() {}, on() {},
            requestSingleInstanceLock: () => true, whenReady: () => Promise.resolve(),
        },
        BrowserWindow: class {
            webContents = contents;
            on() {}
            once() {}
            async loadURL() {}
        },
        ipcMain: { handle: (channel, callback) => handlers.set(channel, callback) },
        protocol: { registerSchemesAsPrivileged() {}, handle() {} },
        session: { defaultSession: { setPermissionRequestHandler() {}, setPermissionCheckHandler() {} } },
        Menu: { buildFromTemplate: () => [], setApplicationMenu() {} },
    };
    const main = await readFile(new URL('../main.cjs', import.meta.url), 'utf8');
    const require = createRequire(import.meta.url);
    vm.runInNewContext(main, {
        __dirname: new URL('..', import.meta.url).pathname,
        process: { argv: [] },
        require: (name) => {
            if (name === 'electron') return electron;
            if (name === './openai.cjs') return {
                GPTError, createGPTClient: () => ({
                    status: () => ({ hasKey: false, model: 'test' }),
                    setKey: () => { keyUpdates += 1; return { hasKey: true, model: 'test' }; },
                }),
            };
            return require(name);
        },
    });
    await setImmediate();
    const trusted = { sender: contents, senderFrame: contents.mainFrame };
    assert.equal((await handlers.get('gpt:status')(trusted)).ok, true);
    for (const event of [
        { sender: contents, senderFrame: { url: contents.mainFrame.url } },
        { sender: { mainFrame: contents.mainFrame }, senderFrame: contents.mainFrame },
        { sender: contents, senderFrame: null },
    ]) {
        assert.equal((await handlers.get('gpt:set-key')(event, key)).ok, false);
    }
    contents.mainFrame.url = 'https://example.com/';
    assert.equal((await handlers.get('gpt:set-key')(trusted, key)).ok, false);
    assert.equal(keyUpdates, 0);
    contents.mainFrame.url = 'yili://almanac/index.html';
    assert.equal((await handlers.get('gpt:set-key')(trusted, key)).ok, true);
    assert.equal(keyUpdates, 1);
});
