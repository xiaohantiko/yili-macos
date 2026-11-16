const elements = ["木", "火", "土", "金", "水"];
const generates = { 木: "火", 火: "土", 土: "金", 金: "水", 水: "木" };
const controls = { 木: "土", 火: "金", 土: "水", 金: "木", 水: "火" };
const hiddenWeights = { 1: [10], 2: [7, 3], 3: [6, 3, 1] };

const trigramByName = Object.fromEntries([
  ["坎", "☵", "正北", 0, "水", "水", "整理容易积压的物品，给桌面留一块空白。"],
  ["艮", "☶", "东北", 45, "山", "土", "把随手乱放的小物归到固定位置，给一项杂事收个尾。"],
  ["震", "☳", "正东", 90, "雷", "木", "清出一条顺畅的动线，迈出一件小事的第一步。"],
  ["巽", "☴", "东南", 135, "风", "木", "天气合适时开窗通风，顺手整理窗边。"],
  ["离", "☲", "正南", 180, "火", "火", "把阅读或书写的位置收拾明亮，集中处理一项任务。"],
  ["坤", "☷", "西南", 225, "地", "土", "归置共享区域，给常用物留出取放方便的位置。"],
  ["兑", "☱", "正西", 270, "泽", "金", "整理一处可坐下聊天的角落，给交流留点时间。"],
  ["乾", "☰", "西北", 315, "天", "金", "清理文件和工具，把当天的重点放在显眼处。"],
].map(([name, symbol, direction, bearing, image, element, prompt]) => [
  name,
  Object.freeze({ id: name, name, symbol, direction, bearing, image, element, prompt }),
]));

export const trigrams = Object.freeze(Object.values(trigramByName));

// The app pairs the branch's element with a later-heaven trigram.
const trigramNameByBranch = {
  子: "坎", 丑: "坤", 寅: "震", 卯: "巽", 辰: "艮", 巳: "离",
  午: "离", 未: "坤", 申: "乾", 酉: "兑", 戌: "艮", 亥: "坎",
};

export const natalMethod = "取日柱天干为日主。每柱天干计 1，地支藏干合计 1。一个藏干计 1，两个依次计 0.7、0.3，三个依次计 0.6、0.3、0.1。百分比展示本应用的五行分布。传统旺衰与用神须结合月令、格局等另行分析。";
export const dailyMethod = "比较流日天干与本命日主的五行生克，得到行动主题。本应用按流日地支取卦，子亥取坎、辰戌取艮、寅取震、卯取巽、巳午取离、丑未取坤、酉取兑、申取乾。卦象和后天方位用于象征性的空间整理提示。";

const dayMasterProfile = {
  甲: "借甲木向上生长的意象，观察自己如何推进长线目标。选一件想做深的事，给它固定的时间，再允许做法随反馈调整。",
  乙: "借乙木顺势伸展的意象，观察自己如何在变化中找空间。卡住时，可以先换一种问法或找一位能互补的同伴。",
  丙: "借丙火照亮四方的意象，观察自己如何分享想法、带动讨论。表达之后留一点停顿，让他人的想法也有机会展开。",
  丁: "借丁火照见近处的意象，观察自己如何照顾细节。给一件值得用心的事留下完整时间，再决定哪些细节可以放手。",
  戊: "借戊土承托的意象，观察自己如何建立稳固的安排。明确一项最重要的责任，也给计划留出随情况调整的余地。",
  己: "借己土培育的意象，观察自己如何把零散资源变成长期积累。把照顾他人的时间和自己的恢复时间一起写进日程。",
  庚: "借庚金成器的意象，观察自己如何取舍和执行。先说清选择的标准，再用一次小范围试行验证它。",
  辛: "借辛金琢磨的意象，观察自己如何打磨品质。给每次修订设一个完成标准，留时间收集真实反馈。",
  壬: "借壬水流动的意象，观察自己如何应对变化。备好另一条路径，也选一件值得持续投入的事作为主线。",
  癸: "借癸水浸润的意象，观察自己如何从细节收集信息。先写下观察，再用一个小行动验证判断。",
};

const paceByElement = {
  木: "给一件新事留二十分钟试做，结束时记下下一步。",
  火: "把需要集中表达的事情安排在一个时段，前后各留一点安静时间。",
  土: "先照顾吃饭、休息和出门准备，再安排可选的活动。",
  金: "删去一项低优先级安排，集中整理需要带走或交付的东西。",
  水: "在紧凑的安排之间留一个空档，散步或记下今天的感受。",
};

