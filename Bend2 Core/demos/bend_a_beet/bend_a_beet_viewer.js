(() => {
  "use strict";
  const $=id=>document.getElementById(id),canvas=$("farm"),camera=globalThis.BEND_A_BEET_CAMERA;
  const list=xs=>{const out=[];while(xs&&xs.$==="Con"){out.push(xs.$0);xs=xs.$1}return out};
  const point=p=>({x:p.$0,y:p.$1,depth:p.$2,visible:p.$3});
  if(!globalThis.BEND_A_BEET_DATA||BEND_A_BEET_DATA.$!=="GameReport")throw new Error("Bend-a-Beet Core artifact missing");
  const appearance=a=>({
    color:[a.$0.$0,a.$0.$1,a.$0.$2],texture:a.$1.$0,textureSeed:a.$1.$1,
    roughness:a.$1.$2,metallic:a.$1.$3,reflection:a.$1.$4.$0+1,
    fuzz:a.$1.$5,furLength:a.$1.$6,furDensity:a.$1.$7.$0+1,
    shadowSoftness:a.$2,shadowSamples:a.$3,fog:a.$4,
  });
  const engineProfiles=list(BEND_A_BEET_DATA.$8).map(p=>({tile:p.$0,...appearance(p.$1)}));
  const engineByTile=new Map(engineProfiles.map(profile=>[profile.tile,profile]));
  const beet=b=>({
    tile:b.$0,row:b.$1,column:b.$2,planted:b.$3,water:b.$4,sugar:b.$5,fiber:b.$6,size:b.$7,magic:b.$8,
    pulled:b.$9,outcome:b.$10,detail:b.$11,state:b.$12,bend:b.$13,integrity:b.$14,growth:b.$15,wind:b.$16,
    tileLight:b.$17,beetLight:b.$18,shadowed:b.$19,body:point(b.$20),root:point(b.$21),control:point(b.$22),
    tip:point(b.$23),left:point(b.$24),right:point(b.$25),radius:b.$26,broken:b.$27,impulse:b.$28,
    stiffness:b.$29,damping:b.$30,flexibility:b.$31,maxBend:b.$32,period:b.$33,responseDuration:b.$34,
    signature:b.$35,breakAt:b.$36,shine:b.$37,specular:b.$38,absorbed:b.$39,shadow:point(b.$40),
    radial:b.$41,vertical:b.$42,leafSegments:b.$43,engine:engineByTile.get(b.$0),
  });
  const frame=f=>({time:f.$0,duration:f.$1,phase:f.$2,note:f.$3,active:f.$4,beets:list(f.$5).map(beet)});
  const report={title:BEND_A_BEET_DATA.$0,seed:BEND_A_BEET_DATA.$1,rows:BEND_A_BEET_DATA.$2,columns:BEND_A_BEET_DATA.$3,planted:BEND_A_BEET_DATA.$4,broken:BEND_A_BEET_DATA.$5,spring:BEND_A_BEET_DATA.$6,recover:BEND_A_BEET_DATA.$7,engineProfiles,frames:list(BEND_A_BEET_DATA.$9).map(frame)};
  const renderer=globalThis.BEND_A_BEET_WEBGL.create(canvas,camera);
  let at=0,timer=0,playing=true,lastStats={triangles:0,furStrands:0};
  function activeCard(frame){const active=frame.active<24?frame.beets[frame.active]:null,card=$("active-card");if(active&&active.planted){const attrs=[["water",active.water],["sugar",active.sugar],["fiber",active.fiber],["size",active.size],["magic",active.magic],["shine",active.shine]],e=active.engine;card.innerHTML=`<h2>Tile ${active.row+1}.${active.column+1} · ${active.state}</h2><div class="outcome">${active.outcome}${active.detail?` · ${active.detail} ${active.outcome==="break"?"pieces":"boings"}`:""}</div><div>bend ${active.bend} · integrity ${active.integrity} · specular ${active.specular} · absorbed ${active.absorbed}</div><div>${active.radial}×${active.vertical} body mesh · ${active.leafSegments} leaf slices</div><div>Engine texture ${e.texture} · reflection ${e.reflection} · fuzz ${e.fuzz} · ${e.furDensity} fur roots</div><div class="attrs">${attrs.map(([k,v])=>`<div class="attr">${k}<b>${v}</b></div>`).join("")}</div>`}else card.innerHTML=`<h2>Seed ${report.seed}</h2><div>${report.planted} planted tiles in the 3 × 8 field</div><div class="outcome">All beets uproot together at exactly 5 seconds.</div><div>Core supplies Engine textures, a four-light rig, fog, reflection, fuzz, fur and soft-shadow controls.</div>`;card.hidden=false}
  function render(){const f=report.frames[at];lastStats=renderer.render(f,report);$("phase").textContent=f.phase;$("note").textContent=`${f.note} · ${lastStats.triangles.toLocaleString()} live triangles · ${(lastStats.furStrands||0).toLocaleString()} fur strands`;$("clock").textContent=f.phase==="Growing"?`${(f.time/1000).toFixed(2)} / 5.00 s`:f.phase==="Uproot"?`${((f.time-5000)/1000).toFixed(2)} s pull`:f.active<24?`${(f.time/1000).toFixed(2)} s response`:`frame ${at+1}`;$("counter").textContent=`${at+1} / ${report.frames.length}`;$("prev").disabled=at===0;$("next").disabled=at===report.frames.length-1;activeCard(f)}
  function stop(){clearTimeout(timer);timer=0;playing=false;$("play").textContent="▶ Play"}
  function schedule(){if(!playing)return;const f=report.frames[at],factor=100/Number($("speed").value);timer=setTimeout(()=>{if(at+1>=report.frames.length){stop();return}at++;render();schedule()},Math.max(30,f.duration*factor))}
  function play(){if(playing){stop();return}playing=true;$("play").textContent="Ⅱ Pause";schedule()}
  $("first").onclick=()=>{stop();at=0;render()};$("prev").onclick=()=>{stop();at=Math.max(0,at-1);render()};$("next").onclick=()=>{stop();at=Math.min(report.frames.length-1,at+1);render()};$("play").onclick=play;$("speed").onchange=()=>{if(playing){clearTimeout(timer);schedule()}};
  for(const [id,name] of [["render-fur","fur"],["render-shadows","softShadows"],["render-fog","fog"],["render-facets","facets"]]){$(id).onchange=event=>{renderer.setOption?.(name,event.target.checked);render()}}
  window.addEventListener("bend-a-beet-camera",render);$("planted").textContent=report.planted;$("breaks").textContent=report.broken;$("springs").textContent=report.spring;$("recovers").textContent=report.recover;render();schedule();
  globalThis.BEND_A_BEET_VIEWER={report,camera,renderer,render,select(index){stop();at=Math.max(0,Math.min(report.frames.length-1,index));render()},get stats(){return lastStats}};
})();
