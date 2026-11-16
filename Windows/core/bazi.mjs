import { firstYear, secondsByYear } from './solar-terms.mjs';

export const supportedYears = Object.freeze([1901, 2099]);

export const stems = Object.freeze(Array.from('甲乙丙丁戊己庚辛壬癸', (text, index) => Object.freeze({
  text,
  element: '木木火火土土金金水水'[index],
})));

// Hidden stems are in principal, middle, and residual order as on macOS.
const hiddenStemTable = [
  ['子', '癸'], ['丑', '己癸辛'], ['寅', '甲丙戊'], ['卯', '乙'], ['辰', '戊乙癸'], ['巳', '丙庚戊'],
  ['午', '丁己'], ['未', '己丁乙'], ['申', '庚壬戊'], ['酉', '辛'], ['戌', '戊辛丁'], ['亥', '壬甲'],
];
export const branches = Object.freeze(hiddenStemTable.map(([text, hidden]) => {
  const hiddenStems = Object.freeze(Array.from(hidden, name => stems.find(stem => stem.text === name)));
  return Object.freeze({ text, element: hiddenStems[0].element, hiddenStems });
}));

const solarTerms = [
  '小寒', '大寒', '立春', '雨水', '惊蛰', '春分', '清明', '谷雨',
  '立夏', '小满', '芒种', '夏至', '小暑', '大暑', '立秋', '处暑',
  '白露', '秋分', '寒露', '霜降', '立冬', '小雪', '大雪', '冬至',
];
const lastSolarTerm = solarTerms.length - 1;
const millisecondsPerDay = 86_400_000;
const formatters = new Map();

const errorMessages = {
  unsupportedYear: '出生年份须在 1901 至 2099 年之间。',
  invalidDate: '请填写有效的公历出生日期。',
  invalidTime: '请填写 00:00 至 23:59 之间的出生时间。',
  invalidTimeZone: '请选择有效的出生地时区。',
  unavailableCivilTime: '该时区的这段本地时间因时钟调整而跳过，请核对出生时间或时区。',
};

export class BaziError extends Error {
  constructor(code) {
    super(errorMessages[code]);
    this.name = 'BaziError';
    this.code = code;
  }
}

export function chartFor(birth) {
  const { year, hour } = birth;
  const { instant, civilTime } = resolveBirth(birth);
  // 立春 begins the new year at the same astronomical instant in every zone.
  const solarYear = instant < termTime(year, 2) ? year - 1 : year;
  const yearPillar = cyclicalPillar(solarYear - 1984);

  const { index } = currentTerm(instant);
  // Each 节 opens a new month. 小寒 opens 丑, the last month of the solar year.
  const monthOffset = (Math.floor(index / 2) + 11) % 12;
  const monthStem = (stems.indexOf(yearPillar.stem) % 5 * 2 + 2 + monthOffset) % 10;
  const monthPillar = pillar(monthStem, (2 + monthOffset) % 12);

  // The 子 hour starts at 23:00. Its stem changes with the civil day at 00:00.
  const dayPillar = dayPillarAtCivilTime(civilTime);
  const hourBranch = Math.floor((hour + 1) / 2) % 12;
  const hourStem = (stems.indexOf(dayPillar.stem) % 5 * 2 + hourBranch) % 10;
  const hourPillar = pillar(hourStem, hourBranch);
  return {
    year: yearPillar,
    month: monthPillar,
    day: dayPillar,
    hour: hourPillar,
    pillars: [yearPillar, monthPillar, dayPillar, hourPillar],
  };
}

export function dayPillarFor(date, timeZoneID) {
  const instant = date.getTime();
  const civilTime = instant + offsetAt(formatterFor(timeZoneID), instant);
  return dayPillarAtCivilTime(civilTime);
}

export function solarTermsAround(date, timeZoneID) {
  const instant = date.getTime();
  if (!Number.isFinite(instant)) return null;
  const civilTime = instant + offsetAt(formatterFor(timeZoneID), instant);
  const civilYear = new Date(civilTime).getUTCFullYear();
  if (!inRange(civilYear, ...supportedYears)) return null;
  const { year, index } = currentTerm(instant);
  const next = index === lastSolarTerm ? occurrence(year + 1, 0) : occurrence(year, index + 1);
  return { current: occurrence(year, index), next };
}

