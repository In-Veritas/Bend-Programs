import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const meta = JSON.parse(await fs.readFile(path.join(root, 'deck.json'), 'utf8'));
const fonts = [];
for (const [family, base] of [['IBM Plex Sans', 'IBMPlexSans'], ['IBM Plex Mono', 'IBMPlexMono']]) {
  for (const [suffix, weight] of [['Regular', 400], ['Medium', 500], ['SemiBold', 600], ['Bold', 700]]) {
    const bytes = await fs.readFile(path.join(root, 'fonts', `${base}-${suffix}.ttf`));
    fonts.push(`@font-face{font-family:'${family}';font-style:normal;font-weight:${weight};font-display:block;src:url(data:font/ttf;base64,${bytes.toString('base64')}) format('truetype')}`);
  }
}
const reset = `
*{box-sizing:border-box}html,body{margin:0;padding:0}body{background:#0b1820;overflow:hidden}
h1,h2,h3,p,ul{margin:0}table{border-collapse:collapse}th,td{padding:15px 18px;text-align:left;vertical-align:top;border-bottom:1px solid var(--line)}th{font-weight:600}
#stage{position:absolute;inset:0;overflow:hidden}section{position:absolute;left:0;top:0;width:1920px;height:1080px;overflow:hidden;transform-origin:top left}
section[hidden]{display:none!important}section::after{content:attr(data-page)}
x-connector{display:block;position:relative;flex-shrink:0;background:currentColor}
x-connector.arrow::after{content:'';position:absolute;right:-1px;top:-6px;border-left:10px solid currentColor;border-top:7px solid transparent;border-bottom:7px solid transparent}
x-connector.arrow-d::after{content:'';position:absolute;bottom:-1px;left:-6px;border-top:10px solid currentColor;border-left:7px solid transparent;border-right:7px solid transparent}
#controls{position:fixed;left:0;right:0;bottom:0;height:48px;display:flex;align-items:center;justify-content:center;gap:14px;background:#0b1820;color:#d5e2e8;font:14px 'IBM Plex Sans',sans-serif;z-index:5}
#controls button,#controls select{border:1px solid #426071;border-radius:5px;background:#172e3d;color:inherit;padding:5px 12px;font:inherit;cursor:pointer}
#controls select{max-width:420px}#controls button:focus-visible,#controls select:focus-visible{outline:2px solid #74d3c7;outline-offset:2px}
.print-only{display:none}
@media print{@page{size:20in 11.25in;margin:0}html,body{background:white;overflow:visible;width:1920px}#stage{position:static;overflow:visible}section,section[hidden]{display:flex!important;position:relative;left:auto!important;top:auto!important;transform:none!important;margin:0;break-after:page;page-break-after:always;-webkit-print-color-adjust:exact;print-color-adjust:exact}section:last-child{break-after:auto;page-break-after:auto}#controls{display:none!important}}
`;
const style = await fs.readFile(path.join(root, 'deck.css'), 'utf8');
const fixes = await fs.readFile(path.join(root, 'refinements.css'), 'utf8').catch(() => '');
const slides = [];
const titles = [];
for (const [index, id] of meta.order.entries()) {
  let slide = await fs.readFile(path.join(root, 'slides', `${id}.html`), 'utf8');
  slide = slide.replace('<section ', `<section data-page="${index + 1}" aria-label="Slide ${index + 1}" `);
  slides.push(slide);
  titles.push(slide.match(/<h[12][^>]*>([\s\S]*?)<\/h[12]>/)?.[1].replace(/<[^>]+>/g, '') || id);
}
const script = `
const slides=[...document.querySelectorAll('#stage > section')];
const picker=document.querySelector('#slide-picker');
const titles=${JSON.stringify(titles)};
titles.forEach((title,i)=>{const o=document.createElement('option');o.value=i;o.textContent=(i+1)+' / '+slides.length+'  '+title;picker.append(o)});
let current=Math.max(0,slides.findIndex(s=>'#'+s.id===location.hash));
function size(){const pad=48;const scale=Math.min(innerWidth/1920,(innerHeight-pad)/1080);for(const s of slides){s.style.transform='scale('+scale+')';s.style.left=(innerWidth-1920*scale)/2+'px';s.style.top=(innerHeight-pad-1080*scale)/2+'px'}}
function show(i){current=Math.max(0,Math.min(slides.length-1,i));slides.forEach((s,j)=>{s.hidden=j!==current;s.setAttribute('aria-hidden',String(j!==current))});picker.value=current;document.querySelector('#previous').disabled=current===0;document.querySelector('#next').disabled=current===slides.length-1;history.replaceState(null,'','#'+slides[current].id);size()}
window.showSlide=show;window.currentSlide=()=>current;
document.querySelector('#previous').onclick=()=>show(current-1);document.querySelector('#next').onclick=()=>show(current+1);picker.onchange=()=>show(Number(picker.value));document.querySelector('#fullscreen').onclick=()=>document.fullscreenElement?document.exitFullscreen():document.documentElement.requestFullscreen();
document.addEventListener('keydown',e=>{if(e.target.tagName==='SELECT')return;if(['ArrowRight','PageDown',' '].includes(e.key)){e.preventDefault();show(current+1)}else if(['ArrowLeft','PageUp'].includes(e.key)){e.preventDefault();show(current-1)}else if(e.key==='Home')show(0);else if(e.key==='End')show(slides.length-1);else if(e.key.toLowerCase()==='f')document.querySelector('#fullscreen').click()});
window.addEventListener('resize',size);window.addEventListener('hashchange',()=>{const i=slides.findIndex(s=>'#'+s.id===location.hash);if(i>=0)show(i)});show(current);
`;
const html = `<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><meta name="description" content="Algoritmos de agrupamento viral, tipos e provas em Bend, e comparação com Vclust."><title>${meta.title}</title><style>${fonts.join('\n')}\n${reset}\n${style}\n${fixes}</style></head><body><main id="stage">${slides.join('\n')}</main><nav id="controls" aria-label="Navegação da apresentação"><button id="previous" aria-label="Slide anterior">←</button><select id="slide-picker" aria-label="Escolher slide"></select><button id="next" aria-label="Próximo slide">→</button><button id="fullscreen">Tela cheia (F)</button></nav><script>${script}</script></body></html>`;
await fs.writeFile(path.join(root, 'index.html'), html);
console.log(`Built ${slides.length} slides: ${path.join(root, 'index.html')}`);
