// Browser orbit camera for the immutable Bend2 Core scene.
// Core emits points through its proven default camera. `unproject` exactly
// reverses that projection; WebGL then applies this interactive camera.
(() => {
  "use strict";

  const state = {yaw:0, pitch:0, zoom:1};
  const VIEW_HEIGHT=2.6, VIEW_RADIUS=12.5;
  const clamp = (value, low, high) => Math.max(low, Math.min(high, value));
  const radians = degrees => degrees * Math.PI / 180;

  function unproject(point) {
    if (!point || !point.visible) return {x:0,y:0,z:0,visible:false};
    const depth = Math.max(.01, point.depth);
    return {
      x:(point.x-640)*depth/560,
      y:7+(360-point.y)*depth/560,
      z:depth-18,
      visible:true,
    };
  }

  function pose() {
    const yaw=radians(state.yaw), pitch=radians(state.pitch), radius=VIEW_RADIUS/state.zoom;
    return {
      eye:[Math.sin(yaw)*Math.cos(pitch)*radius,VIEW_HEIGHT+Math.sin(pitch)*radius,-Math.cos(yaw)*Math.cos(pitch)*radius],
      target:[0,VIEW_HEIGHT,0], up:[0,1,0], fov:2*Math.atan(360/560),
    };
  }

  // Compatibility projection used by diagnostics and the Canvas-free tests.
  function project(point) {
    const world=unproject(point); if(!world.visible)return{x:640,y:360,depth:1,visible:false};
    const yaw=radians(state.yaw),cy=Math.cos(yaw),sy=Math.sin(yaw);
    const x=world.x*cy+world.z*sy,z=-world.x*sy+world.z*cy;
    const ry=world.y-VIEW_HEIGHT,rz=z+VIEW_RADIUS,pitch=radians(state.pitch),cp=Math.cos(pitch),sp=Math.sin(pitch);
    const y=ry*cp-rz*sp,depth=ry*sp+rz*cp;
    if(depth<=.4)return{x:640,y:360,depth,visible:false};
    return{x:640+x*560*state.zoom/depth,y:360-y*560*state.zoom/depth,depth,visible:true};
  }

  const announce=()=>window.dispatchEvent(new CustomEvent("bend-a-beet-camera"));
  function bind(){
    const canvas=document.getElementById("farm"),yaw=document.getElementById("camera-yaw"),pitch=document.getElementById("camera-pitch"),zoom=document.getElementById("camera-zoom"),reset=document.getElementById("camera-reset");
    if(!canvas||!yaw||!pitch||!zoom||!reset)return;
    const update=()=>{state.yaw=Number(yaw.value);state.pitch=Number(pitch.value);state.zoom=Number(zoom.value)/100;announce();};
    yaw.addEventListener("input",update);pitch.addEventListener("input",update);zoom.addEventListener("input",update);
    reset.addEventListener("click",()=>{yaw.value="0";pitch.value="0";zoom.value="100";update();});
    let dragging=false,lastX=0,lastY=0;
    canvas.addEventListener("pointerdown",event=>{dragging=true;lastX=event.clientX;lastY=event.clientY;canvas.setPointerCapture?.(event.pointerId);});
    canvas.addEventListener("pointermove",event=>{if(!dragging)return;state.yaw=clamp(state.yaw+(event.clientX-lastX)*.35,-80,80);state.pitch=clamp(state.pitch+(event.clientY-lastY)*.18,-25,25);lastX=event.clientX;lastY=event.clientY;yaw.value=String(Math.round(state.yaw));pitch.value=String(Math.round(state.pitch));announce();});
    const release=event=>{dragging=false;if(canvas.hasPointerCapture?.(event.pointerId))canvas.releasePointerCapture(event.pointerId);};
    canvas.addEventListener("pointerup",release);canvas.addEventListener("pointercancel",release);canvas.style.touchAction="none";
  }

  globalThis.BEND_A_BEET_CAMERA={state,unproject,project,pose,bind};
  if(document.readyState==="loading")document.addEventListener("DOMContentLoaded",bind,{once:true});else bind();
})();
