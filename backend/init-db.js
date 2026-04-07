require('dotenv').config();
const mysql = require('mysql2/promise');

async function initializeDatabase() {
    try {
        // Connect without database to create it first if necessary
        const connection = await mysql.createConnection({
            host: process.env.DB_HOST,
            user: process.env.DB_USER,
            password: process.env.DB_PASS
        });

        console.log(`Connected to MySQL as ${process.env.DB_USER}`);
        
        await connection.query(`CREATE DATABASE IF NOT EXISTS \`${process.env.DB_NAME}\`;`);
        console.log(`Database '${process.env.DB_NAME}' checked/created.`);
        
        await connection.query(`USE \`${process.env.DB_NAME}\`;`);

        // Create gateways table
        await connection.query(`
            CREATE TABLE IF NOT EXISTS gateways (
                id INT AUTO_INCREMENT PRIMARY KEY,
                gateway_id VARCHAR(50) UNIQUE NOT NULL,
                name VARCHAR(100),
                api_key VARCHAR(100),
                status ENUM('online', 'offline') DEFAULT 'offline',
                last_seen TIMESTAMP NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            );
        `);
        console.log("Table 'gateways' created.");

        // Create sms_jobs table
        await connection.query(`
            CREATE TABLE IF NOT EXISTS sms_jobs (
                id BIGINT AUTO_INCREMENT PRIMARY KEY,
                phone VARCHAR(20) NOT NULL,
                message TEXT NOT NULL,
                status ENUM('pending', 'processing', 'sent', 'failed') DEFAULT 'pending',
                retry_count INT DEFAULT 0,
                gateway_id VARCHAR(50) NULL,
                error_message TEXT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                FOREIGN KEY (gateway_id) REFERENCES gateways(gateway_id) ON DELETE SET NULL
            );
        `);
        console.log("Table 'sms_jobs' created.");

        // Insert dummy gateway for testing
        await connection.query(`
            INSERT IGNORE INTO gateways (gateway_id, name, api_key, status)
            VALUES ('phone-test-01', 'Test Android Device', '${process.env.GATEWAY_API_KEY}', 'offline');
        `);
        console.log("Dummy gateway 'phone-test-01' inserted/checked.");

        await connection.end();
        console.log("Database Initialization Complete.");
    } catch (error) {
        console.error("Failed to initialize database:", error.message);
    }
}

initializeDatabase();
