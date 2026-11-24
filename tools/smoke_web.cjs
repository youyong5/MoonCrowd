/* Copyright 2026 MoonCrowd contributors. SPDX-License-Identifier: Apache-2.0 */
/* Node-only integration test. DOM stub exercises control wiring, not layout. */
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..');
const context = vm.createContext({console});
vm.runInContext(fs.readFileSync(path.join(root,'web/mooncrowd.js'),'utf8'),context);
const api = context.MoonCrowd;
assert.ok(api, 'compiled MoonBit adapter must install its API');
for (let scene=0;scene<3;scene++) {
  const initial = JSON.parse(api.reset(scene,48));
  assert.equal(initial.agents.length,48);
  for(let tick=1;tick<=80;tick++) {
    const state=JSON.parse(api.step());
    assert.equal(state.step,tick);
    assert.equal(state.diagnostics.length,48);
    assert.ok(state.agents.every(a=>a.slice(1).every(Number.isFinite)));
    let overlaps=0, minimum=Infinity;
    for(let i=0;i<state.agents.length;i++)for(let j=i+1;j<state.agents.length;j++){
      const a=state.agents[i],b=state.agents[j];
      const clearance=Math.hypot(a[1]-b[1],a[2]-b[2])-a[5]-b[5];
      minimum=Math.min(minimum,clearance);
      if(clearance < -1e-7)overlaps++;
    }
    assert.equal(state.overlaps,overlaps);
    assert.ok(Math.abs(state.clearance-minimum)<1e-9);
    assert.equal(state.overlap_pairs.length,state.overlaps);
    assert.ok(Number.isInteger(state.obstacle_overlaps));
  }
}
class Element {
  constructor(){this.value='';this.checked=false;this.hidden=false;this.style={};this.dataset={};this.width=0;this.height=0;}
  set textContent(v){this._text=String(v);}
  get textContent(){return this._text||'';}
  setAttribute(k,v){this[k]=v;}
  getBoundingClientRect(){return {width:900,height:650,left:0,top:0};}
  getContext(){return new Proxy({}, {get:(o,k)=>o[k]||(()=>{}),set:(o,k,v)=>(o[k]=v,true)});}
}
const html=fs.readFileSync(path.join(root,'web/index.html'),'utf8');
const elements=Object.fromEntries([...html.matchAll(/id="([^"]+)"/g)].map(m=>[m[1],new Element()]));
elements.count.value='72';elements.trails.checked=true;
const buttons=[0,1,2].map(n=>Object.assign(new Element(),{dataset:{scene:String(n)}}));
const frames=[];
context.document={getElementById:id=>elements[id],querySelectorAll:()=>buttons};
context.window={devicePixelRatio:1};
context.requestAnimationFrame=callback=>frames.push(callback);
vm.runInContext(fs.readFileSync(path.join(root,'web/app.js'),'utf8'),context);
assert.equal(elements.ticks.textContent,'0');
elements.step.onclick();assert.equal(elements.ticks.textContent,'1');
elements.play.onclick();frames.shift()(100);assert.ok(Number(elements.ticks.textContent)>1);
elements.play.onclick();elements.reset.onclick();assert.equal(elements.ticks.textContent,'0');
buttons[2].onclick();assert.equal(elements['scene-name'].textContent,'狭窄通道');
elements.count.value='36';elements.count.oninput();elements.count.onchange();
assert.equal(elements['count-value'].textContent,'36');
assert.equal(elements.arrived.textContent,'0 / 36');
assert.equal(elements.error.hidden,true);
assert.equal(elements.overlaps.textContent,'0');
assert.ok(Number.isFinite(Number(elements.clearance.textContent)));
console.log('Browser adapter: 3 x 80 steps; UI control wiring: passed (DOM stub, no layout assertions).');
