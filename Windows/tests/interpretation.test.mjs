import assert from "node:assert/strict";
import test from "node:test";
import { branches, chartFor, dayPillarFor, stems } from "../core/bazi.mjs";
import { dailyFor, natalFor, trigrams } from "../core/interpretation.mjs";

const timeZoneID = "Asia/Shanghai";
const chart = chartFor({ year: 2000, month: 1, day: 7, hour: 12, minute: 0, timeZoneID });

test("natal reading uses the day master and the same hidden-stem weights as macOS", () => {
  const reading = natalFor(chart);

  assert.equal(reading.dayMaster.text, "甲");
  assert.equal(reading.headline, "甲木日主");
  assert.deepEqual(reading.elements.map(share => share.element), ["木", "火", "土", "金", "水"]);
  assert.deepEqual(reading.elements.map(share => share.weight), [2, 1.7, 1.9, 1.1, 1.3]);
  assert.ok(Math.abs(reading.elements.reduce((total, share) => total + share.fraction, 0) - 1) < 0.0001);
  assert.equal(reading.observations[0].text, "木占比最高，约 25%。这一分布综合了四柱天干与地支藏干。");
});

test("daily reading distinguishes each direction of five-element interaction", () => {
  const samples = [
    [0, "流日天干甲木与本命日主甲木同属一行", "坎", "借熟悉的节奏推进"],
    [8, "流日天干壬水生本命日主甲木", "乾", "先吸收，再行动"],
    [2, "本命日主甲木生流日天干丙火", "震", "把想法做成草稿"],
    [4, "本命日主甲木克流日天干戊土", "艮", "收拢目标，落实一件"],
    [6, "流日天干庚金克本命日主甲木", "离", "先理清边界"],
  ];

  for (const [offset, relation, trigram, headline] of samples) {
    const day = dayPillarFor(new Date(Date.UTC(2000, 0, 7 + offset, 4)), timeZoneID);
    const reading = dailyFor(chart, day);
    assert.equal(reading.pillar, day);
    assert.ok(reading.basis.startsWith(relation));
    assert.equal(reading.trigram.name, trigram);
    assert.equal(reading.headline, headline);
  }
});

test("all branch trigrams preserve their five-element association and dial bearing", () => {
  const observed = new Set();
  for (const branch of branches) {
    const day = { stem: stems[0], branch, text: stems[0].text + branch.text };
    const { trigram } = dailyFor(chart, day);
    assert.equal(trigram.element, branch.element);
    observed.add(trigram);
  }

  assert.deepEqual(observed, new Set(trigrams));
  assert.deepEqual(trigrams.map(trigram => trigram.bearing), [0, 45, 90, 135, 180, 225, 270, 315]);
});
