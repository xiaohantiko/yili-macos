import { readFile, writeFile } from 'node:fs/promises';

const source = new URL('../../Sources/YiLiCore/SolarTermTable.swift', import.meta.url);
const destination = new URL('../core/solar-terms.mjs', import.meta.url);
const swift = await readFile(source, 'utf8');
const firstYear = Number(swift.match(/static let firstYear = (\d{4})/)?.[1]);
const rows = Array.from(swift.matchAll(/^\s*\[([\d, ]+)\],\s*\/\/ (\d{4})\s*$/gm), ([, seconds, year]) => ({
  year: Number(year),
  seconds: seconds.split(',').map(Number),
}));

// Coverage in the UTC years on either side of the birth-year range
// allows lookup around January 1 and December 31 in any time zone.
const lastYear = firstYear + rows.length - 1;
if (!Number.isInteger(firstYear) || firstYear > 1900 || lastYear < 2100) {
  throw new Error('Solar term source must include UTC years 1900 through 2100.');
}
for (const [index, { year, seconds }] of rows.entries()) {
  const yearLength = (Date.UTC(year + 1, 0, 1) - Date.UTC(year, 0, 1)) / 1000;
  if (year !== firstYear + index || seconds.length !== 24 || seconds.some((value, index) =>
    value <= (seconds[index - 1] ?? 0) || value >= yearLength
  )) {
    throw new Error(`Invalid solar term row for ${year}.`);
  }
}

const data = [
  '// Generated from Sources/YiLiCore/SolarTermTable.swift. Do not edit.',
  '// Seconds from Jan 1 in term order from 小寒 through 冬至.',
  `export const firstYear = ${firstYear};`,
  'export const secondsByYear = [',
  ...rows.map(({ year, seconds }) => `  [${seconds.join(', ')}], // ${year}`),
  '];',
  '',
].join('\n');
await writeFile(destination, data);
