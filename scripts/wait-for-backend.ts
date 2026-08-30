import 'dotenv/config';
import waitOn from 'wait-on';

// Only ever runs as part of `npm run dev` (see package.json's dev:frontend:ready). Port comes
// from PORT (the backend's own listen port), matching frontend/vite.config.ts's proxy target.
const target = `${process.env.DEV_BACKEND_HOST ?? 'http://localhost'}:${process.env.PORT ?? 3000}`;

waitOn({ resources: [target] })
    .then(() => process.exit(0))
    .catch((err) => {
        console.error(`[wait-for-backend] backend never became ready at ${target}:`, err.message);
        process.exit(1);
    });
