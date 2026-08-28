import mysql from 'mysql2/promise';
import session from 'express-session';
import MySQLStore from 'express-mysql-session';
import { env } from '@/config/env.config';

export const dbPool = mysql.createPool({
    host: env.DB_HOST,
    port: env.DB_PORT,
    database: env.DB_DATABASE,
    user: env.DB_USERNAME,
    password: env.DB_PASSWORD,
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0
});

const Store = MySQLStore(session as any);

export const sessionStore = new Store({
    clearExpired: true,
    checkExpirationInterval: 900_000, // clean up every 15 minutes
    expiration: 86_400_000,           // sessions expire after 24 hours
    createDatabaseTable: true,        // auto-creates the sessions table
}, dbPool as any);
