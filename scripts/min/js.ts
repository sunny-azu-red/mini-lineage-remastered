import fs from 'fs';
import path from 'path';
import { minify } from 'terser';

const SOCKET_IO_CLIENT = path.resolve(process.cwd(), 'node_modules/socket.io/client-dist/socket.io.min.js');
const JS_ORDER = [
    'common.js',
    'audio.js',
    'socket.js',
    'start.js',
    'sidebar.js',
    'home.js',
    'shop.js',
    'suicide.js',
];

const SRC_DIR = path.resolve(process.cwd(), 'public/js');
const OUT_FILE = path.resolve(process.cwd(), 'dist/public/script.js');

async function minJs() {
    if (!fs.existsSync(SRC_DIR)) {
        fs.mkdirSync(SRC_DIR, { recursive: true });
    }

    let bundle = '';

    if (fs.existsSync(SOCKET_IO_CLIENT)) {
        bundle += fs.readFileSync(SOCKET_IO_CLIENT, 'utf-8') + '\n';
    } else {
        console.warn('⚠️ Warning: Socket.IO client not found in node_modules, build may be broken.');
    }

    for (const file of JS_ORDER) {
        const filePath = path.join(SRC_DIR, file);
        if (fs.existsSync(filePath)) {
            bundle += fs.readFileSync(filePath, 'utf-8') + '\n';
        } else {
            console.warn(`⚠️ Warning: ${file} not found, skipping.`);
        }
    }

    try {
        const minified = await minify(bundle, {
            compress: true,
            mangle: true,
            format: {
                comments: false,
            },
        });

        if (minified.code) {
            fs.writeFileSync(OUT_FILE, minified.code);
            console.log(`✅ JS bundled & minified → ${OUT_FILE}`);
        }
    } catch (err) {
        console.error('❌ JS build error:', err);
        process.exit(1);
    }
}

minJs();
