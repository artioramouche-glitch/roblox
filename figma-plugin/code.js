// Roblox MCP Bridge (Figma plugin). Two commands from the Roblox Ultimate MCP server:
//   read -> the selected layer as a plain tree (positions relative to the parent layer,
//           pictures and vectors exported as PNG); the server turns it into a build_ui spec.
//   draw -> creates the layers the server computed from a build_ui spec.
// All the Roblox logic lives in the server (packages/core/src/gamekit/figma.ts).

figma.showUI(__html__, { width: 280, height: 110, title: 'Roblox MCP Bridge' });

// Shapes Roblox UI cannot draw: exported as pictures (ImageLabels).
const PICTURE_TYPES = ['VECTOR', 'BOOLEAN_OPERATION', 'STAR', 'POLYGON', 'LINE'];

function sendInfo() {
  figma.ui.postMessage({ type: 'info', file: figma.root.name, page: figma.currentPage.name, selection: figma.currentPage.selection.length });
}
figma.on('selectionchange', sendInfo);
figma.on('currentpagechange', sendInfo);
sendInfo();

function paint(p) {
  return {
    type: p.type,
    visible: p.visible,
    opacity: p.opacity,
    color: p.color ? { r: p.color.r, g: p.color.g, b: p.color.b } : undefined,
    stops: p.gradientStops ? p.gradientStops.map((s) => ({ color: { r: s.color.r, g: s.color.g, b: s.color.b } })) : undefined,
  };
}

function hasImageFill(node) {
  return 'fills' in node && Array.isArray(node.fills) && node.fills.some((f) => f.type === 'IMAGE' && f.visible !== false);
}

async function serialize(node, parentBox) {
  const box = node.absoluteBoundingBox || { x: node.x, y: node.y, width: node.width, height: node.height };
  const out = {
    type: node.type,
    name: node.name,
    x: parentBox ? box.x - parentBox.x : 0,
    y: parentBox ? box.y - parentBox.y : 0,
    width: box.width,
    height: box.height,
    visible: node.visible,
    opacity: 'opacity' in node ? node.opacity : 1,
  };
  if ('fills' in node && Array.isArray(node.fills)) out.fills = node.fills.map(paint);
  if ('strokes' in node && Array.isArray(node.strokes)) out.strokes = node.strokes.map(paint);
  if ('strokeWeight' in node && typeof node.strokeWeight === 'number') out.strokeWeight = node.strokeWeight;
  if ('cornerRadius' in node) out.cornerRadius = typeof node.cornerRadius === 'number' ? node.cornerRadius : node.topLeftRadius || 0;
  if (node.type === 'TEXT') {
    out.characters = node.characters;
    const empty = node.characters.length === 0;
    out.fontSize = typeof node.fontSize === 'number' ? node.fontSize : empty ? 16 : node.getRangeFontSize(0, 1);
    const font = typeof node.fontName === 'object' && node.fontName.family ? node.fontName : empty ? null : node.getRangeFontName(0, 1);
    if (font) {
      out.fontFamily = font.family;
      out.fontStyle = font.style;
    }
    out.textAlign = node.textAlignHorizontal;
    if (!Array.isArray(node.fills) && !empty) {
      const fills = node.getRangeFills(0, 1);
      if (Array.isArray(fills)) out.fills = fills.map(paint);
    }
  }
  if ('layoutMode' in node && node.layoutMode !== 'NONE') {
    out.layoutMode = node.layoutMode;
    out.itemSpacing = node.itemSpacing;
    out.padding = node.paddingLeft;
    out.primaryAlign = node.primaryAxisAlignItems;
  }
  const picture = PICTURE_TYPES.indexOf(node.type) >= 0 || /\[image\]/i.test(node.name) || hasImageFill(node);
  if (picture && node.visible) {
    try {
      const bytes = await node.exportAsync({ format: 'PNG', constraint: { type: 'SCALE', value: 2 } });
      out.png = figma.base64Encode(bytes);
    } catch (e) {
      // left without a picture: the server reports it
    }
  } else if ('children' in node) {
    out.children = [];
    for (const child of node.children) out.children.push(await serialize(child, box));
  }
  return out;
}

