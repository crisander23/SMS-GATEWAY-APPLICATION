require('dotenv').config({ path: './backend/.env' });
const mysql = require('mysql2/promise');

async function checkGateways() {
    try {
        const connection = await mysql.createConnection({
            host: process.env.DB_HOST,
            user: process.env.DB_USER,
            password: process.env.DB_PASS,
            database: process.env.DB_NAME
        });

        const [rows] = await connection.query("SELECT gateway_id, name, status, last_seen FROM gateways ORDER BY last_seen DESC");
        
        console.log("\n--- REGISTERED GATEWAYS ---");
        if (rows.length === 0) {
            console.log("No gateways found.");
        } else {
            console.table(rows);
        }

        await connection.end();
    } catch (error) {
        console.error("Error connecting to database:", error.message);
    }
}

checkGateways();
