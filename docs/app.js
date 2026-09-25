const $ = (selector) => document.querySelector(selector);

async function boot() {
  const response = await fetch('data/dashboard-data.json');
  if (!response.ok) throw new Error('Dashboard data could not be loaded.');
  const data = await response.json();
  $('#scope').textContent = data.project.scope;
  $('#facts').innerHTML = data.facts.map(item => `<article class="fact"><span>${item.label}</span><strong>${item.value}</strong><small>${item.note}</small></article>`).join('');
  $('#latest-table').innerHTML = data.latest.map(item => `<tr><td>${item.rank}</td><td>${item.skill}</td><td>${item.mentions.toLocaleString()}</td><td>${item.share.toFixed(2)}%</td></tr>`).join('');
  $('#companions-list').innerHTML = data.snowflakeCompanions.map(item => `<div class="companion"><strong>${item.skill}</strong><b>${item.confidence.toFixed(2)}%</b><small>directional confidence | lift ${item.lift.toFixed(2)}</small></div>`).join('');
  $('#quality').innerHTML = data.quality.map(([label, value]) => `<article class="quality"><strong>${value}</strong><span>${label}</span></article>`).join('');
  $('#validation').innerHTML = data.validation.map(([label, value]) => `<article class="validation"><strong>${label}</strong><span>${value}</span></article>`).join('');
  const select = $('#skill-select');
  Object.keys(data.series).sort().forEach(skill => { const option = new Option(skill, skill); select.add(option); });
  select.value = 'snowflake';
  const update = () => renderTrend(select.value, data.series[select.value]);
  select.addEventListener('change', update);
  update();
}

function renderTrend(skill, values) {
  const svg = $('#trend-chart');
  const W = 900, H = 360, L = 60, R = 25, T = 32, B = 42;
  const max = Math.ceil(Math.max(...values.map(v => v.mentions)) / 250) * 250;
  const x = (i) => L + i * (W - L - R) / (values.length - 1);
  const y = (v) => H - B - v * (H - T - B) / max;
  let nodes = '';
  for (let i = 0; i <= 4; i++) { const value = max * i / 4; const yy = y(value); nodes += `<line class="grid-line" x1="${L}" y1="${yy}" x2="${W-R}" y2="${yy}"/><text class="axis-label" x="${L-10}" y="${yy+4}" text-anchor="end">${Math.round(value).toLocaleString()}</text>`; }
  [0, 5, 11, 17].forEach(i => { nodes += `<text class="axis-label" x="${x(i)}" y="${H-13}" text-anchor="middle">${values[i].month.slice(2)}</text>`; });
  const path = values.map((v, i) => `${i ? 'L' : 'M'} ${x(i)} ${y(v.mentions)}`).join(' ');
  nodes += `<path class="trend-path" d="${path}"/>`;
  nodes += values.map((v, i) => `<circle class="trend-dot" cx="${x(i)}" cy="${y(v.mentions)}" r="4"><title>${v.month}: ${v.mentions.toLocaleString()} postings (${v.share.toFixed(2)}%)</title></circle>`).join('');
  svg.innerHTML = nodes;
  $('#chart-title').textContent = skill;
  const first = values[0].mentions, last = values.at(-1).mentions;
  $('#chart-latest').textContent = `${last.toLocaleString()} mentions`;
  $('#chart-change').textContent = `${last >= first ? '+' : ''}${(last-first).toLocaleString()} since ${values[0].month}`;
}

boot().catch(error => { document.body.innerHTML = `<main class="wrap section"><h1>Dashboard data unavailable</h1><p>${error.message}</p></main>`; });