function rgb(hex) {
  const n = parseInt(String(hex || '#FFFFFF').replace('#', ''), 16);
  return { r: ((n >> 16) & 255) / 255, g: ((n >> 8) & 255) / 255, b: (n & 255) / 255 };
}

function solid(hex, opacity) {
  return { type: 'SOLID', color: rgb(hex), opacity: opacity === undefined ? 1 : opacity };
}

function gradient(colors, opacity) {
  const stop = (hex, position) => ({ position: position, color: Object.assign(rgb(hex), { a: 1 }) });
  return {
    type: 'GRADIENT_LINEAR',
    gradientTransform: [[0, 1, 0], [-1, 0, 1]],
    gradientStops: [stop(colors[0], 0), stop(colors[1] || colors[0], 1)],
    opacity: opacity === undefined ? 1 : opacity,
  };
}

async function draw(ops) {
  await figma.loadFontAsync({ family: 'Inter', style: 'Regular' });
  await figma.loadFontAsync({ family: 'Inter', style: 'Bold' });
  const made = [];
  for (const op of ops) {
    const parent = op.parent < 0 ? figma.currentPage : made[op.parent];
    let node;
    if (op.kind === 'text') {
      node = figma.createText();
      node.fontName = { family: 'Inter', style: op.bold ? 'Bold' : 'Regular' };
      node.characters = op.text || '';
      node.fontSize = op.fontSize || 16;
      node.textAutoResize = 'NONE';
      node.resize(op.w, op.h);
      node.textAlignHorizontal = op.align === 'LEFT' || op.align === 'RIGHT' ? op.align : 'CENTER';
      node.textAlignVertical = 'CENTER';
      node.fills = [solid(op.textColor, 1)];
    } else {
      node = figma.createFrame();
      node.resize(op.w, op.h);
      node.clipsContent = false;
      node.fills = op.gradient ? [gradient(op.gradient, op.fillOpacity)] : op.fill ? [solid(op.fill, op.fillOpacity)] : [];
      // Grey placeholder where a picture goes (the user drops the real one here).
      if (op.kind === 'image' && !op.fill) node.fills = [solid('#9AA0A6', 0.35)];
      node.cornerRadius = op.corner || 0;
      if (op.stroke) {
        node.strokes = [solid(op.stroke, 1)];
        node.strokeWeight = 2;
      }
      if (op.layout) {
        node.layoutMode = op.layout;
        node.itemSpacing = op.gap || 0;
        node.primaryAxisSizingMode = 'FIXED';
        node.counterAxisSizingMode = 'FIXED';
        node.primaryAxisAlignItems = 'CENTER';
        node.counterAxisAlignItems = 'CENTER';
      }
      if (op.padding) {
        node.paddingLeft = op.padding;
        node.paddingRight = op.padding;
        node.paddingTop = op.padding;
        node.paddingBottom = op.padding;
      }
    }
    node.name = op.name;
    parent.appendChild(node);
    if (op.parent < 0) {
      const center = figma.viewport.center;
      node.x = Math.round(center.x - op.w / 2);
      node.y = Math.round(center.y - op.h / 2);
    } else if (!parent.layoutMode || parent.layoutMode === 'NONE') {
      node.x = op.x;
      node.y = op.y;
    }
    if (op.visible === false) node.visible = false;
    made.push(node);
  }
  figma.currentPage.selection = [made[0]];
  figma.viewport.scrollAndZoomIntoView([made[0]]);
  return { nodeId: made[0].id, name: made[0].name, layers: made.length };
}

async function run(command) {
  if (command.action === 'read') {
    const picked = figma.currentPage.selection[0];
    return { file: figma.root.name, root: picked ? await serialize(picked, null) : null };
  }
  if (command.action === 'draw') return draw(command.ops || []);
  throw new Error('Unknown command: ' + command.action);
}

figma.ui.onmessage = async (msg) => {
  if (!msg || msg.type !== 'command') return;
  try {
    figma.ui.postMessage({ type: 'result', id: msg.id, ok: true, result: await run(msg.command || {}) });
  } catch (e) {
    figma.ui.postMessage({ type: 'result', id: msg.id, ok: false, error: String((e && e.message) || e) });
  }
};
