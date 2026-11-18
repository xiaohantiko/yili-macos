const { readFileSync } = require('node:fs');
const path = require('node:path');

const endpoint = 'https://api.openai.com/v1/responses';
const stems = '甲乙丙丁戊己庚辛壬癸';
const branches = '子丑寅卯辰巳午未申酉戌亥';
const elements = '木火土金水';
const resultFields = ['overview', 'reasoning', 'guidance', 'limits'];
const contextFields = [
    'date', 'timeZone', 'solarTerm', 'pillars', 'dayMaster', 'fiveElements',
    'dailyPillar', 'trigram', 'direction', 'basis',
];

class GPTError extends Error {
    constructor(message) {
        super(message);
        this.name = 'GPTError';
    }
}

function invalidContext() {
    throw new GPTError('排盘资料不完整，请刷新页面后重试。');
}

function text(value, limit) {
    if (typeof value !== 'string' || value.length > limit || !value.trim()
        || /[\u0000-\u0008\u000b\u000c\u000e-\u001f]/.test(value)) invalidContext();
    return value.trim();
}

function isPillar(value) {
    if (typeof value !== 'string' || value.length !== 2) return false;
    const stem = stems.indexOf(value[0]);
    const branch = branches.indexOf(value[1]);
    return stem >= 0 && branch >= 0 && stem % 2 === branch % 2;
}

function validateContext(value) {
    if (!value || typeof value !== 'object' || Array.isArray(value)
        || Object.keys(value).length !== contextFields.length
        || contextFields.some((key) => !Object.hasOwn(value, key))) invalidContext();
    const date = text(value.date, 10);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) invalidContext();
    const instant = new Date(`${date}T00:00:00Z`);
    if (!Number.isFinite(instant.getTime()) || instant.toISOString().slice(0, 10) !== date
        || instant.getUTCFullYear() < 1901 || instant.getUTCFullYear() > 2099) invalidContext();
    const timeZone = text(value.timeZone, 100);
    try { new Intl.DateTimeFormat('en', { timeZone }); } catch { invalidContext(); }
    const solarTerm = text(value.solarTerm, 10);
    if (!['小寒', '大寒', '立春', '雨水', '惊蛰', '春分', '清明', '谷雨', '立夏', '小满',
        '芒种', '夏至', '小暑', '大暑', '立秋', '处暑', '白露', '秋分', '寒露', '霜降',
        '立冬', '小雪', '大雪', '冬至', '未知'].includes(solarTerm)) invalidContext();
    if (!Array.isArray(value.pillars) || value.pillars.length !== 4
        || !value.pillars.every(isPillar) || !isPillar(value.dailyPillar)) invalidContext();
    const dayMaster = text(value.dayMaster, 2);
    const dayStem = value.pillars[2][0];
    if (dayMaster !== dayStem + '木木火火土土金金水水'[stems.indexOf(dayStem)]) invalidContext();
    if (!value.fiveElements || typeof value.fiveElements !== 'object'
        || Object.keys(value.fiveElements).length !== 5) invalidContext();
    const fiveElements = {};
    for (const element of elements) {
        const percent = value.fiveElements[element];
        if (typeof percent !== 'number' || !Number.isFinite(percent) || percent < 0 || percent > 100) {
            invalidContext();
        }
        fiveElements[element] = percent;
    }
    const total = Object.values(fiveElements).reduce((sum, percent) => sum + percent, 0);
    if (Math.abs(total - 100) > 2.5) invalidContext();
    const trigram = text(value.trigram, 1);
    if (!'乾坤震巽坎离艮兑'.includes(trigram)) invalidContext();
    const direction = text(value.direction, 2);
    if (!['正北', '东北', '正东', '东南', '正南', '西南', '正西', '西北'].includes(direction)) invalidContext();
    return {
        date, timeZone, solarTerm, pillars: [...value.pillars], dayMaster, fiveElements,
        dailyPillar: value.dailyPillar, trigram, direction, basis: text(value.basis, 1500),
    };
}

function validateKey(value) {
    const key = typeof value === 'string' ? value.trim() : '';
    if (!/^sk-[A-Za-z0-9_-]{12,500}$/.test(key)) {
        throw new GPTError('请填写有效的 OpenAI API Key。');
    }
    return key;
}

function validateRequestId(value) {
    if (!Number.isSafeInteger(value) || value < 1) invalidContext();
}

async function readResponse(response) {
    const reader = response.body?.getReader();
    if (!reader) throw new GPTError('GPT 返回了空内容，请重试。');
    const chunks = [];
    let length = 0;
    try {
        while (true) {
            const { value, done } = await reader.read();
            if (done) break;
            length += value.byteLength;
            if (length > 200_000) throw new GPTError('GPT 返回的内容过长，请重试。');
            chunks.push(value);
        }
    } finally {
        await reader.cancel().catch(() => {});
    }
    return JSON.parse(Buffer.concat(chunks).toString('utf8'));
}

