/* Copyright 2026 MoonCrowd contributors. SPDX-License-Identifier: Apache-2.0 */
'use strict';
(() => {
  const $ = id => document.getElementById(id);
  const canvas = $('canvas'), ctx = canvas.getContext('2d');
  const names = ['环形交换','交叉人流','狭窄通道'];
  const descriptions = ['从圆周走向对侧。微小的侧向偏好帮助打破完美对称。','两组个体沿相反方向穿过彼此，观察让路与流线的形成。','演示提供门口途经点，个体通过宽度有限的通道。'];
  let kind = 0, state = null, running = false, faulted = false, selected = null, last = 0, accumulator = 0;
  const history = new Map();
  function decode(raw) {
    const value = JSON.parse(raw);
    if (value.error) throw new Error(value.error);
    return value;
  }
  function fail(err) {
    running = false; faulted = true; accumulator = 0;
    $('play').disabled = true; $('step').disabled = true;
    $('error').hidden = false;
    $('error').textContent = err.message;
    $('status').textContent = '已停止';
    $('play').textContent = '开始运行';
  }
  function reset(candidateKind = kind) {
    try {
      if (!globalThis.MoonCrowd) throw new Error('请先运行 python3 tools/build_web.py 生成 MoonBit 演示。');
      const next = decode(MoonCrowd.reset(candidateKind, Number($('count').value)));
      state = next; kind = candidateKind; faulted = false;
      running = false;
      $('count').value = String(state.agents.length);
      $('count-value').textContent = state.agents.length;
      $('play').disabled = false; $('step').disabled = false;
      for(const button of document.querySelectorAll('[data-scene]'))button.setAttribute('aria-pressed',String(Number(button.dataset.scene)===kind));
      selected = null; history.clear(); accumulator = 0;
      $('error').hidden = true;
      $('scene-name').textContent = names[kind];
      $('description').textContent = descriptions[kind];
      update(); draw();
    } catch (err) {
      // Keep count controls consistent with the last committed scene on failure.
      if (state) {
        $('count').value = String(state.agents.length);
        $('count-value').textContent = state.agents.length;
      }
      fail(err);
    }
  }
  function advance() {
    if (faulted || !state) return;
    try {
      state = decode(MoonCrowd.step());
      for (const a of state.agents) {
        let trail = history.get(a[0]);
        if (!trail) { trail = []; history.set(a[0],trail); }
        trail.push([a[1],a[2]]);
        if (trail.length > 100) trail.shift();
      }
      update();
    } catch (err) { fail(err); }
  }
  function update() {
    if (!state) return;
    $('clock').textContent = state.time.toFixed(2) + ' s';
    $('ticks').textContent = state.step;
    $('arrived').textContent = state.arrived + ' / ' + state.agents.length;
    $('overlaps').textContent = state.overlaps;
    $('clearance').textContent = state.clearance === null ? '—' : state.clearance.toFixed(4);
    $('overlaps').style.color = state.overlaps ? '#ef9e91' : '';
    $('clearance').style.color = state.clearance < -1e-7 ? '#ef9e91' : '';
    $('violations').textContent = state.violations;
    $('violations').style.color = state.violations ? '#e8ac8d' : '';
    const average = state.agents.reduce((s,a) => s+Math.hypot(a[3],a[4]),0)/state.agents.length;
    $('speed').textContent = average.toFixed(2);
    $('status').textContent = faulted ? '已停止' : (running ? '运行中' : '已暂停');
    $('play').textContent = running ? '暂停' : '开始运行';
    const a = state.agents.find(a => a[0] === selected);
    const d = (state.diagnostics || []).find(d => d[0] === selected);
    $('selected-id').textContent = a ? '#' + a[0] : '—';
    $('inspector').textContent = a ? `位置 (${a[1].toFixed(2)}, ${a[2].toFixed(2)}) · 速度 ${Math.hypot(a[3],a[4]).toFixed(2)}` +
      ((state.obstacle_contacts||[]).includes(a[0]) ? ' · 障碍接触' : '') +
      (d ? ` · 邻居 ${d[1]}${d[2]?'（已截断）':''} · 最大约束违反 ${d[4].toExponential(1)}` : '') : '点击画布中的圆点，查看它的位置、速度与邻居数量。';
  }
  function dimensions() {
    const {width,height} = canvas.getBoundingClientRect();
    const ratio = window.devicePixelRatio || 1;
    if (canvas.width !== Math.round(width*ratio) || canvas.height !== Math.round(height*ratio)) {
      canvas.width = Math.round(width*ratio); canvas.height = Math.round(height*ratio);
    }
    ctx.setTransform(ratio,0,0,ratio,0,0);
    return {width,height,scale:Math.min(width/23,height/20)};
  }
  function draw() {
    const {width:w,height:h,scale:s}=dimensions();
    const point=(x,y)=>[w/2+x*s,h/2-y*s];
    ctx.clearRect(0,0,w,h);
    ctx.lineWidth=1; ctx.strokeStyle='#1b2a2e';
    for(let x=-12;x<=12;x+=2){const p=point(x,0);ctx.beginPath();ctx.moveTo(p[0],0);ctx.lineTo(p[0],h);ctx.stroke();}
    for(let y=-10;y<=10;y+=2){const p=point(0,y);ctx.beginPath();ctx.moveTo(0,p[1]);ctx.lineTo(w,p[1]);ctx.stroke();}
    if(kind===0){ctx.setLineDash([3,6]);ctx.beginPath();ctx.arc(w/2,h/2,8*s,0,Math.PI*2);ctx.strokeStyle='#344849';ctx.stroke();ctx.setLineDash([]);}
    if(kind===2){ctx.lineWidth=5;ctx.strokeStyle='#749397';for(const [y1,y2] of [[-9,-1.2],[1.2,9]]){const a=point(0,y1),b=point(0,y2);ctx.beginPath();ctx.moveTo(...a);ctx.lineTo(...b);ctx.stroke();}}
    if(!state)return;
    const contacts=new Set((state.overlap_pairs||[]).flat().concat(state.obstacle_contacts||[]));
    for(const a of state.agents){
      const color=(kind===0?a[0]<state.agents.length/2:a[0]%2===0)?'#83d8c6':'#e8ac8d';
      const p=point(a[1],a[2]),r=Math.max(2.5,a[5]*s);
      if($('trails').checked){const trail=history.get(a[0])||[];ctx.beginPath();trail.forEach((p,i)=>{const q=point(...p);i?ctx.lineTo(...q):ctx.moveTo(...q);});ctx.lineWidth=1;ctx.strokeStyle=color+'45';ctx.stroke();}
      ctx.beginPath();ctx.arc(...p,r,0,Math.PI*2);ctx.fillStyle=color;ctx.fill();
      if($('vectors').checked || a[0]===selected){const end=point(a[1]+a[3]*.6,a[2]+a[4]*.6);ctx.beginPath();ctx.moveTo(...p);ctx.lineTo(...end);ctx.lineWidth=1.2;ctx.strokeStyle=color;ctx.stroke();}
      if(contacts.has(a[0])){ctx.beginPath();ctx.arc(...p,r+2,0,Math.PI*2);ctx.strokeStyle='#ef9e91';ctx.lineWidth=1.5;ctx.stroke();}
      if(a[0]===selected){ctx.beginPath();ctx.arc(...p,r+5,0,Math.PI*2);ctx.strokeStyle='#ecf6f2';ctx.lineWidth=1;ctx.stroke();}
    }
  }
  function frame(now) {
    if(running && !faulted && state){accumulator+=Math.min((now-last)/1000,.25);let steps=0;while(accumulator>=.05 && steps<5 && running){advance();accumulator-=.05;steps++;}}
    last=now;draw();requestAnimationFrame(frame);
  }
  $('play').onclick=()=>{if(faulted||!state)return;running=!running;accumulator=0;update();};
  $('step').onclick=()=>{running=false;advance();update();draw();};
  $('reset').onclick=()=>reset();
  $('count').oninput=()=>{$('count-value').textContent=$('count').value;};
  $('count').onchange=()=>reset();
  for(const button of document.querySelectorAll('[data-scene]'))button.onclick=()=>reset(Number(button.dataset.scene));
  canvas.onclick=event=>{if(!state)return;const box=canvas.getBoundingClientRect(),s=Math.min(box.width/23,box.height/20);const x=(event.clientX-box.left-box.width/2)/s,y=-(event.clientY-box.top-box.height/2)/s;let distance=Infinity;selected=null;for(const a of state.agents){const d=Math.hypot(a[1]-x,a[2]-y);if(d<Math.max(a[5],.4)&&d<distance){distance=d;selected=a[0];}}update();draw();};
  reset();requestAnimationFrame(frame);
})();