const flowGuidance = {
  sameElement: {
    description: (natal, flow) => `流日天干${flow}与本命日主${natal}同属一行`,
    headline: "借熟悉的节奏推进",
    summary: "把精力放到一个已经摸清方向的目标上，顺手和同行的人对齐进度。",
    work: "选一项有积累的任务，定下今天能交付的部分，再安排后续。",
    relationships: "和熟悉的人交换近况，合作前说清各自负责的部分。",
    favors: ["推进手头重点", "和伙伴对齐进度"],
    easeBack: ["同时开启多个任务", "比较彼此的进度"],
  },
  supportsNatal: {
    description: (natal, flow) => `流日天干${flow}生本命日主${natal}`,
    headline: "先吸收，再行动",
    summary: "留一段时间整理信息或请教，把获得的帮助转成能立刻做的一小步。",
    work: "把卡点写成一个具体问题，找资料或请教有经验的人。",
    relationships: "听完再复述对方的重点，确认理解后再回应。",
    favors: ["请教与整理笔记", "复盘近期经验"],
    easeBack: ["资料未齐就定方案", "把日程排得太满"],
  },
  expressesNatal: {
    description: (natal, flow) => `本命日主${natal}生流日天干${flow}`,
    headline: "把想法做成草稿",
    summary: "用一份能看见、能讨论的初稿，把脑海里的想法往前推一步。",
    work: "给写作、制作或展示划出一段完整时间，先做一个可评议的版本。",
    relationships: "说出一个具体想法或感受，并问问对方接收到了什么。",
    favors: ["写初稿或做原型", "分享阶段成果"],
    easeBack: ["过早反复润色", "一次说太多重点"],
  },
  directedByNatal: {
    description: (natal, flow) => `本命日主${natal}克流日天干${flow}`,
    headline: "收拢目标，落实一件",
    summary: "用清晰的完成条件把零散事务归拢起来，优先做可确认的一件。",
    work: "选一项积压任务，写出完成标准，按步骤处理并确认结果。",
    relationships: "把请求、时间和分工说清楚，留出让对方回应的空间。",
    favors: ["清理待办", "确认分工与时限"],
    easeBack: ["临时增加承诺", "替他人作决定"],
  },
  checksNatal: {
    description: (natal, flow) => `流日天干${flow}克本命日主${natal}`,
    headline: "先理清边界",
    summary: "遇到规则、时限或分歧时，先弄清条件，再选一个能控制的动作。",
    work: "先确认规则、依赖和期限，做完一段就检查一次。",
    relationships: "分歧时先确认事实与各自需要，把后续行动约具体。",
    favors: ["校对关键细节", "预留调整时间"],
    easeBack: ["匆忙作出承诺", "在情绪最强时争辩"],
  },
};

function guidanceFor(natal, flow) {
  if (natal === flow) return flowGuidance.sameElement;
  if (generates[flow] === natal) return flowGuidance.supportsNatal;
  if (generates[natal] === flow) return flowGuidance.expressesNatal;
  if (controls[natal] === flow) return flowGuidance.directedByNatal;
  return flowGuidance.checksNatal;
}

function readingNote(title, text) {
  return { id: title, title, text };
}

function elementShares(chart) {
  const weights = Object.fromEntries(elements.map(element => [element, 0]));
  for (const { stem, branch } of chart.pillars) {
    weights[stem.element] += 10;
    const branchWeights = hiddenWeights[branch.hiddenStems.length];
    branch.hiddenStems.forEach((hiddenStem, index) => {
      weights[hiddenStem.element] += branchWeights[index];
    });
  }
  const total = chart.pillars.length * 20;
  return elements.map(element => ({
    id: element,
    element,
    weight: weights[element] / 10,
    fraction: weights[element] / total,
  }));
}

export function natalFor(chart) {
  const dayMaster = chart.day.stem;
  const shares = elementShares(chart);
  const maxWeight = Math.max(...shares.map(share => share.weight));
  const leading = shares.filter(share => share.weight === maxWeight);
  const leadingNames = leading.map(share => share.element).join("、");
  let distribution;
  if (leading.length === shares.length) {
    distribution = "五行权重相同。可以逐一对照五行的意象，选出最贴近近期处境的一项。";
  } else {
    const percent = Math.round(leading[0].fraction * 100);
    const description = leading.length === 1 ? `占比最高，约 ${percent}%` : `并列最高，各约 ${percent}%`;
    distribution = `${leadingNames}${description}。这一分布综合了四柱天干与地支藏干。`;
  }

  return {
    dayMaster,
    elements: shares,
    headline: `${dayMaster.text}${dayMaster.element}日主`,
    summary: dayMasterProfile[dayMaster.text],
    observations: [
      readingNote("五行分布", distribution),
      readingNote(
        "出生时节",
        `月柱为${chart.month.text}，月支${chart.month.branch.text}属${chart.month.branch.element}。传统子平法以月令作为观察出生时节的重要线索。`,
      ),
    ],
  };
}

export function dailyFor(chart, day) {
  const dayMaster = chart.day.stem;
  const guidance = guidanceFor(dayMaster.element, day.stem.element);
  const trigram = trigramByName[trigramNameByBranch[day.branch.text]];
  const natalName = dayMaster.text + dayMaster.element;
  const flowName = day.stem.text + day.stem.element;
  const relation = guidance.description(natalName, flowName);
  const branchElement = day.branch.element;
  const natalShare = elementShares(chart).find(share => share.element === branchElement);
  const natalPercent = Math.round(natalShare.fraction * 100);

  return {
    pillar: day,
    headline: guidance.headline,
    summary: guidance.summary,
    notes: [
      readingNote("工作与学习", guidance.work),
      readingNote("人际与沟通", guidance.relationships),
      readingNote("生活节奏", paceByElement[branchElement]),
    ],
    favors: [...guidance.favors],
    easeBack: [...guidance.easeBack],
    trigram,
    basis: `${relation}。流日地支${day.branch.text}属${branchElement}，此五行在本命中约占 ${natalPercent}%。取${trigram.name}卦，后天方位为${trigram.direction}。`,
  };
}
