import { deflateSync } from 'zlib';

const PNG_SIGNATURE = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);

const CRC_TABLE = new Uint32Array(256);
for (let n = 0; n < 256; n++) {
  let c = n;
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  CRC_TABLE[n] = c;
}

function crc32(buf: Buffer): number {
  let crc = 0xffffffff;
  for (let i = 0; i < buf.length; i++) crc = CRC_TABLE[(crc ^ buf[i]) & 0xff] ^ (crc >>> 8);
  return (crc ^ 0xffffffff) >>> 0;
}

function writeChunk(type: string, data: Buffer): Buffer {
  const typeBytes = Buffer.from(type, 'ascii');
  const length = Buffer.alloc(4);
  length.writeUInt32BE(data.length);
  const crcInput = Buffer.concat([typeBytes, data]);
  const checksum = Buffer.alloc(4);
  checksum.writeUInt32BE(crc32(crcInput));
  return Buffer.concat([length, typeBytes, data, checksum]);
}

export function rgbaToPng(rgba: Buffer, width: number, height: number): Buffer {
  if (width <= 0 || height <= 0) throw new Error(`Invalid PNG dimensions: ${width}x${height}`);
  const expected = width * height * 4;
  if (rgba.length < expected) throw new Error(`Buffer too small: got ${rgba.length}, need ${expected}`);
  const stride = width * 4;
  const filtered = Buffer.alloc(height * (1 + stride));
  for (let y = 0; y < height; y++) {
    filtered[y * (1 + stride)] = 0; // filter type: None
    rgba.copy(filtered, y * (1 + stride) + 1, y * stride, (y + 1) * stride);
  }

  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8;  // bit depth
  ihdr[9] = 6;  // color type: RGBA
  ihdr[10] = 0; // compression
  ihdr[11] = 0; // filter
  ihdr[12] = 0; // interlace

  return Buffer.concat([
    PNG_SIGNATURE,
    writeChunk('IHDR', ihdr),
    writeChunk('IDAT', deflateSync(filtered)),
    writeChunk('IEND', Buffer.alloc(0)),
  ]);
}

/**
 * Shrinks an RGBA image so its longest side is at most maxSide (box filter: every source
 * pixel counts, so text and thin lines stay readable). Vision models bill images by pixel
 * count, so a 1920x1080 viewport costs ~4x more tokens than the same view at 960x540.
 */
export function downscaleRgba(rgba: Buffer, width: number, height: number, maxSide: number): { data: Buffer; width: number; height: number } {
  const longest = Math.max(width, height);
  if (!maxSide || maxSide <= 0 || longest <= maxSide) return { data: rgba, width, height };
  const scale = maxSide / longest;
  const w = Math.max(1, Math.round(width * scale));
  const h = Math.max(1, Math.round(height * scale));
  const out = Buffer.alloc(w * h * 4);
  for (let y = 0; y < h; y++) {
    const y0 = Math.floor((y * height) / h);
    const y1 = Math.max(y0 + 1, Math.floor(((y + 1) * height) / h));
    for (let x = 0; x < w; x++) {
      const x0 = Math.floor((x * width) / w);
      const x1 = Math.max(x0 + 1, Math.floor(((x + 1) * width) / w));
      let r = 0, g = 0, b = 0, a = 0;
      for (let sy = y0; sy < y1; sy++) {
        let i = (sy * width + x0) * 4;
        for (let sx = x0; sx < x1; sx++, i += 4) {
          r += rgba[i];
          g += rgba[i + 1];
          b += rgba[i + 2];
          a += rgba[i + 3];
        }
      }
      const n = (y1 - y0) * (x1 - x0);
      const o = (y * w + x) * 4;
      out[o] = Math.round(r / n);
      out[o + 1] = Math.round(g / n);
      out[o + 2] = Math.round(b / n);
      out[o + 3] = Math.round(a / n);
    }
  }
  return { data: out, width: w, height: h };
}