function parseReading(response, key) {
    if (response.status !== 'completed' || !Array.isArray(response.output)) {
        throw new GPTError('GPT 解读尚未完整生成，请重试。');
    }
    const messages = response.output.filter((item) => item.type === 'message');
    if (!messages.length || messages.some((item) => item.status !== 'completed' || item.role !== 'assistant'
        || !Array.isArray(item.content) || item.content.some((part) => part.type !== 'output_text'))) {
        throw new GPTError('GPT 未能生成本次解读，请重试。');
    }
    const content = messages.flatMap((item) => item.content.map((part) => part.text)).join('');
    const reading = JSON.parse(content);
    if (!reading || typeof reading !== 'object' || Object.keys(reading).length !== resultFields.length
        || resultFields.some((field) => typeof reading[field] !== 'string' || !reading[field].trim()
            || reading[field].length > 4000 || reading[field].includes(key))) {
        throw new GPTError('GPT 返回的解读格式有误，请重试。');
    }
    return Object.fromEntries(resultFields.map((field) => [field, reading[field].trim()]));
}

function createGPTClient({ fetchImpl = fetch, initialKey = process.env.OPENAI_API_KEY, timeoutMs = 45_000 } = {}) {
    const contract = JSON.parse(readFileSync(path.join(__dirname, 'core', 'fortune-contract.json'), 'utf8'));
    let key = '';
    if (initialKey) {
        try { key = validateKey(initialKey); } catch { /* Invalid environment keys can be replaced in settings. */ }
    }
    let active;

    const cancel = (requestId) => {
        if (active && (requestId === undefined || requestId === active.requestId)) active.controller.abort();
    };
    const status = () => ({ hasKey: Boolean(key), model: contract.model });

    return {
        status,
        setKey(value) {
            const next = validateKey(value);
            cancel();
            key = next;
            return status();
        },
        clearKey() {
            cancel();
            key = '';
            return status();
        },
        cancel,
        async generate(request) {
            validateRequestId(request?.requestId);
            const context = validateContext(request.context);
            if (!key) throw new GPTError('请先填写 OpenAI API Key。');
            cancel();
            const currentKey = key;
            const operation = { requestId: request.requestId, controller: new AbortController(), timedOut: false };
            active = operation;
            const timer = setTimeout(() => {
                operation.timedOut = true;
                operation.controller.abort();
            }, timeoutMs);
            try {
                const response = await fetchImpl(endpoint, {
                    method: 'POST',
                    redirect: 'error',
                    headers: { Authorization: `Bearer ${currentKey}`, 'Content-Type': 'application/json' },
                    signal: operation.controller.signal,
                    body: JSON.stringify({
                        model: contract.model,
                        instructions: contract.instructions,
                        input: JSON.stringify(context),
                        text: { format: contract.format },
                        store: false,
                        max_output_tokens: contract.max_output_tokens,
                        reasoning: { effort: 'low' },
                    }),
                });
                if (!response.ok) {
                    await response.body?.cancel().catch(() => {});
                    if (response.status === 401 || response.status === 403) {
                        throw new GPTError('API Key 无效或没有模型权限，请检查后重试。');
                    }
                    if (response.status === 429) throw new GPTError('请求额度不足或过于频繁，请检查 API 账户后重试。');
                    throw new GPTError('OpenAI 服务暂时不可用，请稍后重试。');
                }
                const result = parseReading(await readResponse(response), currentKey);
                if (operation.controller.signal.aborted) throw new GPTError('本次解读已取消。');
                return { requestId: request.requestId, result };
            } catch (error) {
                if (operation.controller.signal.aborted) {
                    throw new GPTError(operation.timedOut ? 'GPT 响应超时，请重试。' : '本次解读已取消。');
                }
                if (error instanceof GPTError) throw error;
                throw new GPTError('GPT 连接或返回格式异常，请检查网络后重试。');
            } finally {
                clearTimeout(timer);
                if (active === operation) active = undefined;
            }
        },
    };
}

async function smokeTransport(_endpoint, { headers, signal }) {
    await new Promise((resolve, reject) => {
        const cancel = () => { clearTimeout(timer); reject(new Error('Aborted')); };
        const timer = setTimeout(() => { signal.removeEventListener('abort', cancel); resolve(); }, 200);
        signal.addEventListener('abort', cancel, { once: true });
        if (signal.aborted) cancel();
    });
    if (headers.Authorization.includes('failure')) return new Response(null, { status: 401 });
    return Response.json({
        status: 'completed',
        output: [{ type: 'message', role: 'assistant', status: 'completed', content: [{
            type: 'output_text',
            text: JSON.stringify({
                overview: '今日适合把一件重要的事稳步推进。',
                reasoning: '结合日主、五行分布与流日关系，先观察自己的节奏。',
                guidance: '明确当天的优先项，交流时留出回应的空间。',
                limits: '传统文化解读供日常参考。',
            }),
        }] }],
    });
}

module.exports = { createGPTClient, GPTError, validateContext, validateRequestId, smokeTransport };
