import assert from 'node:assert/strict';
import test from 'node:test';
import { chartFor } from '../core/bazi.mjs';
import { buildGPTContext } from '../renderer/gpt-context.mjs';

const birth = { year: 2000, month: 1, day: 7, hour: 12, minute: 0, timeZoneID: 'Asia/Shanghai' };
const chart = chartFor(birth);

test('GPT context contains canonical derived facts and rounded percentages', () => {
    const context = buildGPTContext({
        chart,
        date: new Date('2000-01-07T04:00:00Z'),
        timeZone: 'Asia/Shanghai',
        solarTerm: '小寒',
    });

    assert.deepEqual(Object.keys(context), [
        'date', 'timeZone', 'solarTerm', 'pillars', 'dayMaster', 'fiveElements',
        'dailyPillar', 'trigram', 'direction', 'basis',
    ]);
    assert.equal(context.date, '2000-01-07');
    assert.deepEqual(context.pillars, ['己卯', '丁丑', '甲子', '庚午']);
    assert.equal(context.dayMaster, '甲木');
    assert.deepEqual(context.fiveElements, { 木: 25, 火: 21.25, 土: 23.75, 金: 13.75, 水: 16.25 });
    assert.equal(context.dailyPillar, '甲子');
    assert.equal(context.trigram, '坎');
    assert.equal(context.direction, '正北');
    assert.match(context.basis, /流日天干甲木与本命日主甲木同属一行/);
});

test('GPT date and daily pillar follow the selected day zone without copying raw birth fields', () => {
    const instant = new Date('2026-11-18T00:30:00Z');
    const shanghai = buildGPTContext({ chart, date: instant, timeZone: 'Asia/Shanghai', solarTerm: '立冬' });
    const losAngeles = buildGPTContext({ chart, date: instant, timeZone: 'America/Los_Angeles' });

    assert.equal(shanghai.date, '2026-11-18');
    assert.equal(losAngeles.date, '2026-11-17');
    assert.notEqual(shanghai.dailyPillar, losAngeles.dailyPillar);
    assert.equal(losAngeles.solarTerm, '未知');
    for (const key of Object.keys(birth)) assert.equal(Object.hasOwn(shanghai, key), false);
    assert.equal(Object.hasOwn(shanghai, 'birth'), false);
    assert.equal(Object.hasOwn(shanghai, 'apiKey'), false);
});
