import 'dotenv/config';
import fs from 'fs';
import path from 'path';
import { dbPool } from '../../backend/config/database.config';

const MIGRATIONS_DIR = path.join(__dirname, '../../database/migrations');

export async function dbMigrate() {
    console.log('🚀 Running migrations...');
    const connection = await dbPool.getConnection();

    try {
        // ensure migrations tracking table exists
        await connection.query(`
            CREATE TABLE IF NOT EXISTS \`migrations\` (
                \`id\` int NOT NULL AUTO_INCREMENT,
                \`name\` varchar(255) NOT NULL UNIQUE,
                \`applied_at\` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (\`id\`)
            ) ENGINE=InnoDB;
        `);

        // get already-applied migrations
        const [rows] = await connection.query('SELECT name FROM migrations');
        const applied = new Set((rows as { name: string }[]).map(r => r.name));

        // run pending migrations in order
        const files = fs.readdirSync(MIGRATIONS_DIR)
            .filter(f => f.endsWith('.sql'))
            .sort();

        let count = 0;
        for (const file of files) {
            if (applied.has(file)) {
                console.log(`⏭️  Already applied: ${file}`);
                continue;
            }

            const sql = fs.readFileSync(path.join(MIGRATIONS_DIR, file), 'utf8');
            const statements = sql.split(';').map(s => s.trim()).filter(s => s.length > 0);

            for (const statement of statements)
                await connection.query(statement);

            await connection.query('INSERT INTO migrations (name) VALUES (?)', [file]);
            console.log(`✅ Applied: ${file}`);
            count++;
        }

        if (count === 0)
            console.log('✨ All migrations already applied.');
        else
            console.log(`✅ ${count} migration(s) applied.`);

    } finally {
        connection.release();
    }
}

if (require.main === module) {
    dbMigrate().catch(err => {
        console.error('❌ Migration failed:', err);
        process.exit(1);
    }).then(() => process.exit(0));
}
