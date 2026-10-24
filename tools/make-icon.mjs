// 生成 1024x1024 不透明 App 图标（纯 Node，无第三方依赖）
import fs from 'node:fs';
import zlib from 'node:zlib';

const S = 1024;
const buf = Buffer.alloc(S * S * 3);

const mix = (a, b, t) => a + (b - a) * t;
const clamp = (v, lo = 0, hi = 1) => Math.min(hi, Math.max(lo, v));
const c255 = (v) => Math.min(255, Math.max(0, v)) | 0;

// 背景：深紫 → 近黑对角渐变 + 中心柔光
for (let y = 0; y < S; y++) {
  for (let x = 0; x < S; x++) {
    const t = clamp((x / S) * 0.55 + (y / S) * 0.45);
    let r = mix(26, 9, t), g = mix(14, 7, t), b = mix(52, 18, t);
    const dx = (x - S * 0.5) / S, dy = (y - S * 0.42) / S;
    const d = Math.sqrt(dx * dx + dy * dy);
    const glow = clamp(1 - d * 2.1) ** 2;
    r = mix(r, 124, glow * 0.55);
    g = mix(g, 92, glow * 0.55);
    b = mix(b, 255, glow * 0.55);
    // 暗角
    const vd = Math.sqrt((x - S / 2) ** 2 + (y - S / 2) ** 2) / (S * 0.5);
    const vig = 1 - clamp((vd - 0.62) / 0.55) * 0.72;
    const i = (y * S + x) * 3;
    buf[i] = c255(r * vig);
    buf[i + 1] = c255(g * vig);
    buf[i + 2] = c255(b * vig);
  }
}

// 中央播放三角（2x2 超采样抗锯齿）
const cx = S / 2 + 34, cy = S / 2, size = S * 0.30;
const ax = cx - size * 0.62, ay = cy - size * 0.92;
const bx = cx - size * 0.62, by = cy + size * 0.92;
const ex = cx + size * 0.95, ey = cy;
function inTri(px, py) {
  const d1 = (px - bx) * (ay - by) - (ax - bx) * (py - by);
  const d2 = (px - ex) * (by - ey) - (bx - ex) * (py - ey);
  const d3 = (px - ax) * (ey - ay) - (ex - ax) * (py - ay);
  const neg = d1 < 0 || d2 < 0 || d3 < 0;
  const pos = d1 > 0 || d2 > 0 || d3 > 0;
  return !(neg && pos);
}
let drawn = 0;
for (let y = Math.floor(Math.max(0, cy - size)); y < Math.ceil(Math.min(S, cy + size)); y++) {
  for (let x = Math.floor(Math.max(0, ax)); x < Math.ceil(Math.min(S, ex)); x++) {
    let hit = 0;
    for (const [ox, oy] of [[0.25, 0.25], [0.75, 0.25], [0.25, 0.75], [0.75, 0.75]]) {
      if (inTri(x + ox, y + oy)) hit++;
    }
    if (!hit) continue;
    drawn++;
    const a = hit / 4;
    const i = (y * S + x) * 3;
    buf[i] = mix(buf[i], 255, a) | 0;
    buf[i + 1] = mix(buf[i + 1], 255, a) | 0;
    buf[i + 2] = mix(buf[i + 2], 255, a) | 0;
  }
}
console.log('triangle pixels', drawn);

// PNG 编码
const table = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c >>> 0;
  }
  return t;
})();
const crc32 = (b) => {
  let c = 0xffffffff;
  for (const v of b) c = table[(c ^ v) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
};
const chunk = (type, data) => {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body));
  return Buffer.concat([len, body, crc]);
};
const ihdr = Buffer.alloc(13);
ihdr.writeUInt32BE(S, 0);
ihdr.writeUInt32BE(S, 4);
ihdr[8] = 8; ihdr[9] = 2; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
const raw = Buffer.alloc(S * (S * 3 + 1));
for (let y = 0; y < S; y++) {
  raw[y * (S * 3 + 1)] = 0;
  buf.copy(raw, y * (S * 3 + 1) + 1, y * S * 3, (y + 1) * S * 3);
}
const png = Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  chunk('IHDR', ihdr),
  chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
  chunk('IEND', Buffer.alloc(0)),
]);
const out = process.argv[2] || 'AppIcon.png';
fs.writeFileSync(out, png);
console.log(out, png.length, 'bytes');
