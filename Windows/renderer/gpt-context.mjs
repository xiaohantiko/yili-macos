import { dayPillarFor } from '../core/bazi.mjs';
import { dailyFor, natalFor } from '../core/interpretation.mjs';

export function buildGPTContext({ chart, date, timeZone, solarTerm }) {
    const parts = Object.fromEntries(new Intl.DateTimeFormat('en-CA', {
        timeZone, year: 'numeric', month: '2-digit', day: '2-digit',
    }).formatToParts(date).map(part => [part.type, part.value]));
    const natal = natalFor(chart);
    const reading = dailyFor(chart, dayPillarFor(date, timeZone));

    return {
        date: `${parts.year}-${parts.month}-${parts.day}`,
        timeZone,
        solarTerm: solarTerm ?? '未知',
        pillars: chart.pillars.map(pillar => pillar.text),
        dayMaster: natal.dayMaster.text + natal.dayMaster.element,
        fiveElements: Object.fromEntries(natal.elements.map(share => [share.element, Math.round(share.fraction * 10000) / 100])),
        dailyPillar: reading.pillar.text,
        trigram: reading.trigram.name,
        direction: reading.trigram.direction,
        basis: reading.basis,
    };
}
