// PROTOTYPE — dashboard screen from assets/models_r2/dashboard_data.json (fake but plausible values).
const D = await (await fetch('/models_r2/dashboard_data.json')).json();
const $ = (id) => document.getElementById(id);
const last = (a) => a[a.length - 1];

$('estate').textContent = D.estate; $('plot').textContent = D.plot;
$('date').textContent = D.date; $('stage').textContent = D.stage;
$('cash').textContent = '€ ' + D.cash.toLocaleString('de-DE');
const urgent = D.inbox.filter((m) => m.priority === 'high').length;
$('alertCount').textContent = urgent; $('navInbox').textContent = D.inbox.length;

// ---------------------------------------------------------------- colour scales (diverging good→bad)
const mixHex = (a, b, t) => { const p = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16));
  const [x, y] = [p(a), p(b)]; return `rgb(${x.map((v, i) => Math.round(v + (y[i] - v) * t)).join(',')})`; };
const scale = (stops) => (v) => { for (let i = 0; i < stops.length - 1; i++) { const [a, ca] = stops[i], [b, cb] = stops[i + 1];
  if (v <= b || i === stops.length - 2) return mixHex(ca, cb, Math.min(1, Math.max(0, (v - a) / (b - a)))); } };
const risk = scale([[0, '#2f7d52'], [25, '#8a9a35'], [40, '#c98a2c'], [60, '#b8413c']]);
const oeS = scale([[65, '#3a4f63'], [72, '#4b7a5c'], [80, '#3f9a5f'], [90, '#c8a24a']]);
const waterS = scale([[-1.3, '#b8413c'], [-1.0, '#c98a2c'], [-0.8, '#4b8a5c'], [-0.4, '#3a6f99']]);
const taS = scale([[7, '#8a6b35'], [9, '#3f9a5f'], [11, '#4b7a8a'], [13, '#3a5f86']]);

