/* Bend Engine shared WebGL2 presentation boundary.
 *
 * Bend supplies immutable scene/state values. This renderer turns those values
 * into arbitrary indexed meshes, materials, cameras, and presentation-only
 * interpolation. Complex meshes are generated once and uploaded lazily; callers
 * can also register their own meshes instead of reducing models to primitives.
 */
(() => {
  "use strict";

  const TAU = Math.PI * 2;
  const clamp = (value, low = 0, high = 1) => Math.max(low, Math.min(high, value));
  const add = (left, right) => left.map((value, index) => value + right[index]);
  const sub = (left, right) => left.map((value, index) => value - right[index]);
  const dot = (left, right) => left[0] * right[0] + left[1] * right[1] + left[2] * right[2];
  const cross = (left, right) => [left[1] * right[2] - left[2] * right[1], left[2] * right[0] - left[0] * right[2], left[0] * right[1] - left[1] * right[0]];
  const norm = vector => { const length = Math.hypot(...vector) || 1; return vector.map(value => value / length); };

  const multiply4 = (left, right) => {
    const out = new Float32Array(16);
    for (let column = 0; column < 4; column++) for (let row = 0; row < 4; row++) {
      out[column * 4 + row] = left[row] * right[column * 4] + left[4 + row] * right[column * 4 + 1] + left[8 + row] * right[column * 4 + 2] + left[12 + row] * right[column * 4 + 3];
    }
    return out;
  };
  const perspective = (fov, aspect, near, far) => { const focus = 1 / Math.tan(fov / 2), depth = 1 / (near - far); return new Float32Array([focus / aspect, 0, 0, 0, 0, focus, 0, 0, 0, 0, (far + near) * depth, -1, 0, 0, 2 * far * near * depth, 0]); };
  const lookAt = (eye, target, up) => { const z = norm(sub(eye, target)), x = norm(cross(up, z)), y = cross(z, x); return new Float32Array([x[0], y[0], z[0], 0, x[1], y[1], z[1], 0, x[2], y[2], z[2], 0, -dot(x, eye), -dot(y, eye), -dot(z, eye), 1]); };
  const modelMatrix = (position, scale, rotation = [0, 0, 0]) => {
    const [cx, sx] = [Math.cos(rotation[0]), Math.sin(rotation[0])], [cy, sy] = [Math.cos(rotation[1]), Math.sin(rotation[1])], [cz, sz] = [Math.cos(rotation[2]), Math.sin(rotation[2])];
    return new Float32Array([cy * cz * scale[0], (sx * sy * cz + cx * sz) * scale[0], (-cx * sy * cz + sx * sz) * scale[0], 0, -cy * sz * scale[1], (-sx * sy * sz + cx * cz) * scale[1], (cx * sy * sz + sx * cz) * scale[1], 0, sy * scale[2], -sx * cy * scale[2], cx * cy * scale[2], 0, position[0], position[1], position[2], 1]);
  };
  // modelMatrix is R*S, so its inverse-transpose is R*(1/S).
  const normalMatrix = (model, scale) => { const safe = scale.map(value => Math.abs(value) < 1e-7 ? 1e-7 : value); return new Float32Array([model[0] / safe[0] ** 2, model[1] / safe[0] ** 2, model[2] / safe[0] ** 2, model[4] / safe[1] ** 2, model[5] / safe[1] ** 2, model[6] / safe[1] ** 2, model[8] / safe[2] ** 2, model[9] / safe[2] ** 2, model[10] / safe[2] ** 2]); };

  const color = value => {
    if (Array.isArray(value)) return value.map(channel => channel > 1 ? channel / 255 : channel);
    const text = String(value || "#ffffff");
    if (text.startsWith("hsl")) {
      const parts = text.match(/[\d.]+/g)?.map(Number) || [0, 0, 100], hue = ((parts[0] % 360) + 360) % 360 / 60, saturation = parts[1] / 100, light = parts[2] / 100;
      const chroma = (1 - Math.abs(2 * light - 1)) * saturation, x = chroma * (1 - Math.abs(hue % 2 - 1)), bands = [[chroma, x, 0], [x, chroma, 0], [0, chroma, x], [0, x, chroma], [x, 0, chroma], [chroma, 0, x]], offset = light - chroma / 2;
      return bands[Math.floor(hue) % 6].map(channel => channel + offset);
    }
    const expanded = text.length === 4 ? `#${text[1]}${text[1]}${text[2]}${text[2]}${text[3]}${text[3]}` : text, number = parseInt(expanded.replace("#", ""), 16);
    return [(number >> 16 & 255) / 255, (number >> 8 & 255) / 255, (number & 255) / 255];
  };

  function calculateNormals(positions, indices) {
    const normals = new Float32Array(positions.length);
    for (let offset = 0; offset < indices.length; offset += 3) {
      const ia = indices[offset] * 3, ib = indices[offset + 1] * 3, ic = indices[offset + 2] * 3;
      const a = positions.slice(ia, ia + 3), b = positions.slice(ib, ib + 3), c = positions.slice(ic, ic + 3), face = cross(sub(b, a), sub(c, a));
      for (const index of [ia, ib, ic]) { normals[index] += face[0]; normals[index + 1] += face[1]; normals[index + 2] += face[2]; }
    }
    for (let index = 0; index < normals.length; index += 3) { const value = norm([normals[index], normals[index + 1], normals[index + 2]]); normals[index] = value[0]; normals[index + 1] = value[1]; normals[index + 2] = value[2]; }
    return normals;
  }
  function makeMesh({ positions, normals, uvs, indices }) {
    const p = positions instanceof Float32Array ? positions : new Float32Array(positions), i = indices instanceof Uint32Array ? indices : new Uint32Array(indices);
    const n = normals?.length ? (normals instanceof Float32Array ? normals : new Float32Array(normals)) : calculateNormals(p, i), uv = uvs?.length ? (uvs instanceof Float32Array ? uvs : new Float32Array(uvs)) : new Float32Array(p.length / 3 * 2);
    if (p.length % 3 || n.length !== p.length || uv.length !== p.length / 3 * 2 || i.some(index => index >= p.length / 3)) throw new Error("Bend Engine mesh has inconsistent positions, normals, UVs, or indices");
    return Object.freeze({ positions: p, normals: n, uvs: uv, indices: i });
  }

  function uvSphere(latitude = 28, longitude = 44, radiusAt = () => 1) {
    const positions = [], normals = [], uvs = [], indices = [];
    for (let y = 0; y <= latitude; y++) { const v = y / latitude, phi = v * Math.PI; for (let x = 0; x <= longitude; x++) { const u = x / longitude, theta = u * TAU, sine = Math.sin(phi), direction = [Math.cos(theta) * sine, Math.cos(phi), Math.sin(theta) * sine], radius = radiusAt(u, v); positions.push(...direction.map(value => value * radius)); normals.push(...direction); uvs.push(u, v); } }
    for (let y = 0; y < latitude; y++) for (let x = 0; x < longitude; x++) { const a = y * (longitude + 1) + x, b = a + longitude + 1; indices.push(a, b, a + 1, b, b + 1, a + 1); }
    return makeMesh({ positions, normals, uvs, indices });
  }
  function box() {
    const positions = [], normals = [], uvs = [], indices = [], faces = [[[0, 0, 1], [-1, -1, 1], [1, -1, 1], [1, 1, 1], [-1, 1, 1]], [[0, 0, -1], [1, -1, -1], [-1, -1, -1], [-1, 1, -1], [1, 1, -1]], [[1, 0, 0], [1, -1, 1], [1, -1, -1], [1, 1, -1], [1, 1, 1]], [[-1, 0, 0], [-1, -1, -1], [-1, -1, 1], [-1, 1, 1], [-1, 1, -1]], [[0, 1, 0], [-1, 1, 1], [1, 1, 1], [1, 1, -1], [-1, 1, -1]], [[0, -1, 0], [-1, -1, -1], [1, -1, -1], [1, -1, 1], [-1, -1, 1]]];
    for (const face of faces) { const offset = positions.length / 3; for (let index = 1; index < 5; index++) { positions.push(...face[index]); normals.push(...face[0]); uvs.push(index === 1 || index === 4 ? 0 : 1, index < 3 ? 0 : 1); } indices.push(offset, offset + 1, offset + 2, offset, offset + 2, offset + 3); }
    return makeMesh({ positions, normals, uvs, indices });
  }
  function cylinder(segments = 40, topRadius = 1) {
    const positions = [], normals = [], uvs = [], indices = [];
    for (let y = 0; y < 2; y++) for (let index = 0; index <= segments; index++) { const angle = index / segments * TAU, radius = y ? topRadius : 1; positions.push(Math.cos(angle) * radius, y * 2 - 1, Math.sin(angle) * radius); normals.push(Math.cos(angle), topRadius === 1 ? 0 : .45, Math.sin(angle)); uvs.push(index / segments, y); }
    for (let index = 0; index < segments; index++) { const a = index, b = a + segments + 1; indices.push(a, b, a + 1, b, b + 1, a + 1); }
    for (const y of [0, 1]) { const center = positions.length / 3; positions.push(0, y * 2 - 1, 0); normals.push(0, y ? 1 : -1, 0); uvs.push(.5, .5); for (let index = 0; index < segments; index++) { const a = y * (segments + 1) + index, b = a + 1; indices.push(center, y ? b : a, y ? a : b); } }
    return makeMesh({ positions, normals, uvs, indices });
  }
  function plane(divisions = 96) {
    const positions = [], normals = [], uvs = [], indices = [];
    for (let z = 0; z <= divisions; z++) for (let x = 0; x <= divisions; x++) { positions.push(x / divisions * 2 - 1, 0, z / divisions * 2 - 1); normals.push(0, 1, 0); uvs.push(x / divisions, z / divisions); }
    for (let z = 0; z < divisions; z++) for (let x = 0; x < divisions; x++) { const a = z * (divisions + 1) + x, b = a + divisions + 1; indices.push(a, b, a + 1, b, b + 1, a + 1); }
    return makeMesh({ positions, normals, uvs, indices });
  }
  function lathe(profile, segments = 48) {
    const positions = [], uvs = [], indices = [];
    for (let row = 0; row < profile.length; row++) { const [y, radius] = profile[row]; for (let column = 0; column <= segments; column++) { const u = column / segments, angle = u * TAU; positions.push(Math.cos(angle) * radius, y, Math.sin(angle) * radius); uvs.push(u, row / (profile.length - 1)); } }
    for (let row = 0; row < profile.length - 1; row++) for (let column = 0; column < segments; column++) { const a = row * (segments + 1) + column, b = a + segments + 1; indices.push(a, b, a + 1, b, b + 1, a + 1); }
    return makeMesh({ positions, uvs, indices });
  }
  function torus(major = .7, minor = .25, rings = 52, sides = 20) {
    const positions = [], normals = [], uvs = [], indices = [];
    for (let ring = 0; ring <= rings; ring++) for (let side = 0; side <= sides; side++) { const u = ring / rings, v = side / sides, a = u * TAU, b = v * TAU, normal = [Math.cos(a) * Math.cos(b), Math.sin(b), Math.sin(a) * Math.cos(b)]; positions.push(Math.cos(a) * (major + minor * Math.cos(b)), minor * Math.sin(b), Math.sin(a) * (major + minor * Math.cos(b))); normals.push(...normal); uvs.push(u, v); }
    for (let ring = 0; ring < rings; ring++) for (let side = 0; side < sides; side++) { const a = ring * (sides + 1) + side, b = a + sides + 1; indices.push(a, b, a + 1, b, b + 1, a + 1); }
    return makeMesh({ positions, normals, uvs, indices });
  }
  function superellipsoid(latitude = 30, longitude = 44, exponent = .34) {
    const power = (value, amount) => Math.sign(value) * Math.pow(Math.abs(value), amount), positions = [], uvs = [], indices = [];
    for (let y = 0; y <= latitude; y++) for (let x = 0; x <= longitude; x++) { const v = y / latitude, u = x / longitude, phi = (v - .5) * Math.PI, theta = u * TAU, cp = Math.cos(phi); positions.push(power(cp, exponent) * power(Math.cos(theta), exponent), power(Math.sin(phi), exponent), power(cp, exponent) * power(Math.sin(theta), exponent)); uvs.push(u, v); }
    for (let y = 0; y < latitude; y++) for (let x = 0; x < longitude; x++) { const a = y * (longitude + 1) + x, b = a + longitude + 1; indices.push(a, b, a + 1, b, b + 1, a + 1); }
    return makeMesh({ positions, uvs, indices });
  }
  function sweep(points, radii, sides = 14) {
    const positions = [], normals = [], uvs = [], indices = []; let previousNormal = [0, 0, 1];
    for (let row = 0; row < points.length; row++) { const tangent = norm(sub(points[Math.min(points.length - 1, row + 1)], points[Math.max(0, row - 1)])); let axis = norm(cross(tangent, previousNormal)); if (Math.hypot(...axis) < .1) axis = norm(cross(tangent, [0, 1, 0])); const normal = norm(cross(axis, tangent)); previousNormal = normal; for (let side = 0; side <= sides; side++) { const angle = side / sides * TAU, radial = add(normal.map(value => value * Math.cos(angle)), axis.map(value => value * Math.sin(angle))); positions.push(...add(points[row], radial.map(value => value * radii[row]))); normals.push(...radial); uvs.push(side / sides, row / (points.length - 1)); } }
    for (let row = 0; row < points.length - 1; row++) for (let side = 0; side < sides; side++) { const a = row * (sides + 1) + side, b = a + sides + 1; indices.push(a, b, a + 1, b, b + 1, a + 1); }
    return makeMesh({ positions, normals, uvs, indices });
  }
  function organicBody(rings = 34, sides = 28, style = "fish") {
    const positions = [], uvs = [], indices = [];
    for (let ring = 0; ring <= rings; ring++) { const u = ring / rings, x = u * 2 - 1; let radius = Math.pow(Math.max(0, Math.sin(u * Math.PI)), style === "whale" ? .42 : .58); if (style === "bird") radius *= .92 + .18 * (1 - u); if (style === "whale") radius *= 1 + .22 * Math.exp(-Math.pow((u - .66) * 5, 2)); for (let side = 0; side <= sides; side++) { const v = side / sides, angle = v * TAU, belly = style === "bird" ? -.12 * radius : -.05 * Math.sin(u * Math.PI), height = radius * (style === "whale" ? .72 : style === "bird" ? .9 : .66); positions.push(x, Math.cos(angle) * height + belly, Math.sin(angle) * radius); uvs.push(u, v); } }
    for (let ring = 0; ring < rings; ring++) for (let side = 0; side < sides; side++) { const a = ring * (sides + 1) + side, b = a + sides + 1; indices.push(a, b, a + 1, b, b + 1, a + 1); }
    return makeMesh({ positions, uvs, indices });
  }
  function organicSheet(kind = "leaf", columns = 18, rows = 8, mirrored = false) {
    const positions = [], uvs = [], indices = [];
    for (let column = 0; column <= columns; column++) for (let row = 0; row <= rows; row++) { const u = column / columns, v = row / rows * 2 - 1; if (kind === "wing") { const span = u * 1.65, chord = (.48 * (1 - u) + .08) * v; positions.push(-.16 - u * .58 + chord, Math.sin(u * Math.PI) * .09 - Math.abs(v) * .025, (mirrored ? -1 : 1) * span); } else { const z = u * 2 - 1, width = Math.sin(u * Math.PI) * (.58 + .06 * Math.sin(u * 11 * Math.PI)); positions.push(v * width, Math.sin(u * Math.PI) * .08 * (1 - v * v), z); } uvs.push(u, (v + 1) / 2); }
    const stride = rows + 1; for (let column = 0; column < columns; column++) for (let row = 0; row < rows; row++) { const a = column * stride + row, b = a + stride; if (mirrored) indices.push(a, a + 1, b, b, a + 1, b + 1); else indices.push(a, b, a + 1, b, b + 1, a + 1); }
    return makeMesh({ positions, uvs, indices });
  }
  function extrudedFin(outline, thickness = .065) {
    const positions = [], uvs = [], indices = [], count = outline.length;
    for (const x of [-thickness, thickness]) for (const [y, z] of outline) { positions.push(x, y, z); uvs.push((z + 1) / 2, (y + 1) / 2); }
    for (let index = 1; index < count - 1; index++) indices.push(0, index + 1, index, count, count + index, count + index + 1);
    for (let index = 0; index < count; index++) { const next = (index + 1) % count; indices.push(index, next, count + index, next, count + next, count + index); }
    return makeMesh({ positions, uvs, indices });
  }
  function crystal(sides = 7) {
    const positions = [[0, -1.2, 0], [0, 1.35, 0]], uvs = [[.5, 0], [.5, 1]], indices = [];
    for (const y of [-.62, .72]) for (let index = 0; index < sides; index++) { const angle = index / sides * TAU, radius = y < 0 ? .72 : .58; positions.push([Math.cos(angle) * radius, y, Math.sin(angle) * radius]); uvs.push([index / sides, y < 0 ? .25 : .75]); }
    for (let index = 0; index < sides; index++) { const next = (index + 1) % sides, lower = 2 + index, lowerNext = 2 + next, upper = 2 + sides + index, upperNext = 2 + sides + next; indices.push(0, lowerNext, lower, 1, upper, upperNext, lower, lowerNext, upper, lowerNext, upperNext, upper); }
    return makeMesh({ positions: positions.flat(), uvs: uvs.flat(), indices });
  }
  function island(sides = 18) {
    const positions = [[0, .42, 0], [0, -1.5, 0]], uvs = [[.5, .5], [.5, .5]], indices = [];
    for (let ring = 0; ring < 2; ring++) for (let index = 0; index < sides; index++) { const angle = index / sides * TAU, noise = 1 + .1 * Math.sin(index * 4.7) + .055 * Math.cos(index * 7.3), radius = noise * (ring ? .72 : 1); positions.push([Math.cos(angle) * radius, ring ? .06 + .08 * Math.sin(index * 2.4) : .42 + .035 * Math.sin(index * 3.1), Math.sin(angle) * radius]); uvs.push([Math.cos(angle) * .5 + .5, Math.sin(angle) * .5 + .5]); }
    for (let index = 0; index < sides; index++) { const next = (index + 1) % sides, top = 2 + index, topNext = 2 + next, lower = 2 + sides + index, lowerNext = 2 + sides + next; indices.push(0, topNext, top, top, topNext, lower, topNext, lowerNext, lower, 1, lower, lowerNext); }
    return makeMesh({ positions: positions.flat(), uvs: uvs.flat(), indices });
  }
  function arc(segments = 32, sides = 12) {
    const positions = [], normals = [], uvs = [], indices = [], major = .72, minor = .18;
    for (let segment = 0; segment <= segments; segment++) for (let side = 0; side <= sides; side++) { const u = segment / segments, v = side / sides, a = u * Math.PI, b = v * TAU, center = [Math.cos(a) * major, Math.sin(a) * major, 0], radial = [Math.cos(a) * Math.cos(b), Math.sin(a) * Math.cos(b), Math.sin(b)]; positions.push(...add(center, radial.map(value => value * minor))); normals.push(...radial); uvs.push(u, v); }
    for (let segment = 0; segment < segments; segment++) for (let side = 0; side < sides; side++) { const a = segment * (sides + 1) + side, b = a + sides + 1; indices.push(a, b, a + 1, b, b + 1, a + 1); }
    return makeMesh({ positions, normals, uvs, indices });
  }
  function star(points = 7) { const outline = []; for (let index = 0; index < points * 2; index++) { const angle = index / (points * 2) * TAU, radius = index % 2 ? .45 : 1; outline.push([Math.sin(angle) * radius, Math.cos(angle) * radius]); } return extrudedFin(outline, .12); }
  function manta(columns = 28, rows = 18) {
    const positions = [], uvs = [], indices = [];
    for (let column = 0; column <= columns; column++) for (let row = 0; row <= rows; row++) { const u = column / columns, v = row / rows * 2 - 1, x = u * 2 - 1, width = (1 - .58 * Math.abs(x)) * (1 - .12 * x), z = v * width, y = .18 * Math.cos(v * Math.PI / 2) - .13 * v * v + .07 * Math.sin(u * Math.PI); positions.push(x, y, z); uvs.push(u, (v + 1) / 2); }
    const stride = rows + 1; for (let column = 0; column < columns; column++) for (let row = 0; row < rows; row++) { const a = column * stride + row, b = a + stride; indices.push(a, b, a + 1, b, b + 1, a + 1); }
    return makeMesh({ positions, uvs, indices });
  }

  const capsuleProfile = [];
  for (let index = 0; index <= 8; index++) { const angle = -Math.PI / 2 + index / 8 * Math.PI / 2; capsuleProfile.push([-.55 + Math.sin(angle) * .45, Math.cos(angle) * .45]); }
  capsuleProfile.push([.55, .45]);
  for (let index = 1; index <= 8; index++) { const angle = index / 8 * Math.PI / 2; capsuleProfile.push([.55 + Math.sin(angle) * .45, Math.cos(angle) * .45]); }
  const branchPoints = Array.from({ length: 13 }, (_, index) => { const t = index / 12; return [Math.sin(t * Math.PI * 1.3) * .14, t * 2 - 1, Math.sin(t * Math.PI * 2.1) * .07]; });
  const ropePoints = Array.from({ length: 18 }, (_, index) => { const t = index / 17; return [t * 2 - 1, Math.sin(t * Math.PI) * -.18, Math.sin(t * Math.PI * 2) * .08]; });
  const eelPoints = Array.from({ length: 30 }, (_, index) => { const t = index / 29; return [t * 2 - 1, Math.sin(t * TAU) * .09, Math.sin(t * TAU * 1.35) * .23 * Math.sin(t * Math.PI)]; });
  const geometry = {
    sphere: uvSphere(), rock: uvSphere(24, 34, (u, v) => 1 + .11 * Math.sin(u * 31 + v * 17) + .055 * Math.cos(u * 53 - v * 29)), cloud: uvSphere(22, 34, (u, v) => 1 + .16 * Math.sin(u * 18) * Math.sin(v * 13) + .08 * Math.cos(u * 37 + v * 11)),
    box: box(), bevel: superellipsoid(), cylinder: cylinder(), cone: cylinder(40, 0), water: plane(), disc: cylinder(56, 1), capsule: lathe(capsuleProfile), torus: torus(),
    branch: sweep(branchPoints, branchPoints.map((_, index) => .28 - index / 12 * .17)), rope: sweep(ropePoints, ropePoints.map(() => .055), 12), eel: sweep(eelPoints, eelPoints.map((_, index) => .24 * Math.pow(Math.sin(index / 29 * Math.PI), .45) + .015), 18),
    leaf: organicSheet("leaf"), wing: organicSheet("wing"), wingMirror: organicSheet("wing", 18, 8, true), fishBody: organicBody(), birdBody: organicBody(32, 26, "bird"), whaleBody: organicBody(38, 32, "whale"),
    tailFin: extrudedFin([[0, 0], [.75, .92], [.34, 0], [.75, -.92], [0, 0]], .055), fin: extrudedFin([[-.12, 0], [.9, .1], [.05, .72]], .045), beak: crystal(4), crystal: crystal(), shard: crystal(5), island: island(), arch: arc(), star: star(), manta: manta(),
  };
  function registerMesh(name, definition) { if (!/^[A-Za-z][A-Za-z0-9_-]*$/.test(name)) throw new Error(`invalid Bend Engine mesh name ${name}`); geometry[name] = makeMesh(definition); return name; }
  const meshStats = () => Object.fromEntries(Object.entries(geometry).map(([name, value]) => [name, { vertices: value.positions.length / 3, triangles: value.indices.length / 3 }]));

  const vertexShader = `#version 300 es
    precision highp float; layout(location=0) in vec3 aPosition; layout(location=1) in vec3 aNormal; layout(location=2) in vec2 aUV;
    uniform mat4 uModel,uViewProjection; uniform mat3 uNormalMatrix; uniform float uTime,uWater,uWave,uSoft,uWind,uPulse,uTwist,uPhase;
    out vec3 vPosition,vNormal; out vec2 vUV; out float vRipple,vHeight;
    void main(){vec3 p=aPosition;float h=clamp(p.y*.5+.5,0.,1.);float ripple=sin(p.x*7.+p.z*5.+uTime*1.7)+.55*sin(p.x*13.-p.z*9.-uTime*2.3);if(uWater>.5)p.y+=ripple*uWave*.035;if(uSoft>0.){float q=sin(uTime*5.+p.y*4.+p.x*2.+uPhase);p.xz*=1.+q*uSoft*.08;p.y*=1.-q*uSoft*.05;}if(uWind!=0.){float gust=sin(uTime*1.9+p.y*2.7+uPhase)+.35*sin(uTime*4.1+p.z*5.);p.x+=gust*uWind*h*h*.13;p.z+=cos(uTime*1.3+p.y*3.1+uPhase)*uWind*h*.055;}if(uPulse!=0.)p*=1.+sin(uTime*3.2+uPhase)*uPulse*.055;if(uTwist!=0.){float a=p.y*uTwist+sin(uTime*2.+uPhase)*uTwist*.1;mat2 turn=mat2(cos(a),-sin(a),sin(a),cos(a));p.xz=turn*p.xz;}vec4 world=uModel*vec4(p,1.);vPosition=world.xyz;vNormal=normalize(uNormalMatrix*aNormal);vUV=aUV;vRipple=ripple;vHeight=h;gl_Position=uViewProjection*world;}`;
  const fragmentShader = `#version 300 es
    precision highp float;in vec3 vPosition,vNormal;in vec2 vUV;in float vRipple,vHeight;out vec4 outColor;
    uniform vec3 uColor,uColor2,uCamera,uSunDirection,uSunColor,uPointPosition,uPointColor,uFogColor;uniform float uMetallic,uRoughness,uAlpha,uTexture,uWater,uFur,uTime,uFog,uCaustic,uEmissive,uRim,uSubsurface;
    float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}float pattern(){if(uTexture<.5)return 0.;if(uTexture<1.5)return mod(floor(vUV.x*12.)+floor(vUV.y*12.),2.);if(uTexture<2.5)return smoothstep(.35,.65,sin(vUV.x*40.+sin(vUV.y*21.))*.5+.5);if(uTexture<3.5)return hash(floor(vUV*42.));if(uTexture<4.5){vec2 q=fract(vec2(vUV.x*22.+mod(floor(vUV.y*18.),2.)*.5,vUV.y*18.))-.5;return smoothstep(.48,.22,length(q));}if(uTexture<5.5)return smoothstep(.22,.72,.5+.5*sin(vUV.x*72.+sin(vUV.y*17.)*2.));if(uTexture<6.5)return smoothstep(.72,.9,hash(floor(vUV*64.)));if(uTexture<7.5){vec2 q=abs(fract(vUV*vec2(9.,14.))-.5);return smoothstep(.44,.32,max(q.x,q.y));}if(uTexture<8.5)return .5+.5*sin((vUV.x+vUV.y)*90.+sin(vUV.y*31.)*2.);vec2 cell=floor(vUV*28.);return hash(cell)*.65+hash(cell+vec2(7.,13.))*.35;}
    void main(){vec3 n=normalize(vNormal);if(uWater>.5)n=normalize(n+vec3(dFdx(vRipple),.35,dFdy(vRipple))*.22);vec3 view=normalize(uCamera-vPosition),sun=normalize(-uSunDirection),pv=uPointPosition-vPosition;float pd=max(length(pv),.001);vec3 pointLight=pv/pd;float diffuse=max(dot(n,sun),0.),pointDiffuse=max(dot(n,pointLight),0.)/(1.+pd*pd*.018),rough=max(.035,uRoughness);float spec=pow(max(dot(reflect(-sun,n),view),0.),mix(120.,7.,rough)),pointSpec=pow(max(dot(reflect(-pointLight,n),view),0.),mix(90.,5.,rough)),fresnel=pow(1.-max(dot(n,view),0.),5.),pat=pattern();vec3 base=mix(uColor,uColor2,pat*.72),sky=mix(vec3(.035,.09,.16),vec3(.4,.75,.95),clamp(reflect(-view,n).y*.5+.5,0.,1.)),hemi=mix(vec3(.055,.065,.075),vec3(.31,.42,.48),n.y*.5+.5);float back=pow(max(dot(-n,sun),0.),1.5)*uSubsurface;vec3 lit=base*(hemi+diffuse*.82*uSunColor+pointDiffuse*uPointColor*.88);lit+=(spec+pointSpec*.65)*mix(vec3(1.),uSunColor,.2);lit+=base*uSunColor*back*.42;lit=mix(lit,sky,fresnel*(.2+uMetallic*.64));lit+=base*uEmissive*(1.+.12*sin(uTime*3.+vUV.y*17.));lit+=mix(uColor2,vec3(1.),.55)*pow(1.-max(dot(n,view),0.),2.5)*uRim;if(uWater>.5){float ca=.78+.22*sin((vPosition.x+vPosition.z)*8.-uTime*2.);lit=mix(vec3(.015,.15,.23),vec3(.05,.55,.68),clamp(n.y*.65+.35,0.,1.));lit+=vec3(.15,.8,.9)*ca*uCaustic*.32;lit=mix(lit,sky,.25+fresnel*.55);}if(uFur>.5)lit*=.8+.2*hash(vUV*210.);float fog=1.-exp(-length(uCamera-vPosition)*uFog);lit=mix(lit,uFogColor,clamp(fog,0.,.86));outColor=vec4(pow(max(lit,0.),vec3(.84)),uAlpha);}`;

  const compileShader = (gl, type, source) => { const shader = gl.createShader(type); gl.shaderSource(shader, source); gl.compileShader(shader); if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(shader)); return shader; };
  const createProgram = gl => { const program = gl.createProgram(); gl.attachShader(program, compileShader(gl, gl.VERTEX_SHADER, vertexShader)); gl.attachShader(program, compileShader(gl, gl.FRAGMENT_SHADER, fragmentShader)); gl.linkProgram(program); if (!gl.getProgramParameter(program, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(program)); return program; };
  function upload(gl, source) { const vao = gl.createVertexArray(); gl.bindVertexArray(vao); for (const [index, data, size] of [[0, source.positions, 3], [1, source.normals, 3], [2, source.uvs, 2]]) { const buffer = gl.createBuffer(); gl.bindBuffer(gl.ARRAY_BUFFER, buffer); gl.bufferData(gl.ARRAY_BUFFER, data, gl.STATIC_DRAW); gl.enableVertexAttribArray(index); gl.vertexAttribPointer(index, size, gl.FLOAT, false, 0, 0); } const indexBuffer = gl.createBuffer(); gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, indexBuffer); gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, source.indices, gl.STATIC_DRAW); return { vao, count: source.indices.length, source }; }

  function create(canvas) {
    const gl = canvas.getContext("webgl2", { alpha: false, antialias: true, premultipliedAlpha: false }); if (!gl) throw new Error("WebGL2 is required");
    const program = createProgram(gl), namedGpu = new Map(), customGpu = new WeakMap(), normalized = new WeakMap(), uniform = name => gl.getUniformLocation(program, name);
    const uniforms = Object.fromEntries(["uModel", "uViewProjection", "uNormalMatrix", "uTime", "uWater", "uWave", "uSoft", "uWind", "uPulse", "uTwist", "uPhase", "uColor", "uColor2", "uCamera", "uSunDirection", "uSunColor", "uPointPosition", "uPointColor", "uFogColor", "uMetallic", "uRoughness", "uAlpha", "uTexture", "uFur", "uFog", "uCaustic", "uEmissive", "uRim", "uSubsurface"].map(name => [name, uniform(name)]));
    gl.enable(gl.DEPTH_TEST); gl.enable(gl.CULL_FACE); gl.enable(gl.BLEND); gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    function gpuFor(object) { if (object.mesh) { let source = object.mesh; if (!(source.positions instanceof Float32Array && source.indices instanceof Uint32Array)) { if (!normalized.has(source)) normalized.set(source, makeMesh(source)); source = normalized.get(source); } if (!customGpu.has(source)) customGpu.set(source, upload(gl, source)); return customGpu.get(source); } const name = geometry[object.kind] ? object.kind : "sphere", source = geometry[name], old = namedGpu.get(name); if (!old || old.source !== source) namedGpu.set(name, upload(gl, source)); return namedGpu.get(name); }
    function drawObject(object, context) {
      const gpu = gpuFor(object), scale = object.scale || [1, 1, 1], model = modelMatrix(object.pos || [0, 0, 0], scale, object.rot || [0, 0, 0]);
      gl.bindVertexArray(gpu.vao); gl.uniformMatrix4fv(uniforms.uModel, false, model); gl.uniformMatrix3fv(uniforms.uNormalMatrix, false, normalMatrix(model, scale)); gl.uniform1f(uniforms.uWater, object.kind === "water" ? 1 : 0); gl.uniform1f(uniforms.uWave, object.wave || 0); gl.uniform1f(uniforms.uSoft, object.soft || 0); gl.uniform1f(uniforms.uWind, object.wind || 0); gl.uniform1f(uniforms.uPulse, object.pulse || 0); gl.uniform1f(uniforms.uTwist, object.twist || 0); gl.uniform1f(uniforms.uPhase, object.phase || 0);
      gl.uniform3fv(uniforms.uColor, color(object.color || "#ffffff")); gl.uniform3fv(uniforms.uColor2, color(object.color2 || object.color || "#ffffff")); gl.uniform1f(uniforms.uMetallic, object.metallic || 0); gl.uniform1f(uniforms.uRoughness, object.roughness ?? .45); gl.uniform1f(uniforms.uAlpha, object.alpha ?? 1); gl.uniform1f(uniforms.uTexture, object.texture || 0); gl.uniform1f(uniforms.uFur, object.fur || 0); gl.uniform1f(uniforms.uCaustic, object.caustic ?? context.caustic ?? .5); gl.uniform1f(uniforms.uEmissive, object.emissive || 0); gl.uniform1f(uniforms.uRim, object.rim || 0); gl.uniform1f(uniforms.uSubsurface, object.subsurface || 0);
      const transparent = (object.alpha ?? 1) < 1, doubleSided = transparent || object.doubleSided; if (transparent) gl.depthMask(false); if (doubleSided) gl.disable(gl.CULL_FACE); gl.drawElements(gl.TRIANGLES, gpu.count, gl.UNSIGNED_INT, 0); gl.depthMask(true); gl.enable(gl.CULL_FACE); return gpu.count / 3;
    }
    function render(scene) {
      const pixelRatio = Math.min(globalThis.devicePixelRatio || 1, 2), width = Math.max(2, Math.floor(canvas.clientWidth * pixelRatio)), height = Math.max(2, Math.floor(canvas.clientHeight * pixelRatio)); if (canvas.width !== width || canvas.height !== height) { canvas.width = width; canvas.height = height; }
      gl.viewport(0, 0, width, height); const background = color(scene.background || "#8ccde0"); gl.clearColor(...background, 1); gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT); gl.useProgram(program); const camera = scene.camera || { eye: [8, 6, 12], target: [0, 2, 0], up: [0, 1, 0], fov: 48 }, viewProjection = multiply4(perspective((camera.fov || 48) * Math.PI / 180, width / height, .03, 500), lookAt(camera.eye, camera.target, camera.up || [0, 1, 0]));
      gl.uniformMatrix4fv(uniforms.uViewProjection, false, viewProjection); gl.uniform1f(uniforms.uTime, scene.time || 0); gl.uniform3fv(uniforms.uCamera, camera.eye); gl.uniform3fv(uniforms.uSunDirection, norm(scene.sun?.direction || [-.5, -1, -.35])); gl.uniform3fv(uniforms.uSunColor, color(scene.sun?.color || "#fff1d0")); gl.uniform3fv(uniforms.uPointPosition, scene.point?.position || [2, 7, 3]); gl.uniform3fv(uniforms.uPointColor, color(scene.point?.color || "#80dcff")); gl.uniform3fv(uniforms.uFogColor, color(scene.fog?.color || scene.background || "#8ccde0")); gl.uniform1f(uniforms.uFog, scene.fog?.density ?? .018);
      const objects = scene.objects || [], opaque = objects.filter(object => (object.alpha ?? 1) >= 1 && object.kind !== "water"), transparent = objects.filter(object => (object.alpha ?? 1) < 1 || object.kind === "water").sort((left, right) => Math.hypot(...sub(right.pos || [0, 0, 0], camera.eye)) - Math.hypot(...sub(left.pos || [0, 0, 0], camera.eye))); let triangles = 0; for (const object of opaque) triangles += drawObject(object, scene); for (const object of transparent) triangles += drawObject(object, scene); return { triangles, objects: objects.length };
    }
    return { gl, render, registerMesh };
  }

  const part = (kind, pos, scale, colorValue, more = {}) => ({ kind, pos, scale, color: colorValue, ...more });
  const rotateAroundY = (position, heading, offset) => { const cosine = Math.cos(heading), sine = Math.sin(heading); return [position[0] + offset[0] * cosine + offset[2] * sine, position[1] + offset[1], position[2] - offset[0] * sine + offset[2] * cosine]; };
  function segment(kind, start, end, radius, colorValue, more = {}) {
    const delta = sub(end, start), length = Math.hypot(...delta) || 1e-6, direction = delta.map(value => value / length), cosineZ = Math.sqrt(Math.max(1e-8, 1 - direction[0] * direction[0]));
    return part(kind, start.map((value, index) => (value + end[index]) / 2), [radius, length / 2, radius], colorValue, { ...more, rot: [Math.atan2(direction[2], direction[1]), 0, -Math.asin(clamp(direction[0], -1, 1))], segment: true });
  }
  function character(pos = [0, 0, 0], phase = 0, options = {}) {
    const skin = options.skin || "#ffd0a6", cloth = options.cloth || "#2468d8", accent = options.accent || "#e92f3b", dark = options.dark || "#273b84", scale = options.scale || 1, stride = Math.sin(phase), bounce = Math.abs(stride) * .055, lean = options.lean || Math.sin(phase * .5) * .035, p = offset => add(pos, offset.map(value => value * scale));
    const out = [part("capsule", p([0, 1.16 + bounce, 0]), [.54 * scale, .56 * scale, .42 * scale], cloth, { color2: options.cloth2 || "#173f8f", texture: 7, roughness: .56, rot: [0, 0, lean] }), part("sphere", p([.06, 1.86 + bounce, 0]), [.48 * scale, .51 * scale, .46 * scale], skin, { roughness: .42 }), part("capsule", p([-.02, 2.17 + bounce, 0]), [.54 * scale, .2 * scale, .53 * scale], accent, { roughness: .52 }), part("disc", p([.24, 2.11 + bounce, 0]), [.47 * scale, .055 * scale, .5 * scale], accent, { rot: [0, 0, Math.PI / 2], roughness: .5 }),
      part("capsule", p([-.25 + stride * .09, .48 + bounce, -.2]), [.16 * scale, .42 * scale, .15 * scale], dark, { rot: [0, 0, stride * .34] }), part("capsule", p([.25 - stride * .09, .48 + bounce, .2]), [.16 * scale, .42 * scale, .15 * scale], dark, { rot: [0, 0, -stride * .34] }), part("bevel", p([-.13 + stride * .24, .11, -.2]), [.28 * scale, .13 * scale, .21 * scale], "#4b2e2b", { roughness: .72 }), part("bevel", p([.37 - stride * .24, .11, .2]), [.28 * scale, .13 * scale, .21 * scale], "#4b2e2b", { roughness: .72 }),
      part("capsule", p([-.02 - stride * .08, 1.28 + bounce, -.53]), [.13 * scale, .4 * scale, .13 * scale], accent, { rot: [stride * .16, 0, -stride * .42] }), part("capsule", p([.08 + stride * .08, 1.28 + bounce, .53]), [.13 * scale, .4 * scale, .13 * scale], accent, { rot: [-stride * .16, 0, stride * .42] }), part("sphere", p([-.18 - stride * .22, .93 + bounce, -.55]), [.15 * scale, .15 * scale, .15 * scale], skin), part("sphere", p([.28 + stride * .22, .93 + bounce, .55]), [.15 * scale, .15 * scale, .15 * scale], skin),
      part("sphere", p([.46, 1.93 + bounce, -.16]), [.047 * scale, .08 * scale, .055 * scale], "#171925"), part("sphere", p([.46, 1.93 + bounce, .16]), [.047 * scale, .08 * scale, .055 * scale], "#171925"), part("sphere", p([.51, 1.78 + bounce, 0]), [.12 * scale, .105 * scale, .1 * scale], skin), part("capsule", p([.48, 1.69 + bounce, 0]), [.13 * scale, .045 * scale, .18 * scale], options.hair || "#5a2e22", { rot: [0, 0, Math.PI / 2] }), part("bevel", p([-.47, 1.2 + bounce, 0]), [.16 * scale, .38 * scale, .34 * scale], options.pack || "#73513b", { roughness: .84 }), part("wing", p([-.34, 1.62 + bounce, .2]), [.25 * scale, .32 * scale, .34 * scale], accent, { rot: [0, -Math.PI / 2, Math.PI / 2 + Math.sin(phase * .7) * .08], doubleSided: true, wind: .08, phase })];
    if (options.tool) out.push(...options.tool(p([.25, 1.05, .58]), phase, scale)); return out;
  }
  const hero = (pos = [0, 0, 0], phase = 0) => character(pos, phase);
  const birdColors = { jello: ["#7bea72", "#3a9d48"], rubber: ["#ffca35", "#e45b19"], furball: ["#c98cff", "#5e398d"], stone: ["#81909a", "#363f48"], bubble: ["#72eaff", "#8d8aff"], spring: ["#ff617f", "#7d193c"] };
  function bird(kind, pos = [0, 0, 0], deform = 0, phase = 0, palette) {
    const colors = palette || birdColors[kind] || birdColors.jello, flap = Math.sin(phase * 5) * (.24 + deform * .7), squash = 1 + Math.sin(phase * 5) * deform * .18;
    const out = [part("birdBody", pos, [.78 * squash, .76 / squash, .72 * squash], colors[0], { color2: colors[1], texture: kind === "furball" ? 3 : 8, soft: deform, fur: kind === "furball" ? 1 : 0, roughness: kind === "stone" ? .9 : .3, metallic: kind === "bubble" ? .28 : 0, alpha: kind === "bubble" ? .72 : 1, rim: kind === "bubble" ? .35 : .06 }), part("beak", add(pos, [.82, -.02, 0]), [.22, .2, .2], "#ff9c2d", { rot: [0, 0, -Math.PI / 2], roughness: .54 }), part("wing", add(pos, [-.05, .08, .18]), [.62, .5, .62], colors[1], { rot: [flap, 0, -.08], doubleSided: true, texture: 5, roughness: .58 }), part("wingMirror", add(pos, [-.05, .08, -.18]), [.62, .5, .62], colors[1], { rot: [-flap, 0, .08], doubleSided: true, texture: 5, roughness: .58 }), part("leaf", add(pos, [-.72, .05, 0]), [.16, .28, .4], colors[1], { rot: [0, 0, Math.PI / 2], doubleSided: true })];
    for (const side of [-1, 1]) { out.push(part("sphere", add(pos, [.48, .3, side * .42]), [.14, .16, .09], "#ffffff", { roughness: .18 }), part("sphere", add(pos, [.54, .31, side * .48]), [.053, .065, .035], "#11131d", { roughness: .08 })); }
    if (kind === "spring") out.push(part("torus", add(pos, [-.72, 0, 0]), [.3, .3, .3], colors[1], { rot: [0, 0, Math.PI / 2], metallic: .35, roughness: .2 }));
    if (kind === "furball") for (let index = 0; index < 22; index++) { const angle = index / 22 * TAU, y = ((index % 6) - 2.5) * .15; out.push(part("branch", add(pos, [Math.cos(angle) * .64, y, Math.sin(angle) * .64]), [.035, .17, .035], colors[1], { rot: [Math.sin(angle) * 1.2, 0, -Math.cos(angle) * 1.2], wind: .14, phase: index })); }
    return out;
  }

  const fishPalette = [["#65b4d8", "#1e506d"], ["#ffb238", "#fff1a4"], ["#467ff0", "#182b76"], ["#a96eff", "#ff88dd"], ["#567d8a", "#c8e3df"], ["#e94f6f", "#ffd15c"], ["#83d66d", "#355d42"], ["#7b6b5b", "#d6b98e"], ["#565bc4", "#b784de"], ["#ffdd36", "#242a5e"], ["#7be4cc", "#3d4f9e"], ["#ee6686", "#ffe5ac"]];
  function fish(kind = 0, pos = [0, 0, 0], size = 1, heading = 0, phase = 0, suppliedColors) {
    const colors = suppliedColors || fishPalette[kind % fishPalette.length], at = offset => rotateAroundY(pos, heading, offset), tail = Math.sin(phase * 4 + kind) * .34, out = [], shared = { color2: colors[1], texture: 4 + kind % 5, roughness: .3, soft: .014, rim: .08 };
    if (kind === 3 || kind === 7) { out.push(part("capsule", pos, [.72 * size, .34 * size, .72 * size], colors[0], { ...shared, alpha: .6, pulse: .08, subsurface: .3 }), part("disc", at([0, .12 * size, 0]), [.68 * size, .12 * size, .68 * size], colors[1], { alpha: .46, roughness: .08 })); for (let index = 0; index < 12; index++) { const angle = index / 12 * TAU; out.push(part("branch", at([Math.cos(angle) * .43 * size, -.65 * size, Math.sin(angle) * .43 * size]), [.035 * size, .44 * size, .035 * size], colors[index % 2], { alpha: .58, wind: .22, phase: phase + index, rot: [Math.sin(angle) * .16, heading, -Math.cos(angle) * .16] })); } return out; }
    if (kind === 8) { out.push(part("manta", pos, [1.2 * size, .62 * size, 1.35 * size], colors[0], { ...shared, doubleSided: true, soft: .08, phase }), part("rope", at([-1.32 * size, 0, 0]), [.72 * size, .12 * size, .12 * size], colors[1], { rot: [0, heading, 0], soft: .06 })); }
    else if (kind === 10) { for (let index = 0; index < 7; index++) { const t = index / 6, curl = t * Math.PI * 1.25; out.push(part("capsule", at([(t - .45) * .95 * size, (.22 - t * .65 + Math.sin(curl) * .16) * size, Math.sin(curl) * .16 * size]), [(.22 - t * .11) * size, .24 * size, (.18 - t * .08) * size], index % 2 ? colors[0] : colors[1], { rot: [0, heading, Math.cos(curl) * .38], roughness: .42 })); } out.push(part("torus", at([-.55 * size, -.62 * size, 0]), [.24 * size, .24 * size, .24 * size], colors[1], { rot: [Math.PI / 2, heading, 0] })); }
    else if (kind === 5 || kind === 11) { out.push(part("eel", pos, [1.55 * size, .65 * size, .65 * size], colors[0], { ...shared, rot: [0, heading, 0], soft: .12, phase })); for (let index = 0; index < 5; index++) out.push(part("fin", at([(.35 - index * .3) * size, .2 * size, 0]), [.15 * size, .26 * size, .2 * size], colors[1], { rot: [0, heading, 0], doubleSided: true })); }
    else { const length = kind === 9 ? 1.38 : kind === 4 ? 1.18 : 1.05, height = kind === 6 ? .7 : kind === 9 ? .48 : .5, width = kind === 6 ? .58 : .38; out.push(part("fishBody", pos, [length * size, height * size, width * size], colors[0], { ...shared, roughness: kind === 4 ? .5 : .28, rot: [0, heading, 0] }), part("tailFin", at([-1.12 * length * size, 0, 0]), [.58 * size, .54 * size, .5 * size], colors[1], { rot: [0, heading + tail * .16, 0], doubleSided: true, texture: 5 }), part("fin", at([-.08 * size, .42 * height / .5 * size, 0]), [.38 * size, .42 * size, .35 * size], colors[1], { rot: [0, heading, 0], doubleSided: true })); for (const side of [-1, 1]) out.push(part("fin", at([-.05 * size, -.06 * size, side * width * .86 * size]), [.28 * size, .34 * size, .25 * size], colors[1], { rot: [side * .8, heading, -.3], doubleSided: true })); }
    const eyeBase = kind === 10 ? [.3, .14, .14] : [.7, .14, .31]; for (const side of [-1, 1]) out.push(part("sphere", at([eyeBase[0] * size, eyeBase[1] * size, side * eyeBase[2] * size]), [.08 * size, .095 * size, .048 * size], "#f7ffff", { roughness: .12 }), part("sphere", at([.74 * size, .15 * size, side * .34 * size]), [.034 * size, .045 * size, .026 * size], "#101b24", { roughness: .04 }));
    return out;
  }
  function whale(pos = [0, 0, 0], size = 1, heading = 0, phase = 0, colorValue = "#617b8d") { const at = offset => rotateAroundY(pos, heading, offset), tail = Math.sin(phase * 2.2) * .28, out = [part("whaleBody", pos, [1.72 * size, .72 * size, .66 * size], colorValue, { color2: "#c6d2d3", texture: 8, roughness: .46, rot: [0, heading, 0], subsurface: .08 }), part("tailFin", at([-1.92 * size, .02, 0]), [.78 * size, .7 * size, .68 * size], colorValue, { rot: [0, heading + tail * .12, 0], doubleSided: true }), part("fin", at([-.15 * size, -.22 * size, .58 * size]), [.55 * size, .62 * size, .54 * size], colorValue, { rot: [.95, heading, -.15], doubleSided: true }), part("fin", at([-.15 * size, -.22 * size, -.58 * size]), [.55 * size, .62 * size, .54 * size], colorValue, { rot: [-.95, heading, -.15], doubleSided: true }), part("fin", at([-.55 * size, .55 * size, 0]), [.44 * size, .48 * size, .34 * size], colorValue, { rot: [0, heading, -.1], doubleSided: true }), part("torus", at([.52 * size, .58 * size, 0]), [.11 * size, .05 * size, .11 * size], "#26343d", { roughness: .65 })]; for (const side of [-1, 1]) out.push(part("sphere", at([.92 * size, .18 * size, side * .56 * size]), [.055 * size, .065 * size, .035 * size], "#0b1118", { roughness: .08 })); return out; }
  function tree(kind = "oak", pos = [0, 0, 0], size = 1, phase = 0, colors = ["#70482e", "#3f914b"]) {
    const wind = .12 + Math.abs(Math.sin(phase)) * .12, out = [part("branch", add(pos, [0, size, 0]), [.34 * size, size, .34 * size], colors[0], { texture: 2, roughness: .9, wind: wind * .2, phase })];
    for (let index = 0; index < 5; index++) { const angle = index / 5 * TAU, height = (1.05 + index % 3 * .25) * size; out.push(part("branch", add(pos, [Math.cos(angle) * .23 * size, height, Math.sin(angle) * .23 * size]), [.18 * size, .62 * size, .18 * size], colors[0], { rot: [Math.sin(angle) * .62, angle, -Math.cos(angle) * .62], wind: wind * .35, phase: phase + index })); }
    const top = add(pos, [0, 2.05 * size, 0]); if (/pine|cypress/i.test(kind)) { for (let tier = 0; tier < 4; tier++) out.push(part("leaf", add(top, [0, -.28 * tier * size, 0]), [(.9 - tier * .12) * size, (.9 - tier * .1) * size, (.9 - tier * .12) * size], colors[1], { rot: [0, tier * 1.7, Math.PI / 2], texture: 5, doubleSided: true, wind, phase: phase + tier })); } else { for (let index = 0; index < 7; index++) { const angle = index / 7 * TAU, radius = index ? .62 * size : 0; out.push(part("cloud", add(top, [Math.cos(angle) * radius, (index % 3 - 1) * .2 * size, Math.sin(angle) * radius]), [.78 * size, .6 * size, .7 * size], colors[1], { color2: "#b4ce58", texture: 3, roughness: .88, wind, phase: phase + index })); } for (let index = 0; index < (/willow/i.test(kind) ? 18 : 9); index++) { const angle = index / 9 * TAU; out.push(part("leaf", add(top, [Math.cos(angle) * .72 * size, -.35 * size - index % 3 * .18, Math.sin(angle) * .72 * size]), [.11 * size, .34 * size, .22 * size], colors[1], { rot: [Math.sin(angle) * .4, angle, Math.cos(angle) * .5], doubleSided: true, wind: wind * 1.4, phase: phase + index })); } }
    for (let index = 0; index < 4; index++) out.push(part("branch", add(pos, [Math.cos(index * Math.PI / 2) * .3 * size, .05, Math.sin(index * Math.PI / 2) * .3 * size]), [.16 * size, .45 * size, .16 * size], colors[0], { rot: [Math.sin(index * Math.PI / 2) * 1.2, index * Math.PI / 2, -Math.cos(index * Math.PI / 2) * 1.2] })); return out;
  }
  function coral(kind, pos, size = 1, colorValue = "#e86aa8", phase = 0) {
    const label = String(kind), out = [part("rock", add(pos, [0, .08 * size, 0]), [.52 * size, .18 * size, .42 * size], "#4d4c48", { texture: 3, roughness: .95 })];
    if (kind === 1 || /brain/i.test(label)) return out.concat(part("torus", add(pos, [0, .4 * size, 0]), [.72 * size, .3 * size, .72 * size], colorValue, { color2: "#63366c", texture: 2, roughness: .8, twist: .08 }));
    if (kind === 6 || /plate/i.test(label)) { for (let index = 0; index < 5; index++) out.push(part("leaf", add(pos, [index * .07 * size, .2 * size + index * .13 * size, 0]), [(.58 - index * .045) * size, .2 * size, (.62 - index * .05) * size], index % 2 ? colorValue : "#f0a85b", { rot: [0, index * .75, Math.PI / 2], doubleSided: true, roughness: .67 })); return out; }
    const branches = /anemone|torch|glabrescens/i.test(label) ? 24 : 15; for (let index = 0; index < branches; index++) { const angle = index / branches * TAU, ring = (index % 5) * .085 * size, height = (.5 + index % 6 * .09) * size, soft = /anemone|torch|glabrescens/i.test(label), base = add(pos, [Math.cos(angle) * ring, height * .52, Math.sin(angle) * ring]); out.push(part("branch", base, [(soft ? .045 : .075) * size, height * .5, (soft ? .045 : .075) * size], soft ? colorValue : "#7b5845", { rot: [Math.sin(angle) * .2, angle, -Math.cos(angle) * .2], wind: soft ? .24 : .05, phase: phase + index, roughness: .58 })); if (soft || index % 2 === 0) out.push(part("star", add(base, [Math.sin(phase + index) * .06 * size, height * .48, 0]), [.11 * size, .045 * size, .11 * size], colorValue, { emissive: .08, rim: .15, rot: [Math.PI / 2, angle, 0] })); }
    return out;
  }
  function wildBird(pos = [0, 0, 0], size = 1, heading = 0, phase = 0, colors = ["#e7eff1", "#33404b"], flying = true) { const flap = flying ? Math.sin(phase) * .75 : .08; return [part("birdBody", pos, [.44 * size, .3 * size, .28 * size], colors[0], { color2: colors[1], texture: 5, rot: [0, heading, 0], roughness: .62 }), part("wing", rotateAroundY(pos, heading, [-.05 * size, .04 * size, .12 * size]), [.46 * size, .35 * size, .5 * size], colors[1], { rot: [flap, heading, 0], doubleSided: true }), part("wingMirror", rotateAroundY(pos, heading, [-.05 * size, .04 * size, -.12 * size]), [.46 * size, .35 * size, .5 * size], colors[1], { rot: [-flap, heading, 0], doubleSided: true }), part("beak", rotateAroundY(pos, heading, [.46 * size, 0, 0]), [.12 * size, .1 * size, .1 * size], "#dfad46", { rot: [0, heading, -Math.PI / 2] }), part("leaf", rotateAroundY(pos, heading, [-.38 * size, 0, 0]), [.1 * size, .18 * size, .24 * size], colors[1], { rot: [0, heading, Math.PI / 2], doubleSided: true })]; }
  function cloud(pos = [0, 0, 0], size = 1, tint = "#edf5f6", phase = 0, alpha = .8) { const out = []; for (let index = 0; index < 5; index++) out.push(part("cloud", add(pos, [(index - 2) * .5 * size, Math.sin(index * 1.8) * .2 * size, Math.cos(index * 1.3) * .24 * size]), [(.72 + index % 2 * .2) * size, (.42 + index % 3 * .07) * size, (.54 + index % 2 * .1) * size], tint, { alpha, roughness: 1, soft: .025, phase: phase + index })); return out; }
  function bindOrbit(canvas, initial = { yaw: .6, pitch: .32, distance: 14, target: [0, 2, 0] }) { const state = { ...initial, target: [...(initial.target || [0, 2, 0])] }, listeners = []; let drag = null; const emit = () => listeners.forEach(listener => listener(state)); canvas.addEventListener("pointerdown", event => { drag = [event.clientX, event.clientY]; canvas.setPointerCapture(event.pointerId); }); canvas.addEventListener("pointermove", event => { if (!drag) return; state.yaw += (event.clientX - drag[0]) * .008; state.pitch = clamp(state.pitch + (event.clientY - drag[1]) * .006, -1.25, 1.25); drag = [event.clientX, event.clientY]; emit(); }); canvas.addEventListener("pointerup", () => { drag = null; }); canvas.addEventListener("wheel", event => { event.preventDefault(); state.distance = clamp(state.distance * Math.exp(event.deltaY * .001), 3, 45); emit(); }, { passive: false }); return { state, onChange(listener) { listeners.push(listener); }, camera(target = state.target) { const cosine = Math.cos(state.pitch); return { eye: [target[0] + Math.sin(state.yaw) * cosine * state.distance, target[1] + Math.sin(state.pitch) * state.distance, target[2] + Math.cos(state.yaw) * cosine * state.distance], target, up: [0, 1, 0], fov: 48 }; } }; }

  globalThis.BEND_ENGINE_WEBGL = Object.freeze({ create, bindOrbit, registerMesh, makeMesh, meshStats, hero, character, bird, wildBird, fish, whale, tree, coral, cloud, part, segment, color, clamp });
})();
