import fs from 'fs';
import path from 'path';
import { minify } from 'html-minifier-terser';

const DIST_VIEW_DIR = path.resolve(process.cwd(), 'dist/src/view/template');

async function minifyFile(filePath: string) {
    const content = fs.readFileSync(filePath, 'utf-8');
    try {
        const minified = await minify(content, {
            collapseWhitespace: true,
            conservativeCollapse: true,
            removeComments: true,
            minifyJS: true,
            minifyCSS: true,
            ignoreCustomFragments: [/<%[\s\S]*?%>/g], // Ignore EJS tags
        });
        fs.writeFileSync(filePath, minified);
        console.log(`✅ Minified: ${path.relative(DIST_VIEW_DIR, filePath)}`);
    } catch (err) {
        console.error(`❌ Error minifying ${filePath}:`, err);
    }
}

async function walkDir(dir: string) {
    const files = fs.readdirSync(dir);
    for (const file of files) {
        const filePath = path.join(dir, file);
        const stat = fs.statSync(filePath);
        if (stat.isDirectory()) {
            await walkDir(filePath);
        } else if (filePath.endsWith('.ejs')) {
            await minifyFile(filePath);
        }
    }
}

async function minHtml() {
    if (!fs.existsSync(DIST_VIEW_DIR)) {
        console.error(`❌ Error: ${DIST_VIEW_DIR} does not exist. Run 'npm run build' first or ensure templates are copied.`);
        process.exit(1);
    }

    console.log('🚀 Minifying HTML (EJS) templates...');
    await walkDir(DIST_VIEW_DIR);
    console.log('✨ HTML minification complete.');
}

minHtml();