// ---------------------------------------------------------------- block table (sortable, tooltips)
const cols = [
  { k: 'id', h: 'Block', v: (b) => b.id, cell: (b) => `<b>${b.id}</b>${b.name}<span class="soil">${b.soil}</span>`, cls: 'blk' },
  { k: 'variety', h: 'Variety · rootstock', v: (b) => b.variety, cell: (b) => `${b.variety}<span class="soil">${b.rootstock} · ${b.slope}° ${b.aspect}</span>` },
  { k: 'oe', h: '°Oe', num: 1, v: (b) => last(b.oe), pill: (b) => oeS(last(b.oe)), fmt: (v) => v.toFixed(0),
    tip: (b) => `<b>Must weight ${last(b.oe)} °Oe</b><br>+${(last(b.oe) - b.oe[b.oe.length - 2]).toFixed(1)} since last sample.<br>Mosel minimums: Kabinett 70 · Spätlese 76 · Auslese 83 °Oe.` },
  { k: 'ta', h: 'TA g/L', num: 1, v: (b) => last(b.ta), pill: (b) => taS(last(b.ta)), fmt: (v) => v.toFixed(1),
    tip: (b) => `<b>Titratable acidity ${last(b.ta)} g/L</b> (as tartaric).<br>Falling as malic acid is respired in warm nights.` },
  { k: 'ph', h: 'pH', num: 1, v: (b) => last(b.ph), fmt: (v) => v.toFixed(2) },
  { k: 'water', h: 'Ψstem MPa', num: 1, v: (b) => b.water, pill: (b) => waterS(b.water), fmt: (v) => v.toFixed(2),
    tip: (b) => `<b>Stem water potential ${b.water} MPa</b><br>${b.water < -1.0 ? 'Moderate–strong stress: ripening slows.' : b.water < -0.8 ? 'Mild stress — good for concentration.' : 'No stress.'}` },
  { k: 'downy', h: 'Downy', num: 1, v: (b) => b.downy, pill: (b) => risk(b.downy), fmt: (v) => v + '%', tip: (b) => `<b>Downy mildew risk ${b.downy}%</b><br>Model risk from leaf wetness and temperature.` },
  { k: 'powdery', h: 'Powdery', num: 1, v: (b) => b.powdery, pill: (b) => risk(b.powdery), fmt: (v) => v + '%', tip: (b) => `<b>Powdery mildew risk ${b.powdery}%</b>` },
  { k: 'botrytis', h: 'Botrytis', num: 1, v: (b) => b.botrytis, pill: (b) => risk(b.botrytis), fmt: (v) => v + '%',
    tip: (b) => `<b>Botrytis risk ${b.botrytis}%</b><br>${b.botrytis > 40 ? 'High: rain forecast Mon–Tue. Consider picking first.' : 'Watch after the rain.'}` },
  { k: 'yieldKgHa', h: 'Yield kg/ha', num: 1, v: (b) => b.yieldKgHa, fmt: (v) => v.toLocaleString('de-DE') },
  { k: 'health', h: 'Canopy health', v: (b) => b.health, cell: (b) => `<span class="bar"><i style="width:${b.health * 100}%;background:${mixHex('#b8413c', '#3f9a5f', (b.health - 0.7) / 0.3)}"></i></span>${Math.round(b.health * 100)}` },
];
let sortK = 'botrytis', asc = false;
function renderTable() {
  const rows = [...D.blocks].sort((a, b) => { const c = cols.find((x) => x.k === sortK); const va = c.v(a), vb = c.v(b);
    return (va > vb ? 1 : va < vb ? -1 : 0) * (asc ? 1 : -1); });
  $('blockTable').innerHTML = `<thead><tr>${cols.map((c) => `<th data-k="${c.k}" class="${c.num ? 'num' : ''} ${c.k === sortK ? 'sorted' + (asc ? ' asc' : '') : ''}">${c.h}</th>`).join('')}</tr></thead>
    <tbody>${rows.map((b) => `<tr>${cols.map((c) => {
      const inner = c.cell ? c.cell(b) : c.pill ? `<span class="pill" style="background:${c.pill(b)}">${c.fmt(c.v(b))}</span>` : c.fmt ? c.fmt(c.v(b)) : c.v(b);
      return `<td class="${c.num ? 'num' : ''} ${c.cls ?? ''}" data-tip="${c.tip ? encodeURIComponent(c.tip(b)) : ''}">${inner}</td>`;
    }).join('')}</tr>`).join('')}</tbody>`;
  document.querySelectorAll('th').forEach((th) => th.onclick = () => { const k = th.dataset.k; asc = sortK === k ? !asc : false; sortK = k; renderTable(); });
}
renderTable();
const tip = $('tip');
document.addEventListener('mousemove', (e) => {
  const td = e.target.closest?.('td[data-tip]');
  if (td && td.dataset.tip) { tip.innerHTML = decodeURIComponent(td.dataset.tip); tip.style.left = e.clientX + 14 + 'px'; tip.style.top = e.clientY + 14 + 'px'; tip.style.opacity = 1; }
  else tip.style.opacity = 0;
});

