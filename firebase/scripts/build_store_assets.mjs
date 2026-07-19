// Builds Play Store assets from the generated master artwork.
// Usage: node build_store_assets.mjs <icon_master.png> <feature_master.png>
// Outputs to ../../store_assets and ../../assets/launcher.
import { mkdir } from "node:fs/promises";
import path from "node:path";
import sharp from "sharp";

const [iconMaster, featureMaster] = process.argv.slice(2);
if (!iconMaster || !featureMaster) {
  console.error("usage: node build_store_assets.mjs <icon> <feature>");
  process.exit(1);
}

const root = path.resolve(import.meta.dirname, "..", "..");
const storeDir = path.join(root, "store_assets");
const launcherDir = path.join(root, "assets", "launcher");
await mkdir(storeDir, { recursive: true });
await mkdir(launcherDir, { recursive: true });

// 1. Play Console hi-res icon: 512x512 32-bit PNG.
await sharp(iconMaster)
  .resize(512, 512)
  .png()
  .toFile(path.join(storeDir, "icon_512.png"));

// 2. Launcher icon source (legacy square) at 1024.
await sharp(iconMaster)
  .resize(1024, 1024)
  .png()
  .toFile(path.join(launcherDir, "icon.png"));

// 3. Adaptive foreground: artwork scaled into the 66% safe zone on a
//    transparent 1024 canvas.
const fg = await sharp(iconMaster).resize(660, 660).png().toBuffer();
await sharp({
  create: {
    width: 1024,
    height: 1024,
    channels: 4,
    background: { r: 0, g: 0, b: 0, alpha: 0 },
  },
})
  .composite([{ input: fg, gravity: "centre" }])
  .png()
  .toFile(path.join(launcherDir, "icon_foreground.png"));

// 4. Feature graphic 1024x500 with crisp SVG title text on the right.
const title = Buffer.from(`<svg width="1024" height="500">
  <style>
    .t { font-family: 'DejaVu Sans', sans-serif; }
  </style>
  <text x="655" y="225" class="t" font-size="64" font-weight="700"
        fill="#9B3B5A">Flut Marriage</text>
  <text x="657" y="275" class="t" font-size="28" fill="#7a6a58">
    One account · Five life domains</text>
  <text x="657" y="315" class="t" font-size="28" fill="#7a6a58">
    Marriage · Jobs · Rooms · Bikes · Help</text>
</svg>`);
await sharp(featureMaster)
  .resize(1024, 500, { fit: "cover", position: "centre" })
  .composite([{ input: title }])
  .png()
  .toFile(path.join(storeDir, "feature_graphic_1024x500.png"));

console.log("store assets written to", storeDir, "and", launcherDir);
