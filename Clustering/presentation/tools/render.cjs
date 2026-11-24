const fs = require('node:fs/promises');
const path = require('node:path');
const {pathToFileURL} = require('node:url');
const assert = require('node:assert/strict');
const runtime = process.env.CODEX_NODE_MODULES || '/home/veritas/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules';
const { chromium } = require(path.join(runtime, 'playwright'));

(async () => {
  const root = path.resolve(__dirname, '..');
  const out = process.env.PRESENTATION_QA || '/tmp/bend-presentation-qa';
  await fs.mkdir(out, {recursive:true});
  const browser = await chromium.launch({headless:true, args:['--no-sandbox','--disable-dev-shm-usage']});
  try {
    const page = await browser.newPage({viewport:{width:1920,height:1128}, deviceScaleFactor:1});
    const errors=[];
    const network=[];
    page.on('pageerror', error => errors.push(error.message));
    page.on('request', request => {if(/^https?:/.test(request.url()))network.push(request.url())});
    await page.goto(pathToFileURL(path.join(root,'index.html')).href);
    await page.evaluate(() => document.fonts.ready);
    const ids = await page.locator('#stage > section').evaluateAll(s => s.map(e=>e.id));
    assert.equal(ids.length,37,'The recovered deck must retain all 37 slides');
    await page.keyboard.press('Home');
    assert.equal(await page.evaluate(()=>window.currentSlide()),0);
    await page.keyboard.press('ArrowRight');
    assert.equal(await page.evaluate(()=>window.currentSlide()),1);
    await page.keyboard.press('End');
    assert.equal(await page.evaluate(()=>window.currentSlide()),36);
    await page.locator('#previous').click();
    assert.equal(await page.evaluate(()=>window.currentSlide()),35);
    await page.locator('#slide-picker').selectOption('26');
    assert.equal(await page.evaluate(()=>window.currentSlide()),26);
    assert.equal(await page.evaluate(()=>location.hash),'#prefilter');
    const reports=[];
    for (let i=0;i<ids.length;i++) {
      await page.evaluate(i=>window.showSlide(i),i);
      const report=await page.evaluate(()=>{
        const slide=document.querySelector('#stage > section:not([hidden])');
        const sr=slide.getBoundingClientRect();
        const foot=slide.querySelector('.foot')?.getBoundingClientRect();
        const overflow=[];
        for(const el of slide.querySelectorAll('*')) {
          if(el.closest('svg') || el.matches('svg,x-connector'))continue;
          const r=el.getBoundingClientRect();
          if(r.width===0||r.height===0)continue;
          const text=el.textContent.trim().slice(0,100);
          if(r.right>sr.right+1||r.bottom>sr.bottom+1||r.left<sr.left-1||r.top<sr.top-1)overflow.push({kind:'slide',tag:el.tagName,cls:el.className,text,bounds:[r.x,r.y,r.width,r.height]});
          if(el.scrollWidth>el.clientWidth+3&&el.clientWidth>0)overflow.push({kind:'horizontal',tag:el.tagName,cls:el.className,text,width:el.clientWidth,scroll:el.scrollWidth});
          if(foot && !el.closest('.foot') && r.top<foot.bottom && r.bottom>foot.top && !el.contains(slide.querySelector('.foot')) && text && ['P','TABLE','UL'].includes(el.tagName))overflow.push({kind:'footer',tag:el.tagName,cls:el.className,text,bottom:r.bottom,footerTop:foot.top});
        }
        return {id:slide.id,overflow};
      });
      reports.push(report);
      await page.screenshot({path:path.join(out,`${String(i+1).padStart(2,'0')}-${ids[i]}.png`),clip:{x:0,y:0,width:1920,height:1080}});
    }
    await page.setViewportSize({width:1280,height:720});
    await page.evaluate(()=>window.showSlide(35));
    const responsive=await page.evaluate(()=>{
      const s=document.querySelector('#stage > section:not([hidden])').getBoundingClientRect();
      return {viewport:[innerWidth,innerHeight],slide:[s.x,s.y,s.width,s.height],inside:s.x>=-1&&s.y>=-1&&s.right<=innerWidth+1&&s.bottom<=innerHeight-47};
    });
    assert.equal(responsive.inside,true,'The scaled slide must stay above the controls');
    await page.screenshot({path:path.join(out,'responsive-1280x720.png')});
    await page.setViewportSize({width:1920,height:1128});
    if(process.argv.includes('--pdf')) {
      await page.emulateMedia({media:'print'});
      await page.pdf({path:path.join(root,'agrupando-genomas-virais-em-bend.pdf'),width:'20in',height:'11.25in',printBackground:true,preferCSSPageSize:true});
    }
    const issues=reports.filter(r=>r.overflow.length);
    await fs.writeFile(path.join(out,'layout.json'),JSON.stringify({errors,network,navigation:'passed',responsive,reports},null,2));
    console.log(JSON.stringify({screenshots:reports.length,errors,network,navigation:'passed',responsive,issues,out},null,2));
    if(errors.length||issues.length||network.length)process.exitCode=1;
  } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1});