// ---------------------------------------------------------------- ripeness chart (°Oe left axis, TA right axis)
let sel = 'A';
$('chips').innerHTML = D.blocks.map((b) => `<button data-b="${b.id}">${b.id}</button>`).join('');
function renderChart() {
  document.querySelectorAll('#chips button').forEach((b) => b.classList.toggle('on', b.dataset.b === sel));
  const W = 760, H = 420, m = { l: 44, r: 44, t: 14, b: 30 }, cw = W - m.l - m.r, ch = H - m.t - m.b;
  const x = (i) => m.l + (i / (D.weeks.length - 1)) * cw;
  const yOe = (v) => m.t + ch - ((v - 40) / (100 - 40)) * ch, yTa = (v) => m.t + ch - ((v - 5) / (23 - 5)) * ch;
  let s = '';
  for (let v = 40; v <= 100; v += 10) s += `<line x1="${m.l}" x2="${W - m.r}" y1="${yOe(v)}" y2="${yOe(v)}" stroke="#222c35"/><text x="${m.l - 8}" y="${yOe(v) + 4}" fill="#8796a3" font-size="11" text-anchor="end">${v}</text>`;
  for (let v = 5; v <= 23; v += 3) s += `<text x="${W - m.r + 8}" y="${yTa(v) + 4}" fill="#58a6d6" font-size="11">${v}</text>`;
  D.weeks.forEach((w, i) => { s += `<text x="${x(i)}" y="${H - 8}" fill="#8796a3" font-size="11" text-anchor="middle">${w}</text>`; });
  for (const [v, n] of [[70, 'Kabinett'], [76, 'Spätlese'], [83, 'Auslese']])
    s += `<line x1="${m.l}" x2="${W - m.r}" y1="${yOe(v)}" y2="${yOe(v)}" stroke="#7d8a95" stroke-dasharray="4 4" opacity=".7"/><text x="${m.l + 6}" y="${yOe(v) - 4}" fill="#9aa7b2" font-size="11">${n} ${v}</text>`;
  for (const b of D.blocks) if (b.id !== sel) s += `<polyline fill="none" stroke="#c8a24a" stroke-opacity=".18" stroke-width="1.5" points="${b.oe.map((v, i) => `${x(i)},${yOe(v)}`).join(' ')}"/>`;
  const B = D.blocks.find((b) => b.id === sel);
  const area = `${m.l},${m.t + ch} ${B.oe.map((v, i) => `${x(i)},${yOe(v)}`).join(' ')} ${x(B.oe.length - 1)},${m.t + ch}`;
  s += `<defs><linearGradient id="g" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stop-color="#c8a24a" stop-opacity=".28"/><stop offset="1" stop-color="#c8a24a" stop-opacity="0"/></linearGradient></defs>`;
  s += `<polygon points="${area}" fill="url(#g)"/>`;
  s += `<polyline fill="none" stroke="#c8a24a" stroke-width="3" points="${B.oe.map((v, i) => `${x(i)},${yOe(v)}`).join(' ')}"/>`;
  s += `<polyline fill="none" stroke="#58a6d6" stroke-width="2.5" stroke-dasharray="1 0" points="${B.ta.map((v, i) => `${x(i)},${yTa(v)}`).join(' ')}"/>`;
  B.oe.forEach((v, i) => { s += `<circle cx="${x(i)}" cy="${yOe(v)}" r="3.5" fill="#c8a24a"><title>${D.weeks[i]}: ${v} °Oe</title></circle>`; });
  B.ta.forEach((v, i) => { s += `<circle cx="${x(i)}" cy="${yTa(v)}" r="3" fill="#58a6d6"><title>${D.weeks[i]}: TA ${v} g/L</title></circle>`; });
  s += `<text x="${x(B.oe.length - 1) - 6}" y="${yOe(last(B.oe)) - 10}" fill="#e6ebef" font-size="13" font-weight="600" text-anchor="end">${B.id} · ${B.name}: ${last(B.oe)} °Oe · ${last(B.ta)} g/L</text>`;
  $('ripeChart').innerHTML = s;
}
$('chips').onclick = (e) => { if (e.target.dataset.b) { sel = e.target.dataset.b; renderChart(); } };
renderChart();

// ---------------------------------------------------------------- forecast + inbox
const icon = { sun: '☀️', cloud: '☁️', rain: '🌧️' };
const maxRain = Math.max(...D.forecast.map((f) => f.rain), 10);
$('forecast').innerHTML = D.forecast.map((f) => `<div class="day ${f.rain > 5 ? 'wet' : ''}"><b>${f.day}</b><span style="font-size:24px">${icon[f.icon]}</span>
  <span class="t">${f.tmax}° <small>/ ${f.tmin}°</small></span><div class="rain"><i style="height:${Math.max(2, (f.rain / maxRain) * 44)}px"></i></div>
  <span class="t">${f.rain.toFixed(1)} mm</span><span class="rh">${f.rh}% RH</span></div>`).join('');
$('inbox').innerHTML = D.inbox.map((m) => `<div class="msg ${m.priority}"><div class="h"><b>${m.from}</b><span>${m.time}</span></div>
  <div class="s">${m.subject}</div>${m.body ? `<p>${m.body}</p>` : ''}</div>`).join('');

document.querySelectorAll('.timectl button').forEach((b) => b.onclick = () => { b.animate([{ transform: 'scale(.94)' }, { transform: 'scale(1)' }], 160); });
window.demoReady = true;
