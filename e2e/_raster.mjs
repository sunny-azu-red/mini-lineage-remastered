import { chromium } from 'playwright';
import fs from 'node:fs';
const [svgPath, outDir, ...sizes] = process.argv.slice(2);
const svg = fs.readFileSync(svgPath, 'utf8');
const b = await chromium.launch();
for (const size of sizes.map(Number)) {
  const p = await b.newPage({ viewport: { width: size, height: size }, deviceScaleFactor: 1 });
  await p.setContent(`<html><body style="margin:0;background:transparent">${svg.replace('<svg ', `<svg width="${size}" height="${size}" `)}</body></html>`);
  await p.screenshot({ path: `${outDir}/icon-${size}.png`, omitBackground: true });
  await p.close();
}
await b.close();
