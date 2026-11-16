import { trigrams } from './core/interpretation.mjs';

const bars = {
    坎: [0, 1, 0], 艮: [1, 0, 0], 震: [0, 0, 1], 巽: [1, 1, 0],
    离: [1, 0, 1], 坤: [0, 0, 0], 兑: [0, 1, 1], 乾: [1, 1, 1],
};

export function drawBagua(canvas, active) {
    const size = 224;
    const center = size / 2;
    const density = window.devicePixelRatio || 1;
    canvas.width = canvas.height = size * density;
    const ctx = canvas.getContext('2d');
    ctx.scale(density, density);
    ctx.translate(center, center);
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';

    const angle = (bearing) => (bearing - 90) * Math.PI / 180;
    const point = (bearing, radius) => [Math.cos(angle(bearing)) * radius, Math.sin(angle(bearing)) * radius];
    function stroke(color, width, draw) {
        ctx.beginPath();
        ctx.strokeStyle = color;
        ctx.lineWidth = width;
        draw();
        ctx.stroke();
    }
    function line(bearing, inner, outer, color, width) {
        stroke(color, width, () => {
            ctx.moveTo(...point(bearing, inner));
            ctx.lineTo(...point(bearing, outer));
        });
    }
    function trigramLines(trigram, x, y, width, color) {
        ctx.fillStyle = color;
        for (const [row, solid] of bars[trigram.name].entries()) {
            const top = y + (row - 1) * width / 4.6 - width / 26;
            ctx.fillRect(x - width / 2, top, width * (solid ? 1 : 0.41), width / 13);
            if (!solid) ctx.fillRect(x + width * 0.09, top, width * 0.41, width / 13);
        }
    }

    for (const radius of [110, 101, 76, 52, 41]) {
        stroke(radius === 101 ? '#c6a36766' : '#c6a36734', 0.75, () => ctx.arc(0, 0, radius, 0, 2 * Math.PI));
    }
    for (let tick = 0; tick < 72; tick += 1) {
        const major = tick % 9 === 0;
        line(tick * 5, major ? 102 : 106, 109, major ? '#c6a367ae' : '#c6a36745', major ? 1.1 : 0.6);
    }
    for (const trigram of trigrams) {
        const on = trigram.name === active.name;
        const { bearing } = trigram;
        line(bearing + 22.5, 52, 101, '#c6a36738', 0.7);
        if (on) stroke('#e0c38d', 1.8, () => ctx.arc(0, 0, 101, angle(bearing - 16), angle(bearing + 16)));
        ctx.fillStyle = on ? '#e0c38d' : '#a29e8e';
        ctx.font = '16px SimSun, "Songti SC", serif';
        ctx.fillText(trigram.name, ...point(bearing, 88));
        trigramLines(trigram, ...point(bearing, 63), 16, on ? '#e0c38d' : '#c6a3677a');
    }
    trigramLines(active, 0, -7, 37, '#e0c38d');
    ctx.fillStyle = '#c6a367';
    ctx.font = '11px sans-serif';
    ctx.fillText(active.direction, 0, 20);
}
