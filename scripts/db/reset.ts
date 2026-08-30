import 'dotenv/config';
import { dbPool } from '../../backend/config/database.config';
import { dbMigrate } from './migrate';

async function dbReset() {
    console.log('🚀 Resetting database to a clean state...');

    try {
        const connection = await dbPool.getConnection();
        console.log('🧹 Clearing all existing tables...');

        // get all tables in the current database
        const [rows] = await connection.query('SHOW TABLES') as any[];
        const tables = rows.map((row: any) => Object.values(row)[0] as string);

        if (tables.length > 0) {
            // disable foreign key checks to ensure we can drop everything
            await connection.query('SET FOREIGN_KEY_CHECKS = 0');

            for (const table of tables) {
                console.log(`🗑️  Dropping table: ${table}`);
                await connection.query(`DROP TABLE IF EXISTS \`${table}\``);
            }

            await connection.query('SET FOREIGN_KEY_CHECKS = 1');
            console.log('✅ All tables dropped.');
        } else {
            console.log('✨ No tables found to drop.');
        }

        connection.release();

        await dbMigrate();

        console.log('✅ Database reset successfully!');
    } catch (err) {
        console.error('❌ Database reset failed:', err);
        process.exit(1);
    } finally {
        process.exit(0);
    }
}

dbReset();
