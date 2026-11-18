import assert from 'node:assert/strict';
import test from 'node:test';
import { solarTermsAround } from '../core/bazi.mjs';

// Hong Kong Observatory Almanac 2024, major solar terms and February almanac.
// Published times are Hong Kong civil time, rounded to a minute.
// https://www.hko.gov.hk/tc/gts/astron2024/files/HKO_almanac_2024.pdf
test('shared solar-term table agrees with the HKO 2024 published minute for 13 reference times', () => {
    const samples = [
        ['大寒', '01-20T22:07'], ['立春', '02-04T16:27'], ['雨水', '02-19T12:13'],
        ['春分', '03-20T11:06'], ['谷雨', '04-19T22:00'], ['小满', '05-20T21:00'],
        ['夏至', '06-21T04:51'], ['大暑', '07-22T15:44'], ['处暑', '08-22T22:55'],
        ['秋分', '09-22T20:44'], ['霜降', '10-23T06:15'], ['小雪', '11-22T03:56'],
        ['冬至', '12-21T17:21'],
    ];
    for (const [term, localTime] of samples) {
        const published = Date.parse(`2024-${localTime}:00+08:00`);
        const lookup = new Date(published + 60_000);
        const actual = solarTermsAround(lookup, 'Asia/Hong_Kong').current;
        assert.equal(actual.term, term);
        assert.ok(Math.abs(actual.date.getTime() - published) <= 30_000, term);
    }
});
