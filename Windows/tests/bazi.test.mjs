import assert from 'node:assert/strict';
import test from 'node:test';
import { BaziError, chartFor, dayPillarFor, solarTermsAround } from '../core/bazi.mjs';

function birth(year, month, day, hour, minute, timeZoneID = 'Asia/Shanghai') {
  return { year, month, day, hour, minute, timeZoneID };
}

function fourPillars(input) {
  return chartFor(input).pillars.map(pillar => pillar.text);
}

function checkError(input, code) {
  assert.throws(() => chartFor(input), { name: BaziError.name, code });
}

test('立春 changes year and month at the same instant in different zones', () => {
  assert.deepEqual(fourPillars(birth(2024, 2, 4, 16, 27)), ['癸卯', '乙丑', '戊戌', '庚申']);
  assert.deepEqual(fourPillars(birth(2024, 2, 4, 16, 28)), ['甲辰', '丙寅', '戊戌', '庚申']);
  assert.deepEqual(fourPillars(birth(2024, 2, 4, 3, 28, 'America/New_York')).slice(0, 2), ['甲辰', '丙寅']);
});

test('the month changes at 节 and remains the same across 中气', () => {
  assert.equal(chartFor(birth(2024, 2, 19, 12, 12)).month.text, '丙寅');
  assert.equal(chartFor(birth(2024, 2, 19, 12, 14)).month.text, '丙寅');
  assert.equal(chartFor(birth(2024, 3, 5, 10, 22)).month.text, '丙寅');
  assert.equal(chartFor(birth(2024, 3, 5, 10, 24)).month.text, '丁卯');
});

test('the local date changes at midnight and 子 hour spans 23:00 through 00:59', () => {
  assert.deepEqual(fourPillars(birth(2000, 1, 7, 22, 59)).slice(2), ['甲子', '乙亥']);
  assert.deepEqual(fourPillars(birth(2000, 1, 7, 23, 0)).slice(2), ['甲子', '甲子']);
  assert.deepEqual(fourPillars(birth(2000, 1, 8, 0, 0)).slice(2), ['乙丑', '丙子']);
  assert.deepEqual(fourPillars(birth(2000, 1, 8, 1, 0)).slice(2), ['乙丑', '丁丑']);
  const instant = new Date('2024-02-04T16:30:00Z');
  assert.equal(dayPillarFor(instant, 'Asia/Shanghai').text, '己亥');
  assert.equal(dayPillarFor(instant, 'America/New_York').text, '戊戌');
});

test('birth dates are validated against the proleptic Gregorian calendar and range', () => {
  assert.deepEqual(fourPillars(birth(1901, 1, 1, 0, 0)).slice(0, 3), ['庚子', '戊子', '己卯']);
  assert.equal(chartFor(birth(2099, 12, 31, 23, 59, 'America/New_York')).day.text, '壬寅');
  assert.equal(chartFor(birth(2024, 2, 29, 12, 0)).day.text, '癸亥');
  checkError(birth(1900, 1, 1, 0, 0), 'unsupportedYear');
  checkError(birth(2100, 1, 1, 0, 0), 'unsupportedYear');
  checkError(birth(2023, 2, 29, 12, 0), 'invalidDate');
  checkError(birth(2024, 4, 31, 12, 0), 'invalidDate');
  checkError(birth(2024, 2, 29, 24, 0), 'invalidTime');
  checkError(birth(2024, 2, 29, 12, 60), 'invalidTime');
  checkError(birth(2024, 2, 29, 12, 0, 'Invalid/Zone'), 'invalidTimeZone');
});

test('skipped local times are rejected and clock overlaps use the earlier instant', () => {
  checkError(birth(2024, 3, 10, 2, 30, 'America/Los_Angeles'), 'unavailableCivilTime');
  checkError(birth(2011, 12, 30, 12, 0, 'Pacific/Apia'), 'unavailableCivilTime');
  checkError(birth(1986, 1, 1, 0, 5, 'Asia/Kathmandu'), 'unavailableCivilTime');
  // 立冬 occurred at 04:58:46 UTC, between the two 01:30s in Halifax that day.
  assert.equal(chartFor(birth(2021, 11, 7, 1, 30, 'America/Halifax')).month.text, '戊戌');
  assert.equal(chartFor(birth(2021, 11, 7, 5, 30, 'UTC')).month.text, '己亥');
});

test('historical time zone offsets preserve seconds at day and term boundaries', () => {
  // Kathmandu was UTC+05:41:16. 17:21 there was 11:39:44 UTC, 7 seconds before 立春.
  assert.equal(chartFor(birth(1901, 2, 4, 17, 21, 'Asia/Kathmandu')).year.text, '庚子');
  assert.equal(chartFor(birth(1901, 2, 4, 17, 22, 'Asia/Kathmandu')).year.text, '辛丑');
  assert.equal(dayPillarFor(new Date('1901-01-01T00:43:07Z'), 'Africa/Monrovia').text, '戊寅');
  assert.equal(dayPillarFor(new Date('1901-01-01T00:43:08Z'), 'Africa/Monrovia').text, '己卯');
});

test('solar terms change at the table instant and continue across UTC years', () => {
  const beforeSpring = solarTermsAround(new Date('2024-02-04T08:27:07.999Z'), 'Asia/Shanghai');
  assert.equal(beforeSpring.current.term, '大寒');
  assert.equal(beforeSpring.next.term, '立春');
  assert.equal(beforeSpring.next.date.toISOString(), '2024-02-04T08:27:08.000Z');
  assert.deepEqual(solarTermsAround(beforeSpring.next.date, 'Asia/Shanghai').current, beforeSpring.next);

  const termsAtNewYear = solarTermsAround(new Date('2024-12-31T20:00:00Z'), 'Asia/Shanghai');
  assert.equal(termsAtNewYear.current.term, '冬至');
  assert.equal(termsAtNewYear.next.term, '小寒');
  assert.equal(termsAtNewYear.next.date.getUTCFullYear(), 2025);

  const upperEdge = new Date('2100-01-01T01:00:00Z');
  assert.equal(solarTermsAround(upperEdge, 'America/New_York').next.term, '小寒');
  assert.equal(solarTermsAround(upperEdge, 'Asia/Shanghai'), null);
});