function resolveBirth({ year, month, day, hour, minute, timeZoneID }) {
  if (!inRange(year, ...supportedYears)) throw new BaziError('unsupportedYear');
  if (!inRange(month, 1, 12) || !inRange(day, 1, 31)) throw new BaziError('invalidDate');
  if (!inRange(hour, 0, 23) || !inRange(minute, 0, 59)) throw new BaziError('invalidTime');
  const formatter = formatterFor(timeZoneID);
  const civilTime = Date.UTC(year, month - 1, day, hour, minute);
  if (new Date(civilTime).getUTCDate() !== day) throw new BaziError('invalidDate');

  // The adjacent UTC days bracket the time-zone offsets that can apply here.
  // Round-trip each candidate to reject skipped times and select the earlier overlap.
  const offsets = new Set([
    offsetAt(formatter, civilTime - millisecondsPerDay),
    offsetAt(formatter, civilTime + millisecondsPerDay),
  ]);
  let instant = Infinity;
  for (const offset of offsets) {
    const candidate = civilTime - offset;
    if (offsetAt(formatter, candidate) === offset) instant = Math.min(instant, candidate);
  }
  if (instant === Infinity) throw new BaziError('unavailableCivilTime');
  return { instant, civilTime };
}

function formatterFor(timeZoneID) {
  if (typeof timeZoneID !== 'string' || !/^[a-z]/i.test(timeZoneID)) {
    throw new BaziError('invalidTimeZone');
  }
  let formatter = formatters.get(timeZoneID);
  if (!formatter) {
    try {
      formatter = new Intl.DateTimeFormat('en-US', {
        timeZone: timeZoneID,
        timeZoneName: 'longOffset',
        numberingSystem: 'latn',
      });
    } catch (error) {
      if (error instanceof RangeError) throw new BaziError('invalidTimeZone');
      throw error;
    }
    formatters.set(timeZoneID, formatter);
  }
  return formatter;
}

function offsetAt(formatter, instant) {
  const offset = formatter.formatToParts(instant).find(part => part.type === 'timeZoneName').value;
  if (offset === 'GMT') return 0;
  // Historical zones can have offsets finer than a minute, e.g. GMT+05:41:16.
  const match = /^GMT([+-])(\d{2}):(\d{2})(?::(\d{2}))?$/.exec(offset);
  if (!match) throw new Error(`Unexpected time zone offset: ${offset}`);
  const [, sign, hours, minutes, seconds = '0'] = match;
  return (Number(hours) * 3600 + Number(minutes) * 60 + Number(seconds)) * (sign === '-' ? -1000 : 1000);
}

function inRange(value, min, max) {
  return Number.isInteger(value) && value >= min && value <= max;
}

function dayPillarAtCivilTime(civilTime) {
  const julianDayNumber = Math.floor(civilTime / millisecondsPerDay) + 2_440_588;
  // The JDN anchor is shared with BaziCalculator.dayPillar on macOS.
  return cyclicalPillar(julianDayNumber + 49);
}

function pillar(stemIndex, branchIndex) {
  const stem = stems[stemIndex];
  const branch = branches[branchIndex];
  return { stem, branch, text: stem.text + branch.text };
}

function cyclicalPillar(index) {
  const cycleIndex = (index % 60 + 60) % 60;
  return pillar(cycleIndex % 10, cycleIndex % 12);
}

function currentTerm(instant) {
  const year = new Date(instant).getUTCFullYear();
  const elapsed = (instant - Date.UTC(year, 0, 1)) / 1000;
  const index = secondsByYear[year - firstYear].findLastIndex(seconds => seconds <= elapsed);
  return index < 0 ? { year: year - 1, index: lastSolarTerm } : { year, index };
}

function termTime(year, index) {
  return Date.UTC(year, 0, 1) + secondsByYear[year - firstYear][index] * 1000;
}

function occurrence(year, index) {
  return { term: solarTerms[index], date: new Date(termTime(year, index)) };
}
