require('dotenv').config();
const express = require('express');
const cors = require('cors');
const mysql = require('mysql2/promise');

const app = express();
app.use(cors());
app.use(express.json());

// Database Pool
const pool = mysql.createPool({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASS,
    database: process.env.DB_NAME,
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0
});

// Authentication Middlewares
const clientAuth = (req, res, next) => {
    const apiKey = req.headers['x-api-key'] || req.query.apikey;
    if (apiKey === process.env.CLIENT_API_KEY) {
        return next();
    }
    return res.status(401).json({ status: 'error', message: 'Unauthorized Client API Key' });
};

const gatewayAuth = async (req, res, next) => {
    const authHeader = req.headers.authorization;
    const gatewayId = req.headers['x-gateway-id'] || req.body.gateway_id;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ status: 'error', message: 'Missing Authorization header' });
    }
    
    const token = authHeader.split(' ')[1];
    
    if (token !== process.env.GATEWAY_API_KEY) {
        return res.status(401).json({ status: 'error', message: 'Invalid Gateway API Key' });
    }

    if (!gatewayId) {
        return res.status(400).json({ status: 'error', message: 'Missing x-gateway-id header' });
    }

    req.gatewayId = gatewayId;
    
    // Auto-Register or Update gateway last seen
    try {
        await pool.query(
            "INSERT INTO gateways (gateway_id, name, status, last_seen) VALUES (?, ?, 'online', NOW()) ON DUPLICATE KEY UPDATE status='online', last_seen=NOW(), updated_at=NOW()",
            [gatewayId, gatewayId] // Using ID as Name initially
        );
    } catch (e) {
        console.error("Failed to sync gateway status:", e);
    }

    next();
};

app.get('/', (req, res) => res.json({ status: 'online', message: 'SMS Gateway Production API' }));

// ==========================================
// 1. PUBLIC API FOR EXTERNAL CLIENTS
// ==========================================
app.post('/api/v1/send-sms', clientAuth, async (req, res) => {
    const { phone, message } = req.body;
    
    if (!phone || !message) {
        return res.status(400).json({ status: 'error', message: 'Missing phone or message' });
    }

    try {
        const [result] = await pool.query(
            "INSERT INTO sms_jobs (phone, message, status) VALUES (?, ?, 'pending')",
            [phone, message]
        );
        
        return res.status(200).json({
            status: 'success',
            message: 'SMS queued successfully',
            data: {
                job_id: result.insertId
            }
        });
    } catch (err) {
        console.error("Queue Error:", err);
        return res.status(500).json({ status: 'error', message: 'Database error queuing SMS' });
    }
});


// ==========================================
// 2. INTERNAL API FOR GATEWAY
// ==========================================

// A. Fetch Pending Jobs
app.get('/api/v1/gateway/jobs', gatewayAuth, async (req, res) => {
    try {
        const connection = await pool.getConnection();
        await connection.beginTransaction();

        // 1. Find up to 3 pending jobs
        const [jobs] = await connection.query(
            "SELECT id, phone, message FROM sms_jobs WHERE status = 'pending' ORDER BY id ASC LIMIT 3 FOR UPDATE"
        );

        if (jobs.length === 0) {
            await connection.commit();
            connection.release();
            return res.status(200).json({
                status: 'success',
                data: { jobs: [] }
            });
        }

        const jobIds = jobs.map(j => j.id);

        // 2. Update their status to 'processing' and lock them to this gateway
        await connection.query(
            "UPDATE sms_jobs SET status = 'processing', gateway_id = ?, updated_at = NOW() WHERE id IN (?)",
            [req.gatewayId, jobIds]
        );

        await connection.commit();
        connection.release();

        return res.status(200).json({
            status: 'success',
            data: { jobs }
        });

    } catch (err) {
        console.error("Fetch Jobs Error:", err);
        return res.status(500).json({ status: 'error', message: 'Database error fetching jobs' });
    }
});

// B. Report Job Complete
app.post('/api/v1/gateway/job-complete', gatewayAuth, async (req, res) => {
    const { job_id } = req.body;
    
    try {
        await pool.query(
            "UPDATE sms_jobs SET status = 'sent', updated_at = NOW() WHERE id = ? AND gateway_id = ?",
            [job_id, req.gatewayId]
        );

        return res.status(200).json({
            status: 'success',
            message: `Job ${job_id} marked as sent`
        });
    } catch (err) {
        return res.status(500).json({ status: 'error', message: 'Failed to update job status' });
    }
});

// C. Report Job Failed
app.post('/api/v1/gateway/job-failed', gatewayAuth, async (req, res) => {
    const { job_id, error } = req.body;
    
    try {
        // Fetch current retry count
        const [rows] = await pool.query("SELECT retry_count FROM sms_jobs WHERE id = ?", [job_id]);
        
        if (rows.length === 0) return res.status(404).json({ status: 'error', message: 'Job not found' });
        
        const retryCount = rows[0].retry_count;

        if (retryCount >= 1) { // Max 1 retry (so 2 total attempts)
            await pool.query(
                "UPDATE sms_jobs SET status = 'failed', error_message = ?, updated_at = NOW() WHERE id = ?",
                [error || 'Unknown Native Error', job_id]
            );
            return res.status(200).json({
                status: 'success',
                message: 'Job marked as definitively failed.',
                data: { retry_scheduled: false }
            });
        } else {
            // Set back to pending for retry
            await pool.query(
                "UPDATE sms_jobs SET status = 'pending', retry_count = retry_count + 1, error_message = ?, gateway_id = NULL, updated_at = NOW() WHERE id = ?",
                [error || 'Unknown Native Error', job_id]
            );
            return res.status(200).json({
                status: 'success',
                message: 'Job failed. Will retry.',
                data: { retry_scheduled: true }
            });
        }
    } catch (err) {
        return res.status(500).json({ status: 'error', message: 'Failed to report job failure' });
    }
});

// ==========================================
// 3. ADMIN API FOR DASHBOARD
// ==========================================

// A. Get Stats
app.get('/api/v1/admin/stats', clientAuth, async (req, res) => {
    try {
        const [[stats]] = await pool.query(`
            SELECT 
                COUNT(*) as total_count,
                SUM(CASE WHEN status = 'sent' THEN 1 ELSE 0 END) as sent_count,
                SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) as pending_count,
                SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) as failed_count
            FROM sms_jobs
        `);
        
        const [[gateways]] = await pool.query(`
            SELECT COUNT(*) as online_gateways FROM gateways WHERE status = 'online' AND last_seen > DATE_SUB(NOW(), INTERVAL 5 MINUTE)
        `);

        res.json({
            status: 'success',
            data: {
                ...stats,
                online_gateways: gateways.online_gateways || 0
            }
        });
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});

// B. Get Recent Jobs
app.get('/api/v1/admin/jobs', clientAuth, async (req, res) => {
    try {
        const [jobs] = await pool.query(
            "SELECT id, phone, message, status, gateway_id, error_message, updated_at FROM sms_jobs ORDER BY id DESC LIMIT 50"
        );
        res.json({ status: 'success', data: jobs });
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});

// C. Get All Gateways
app.get('/api/v1/admin/gateways', clientAuth, async (req, res) => {
    try {
        const [gateways] = await pool.query(
            "SELECT gateway_id, name, status, last_seen, updated_at FROM gateways ORDER BY last_seen DESC"
        );
        res.json({ status: 'success', data: gateways });
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});

const releaseStuckJobs = async () => {
    try {
        const [result] = await pool.query(
            "UPDATE sms_jobs SET status = 'pending', gateway_id = NULL, error_message = 'Job timed out on previous gateway', updated_at = NOW() WHERE status = 'processing' AND updated_at < DATE_SUB(NOW(), INTERVAL 5 MINUTE)"
        );
        if (result.changedRows > 0) {
            console.log(`[Failover] Released ${result.changedRows} stuck jobs back to pending.`);
        }
    } catch (err) {
        console.error("Failover Cleanup Error:", err);
    }
};

// Run cleanup every minute
setInterval(releaseStuckJobs, 60000);

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
    console.log(`SMS Gateway Production Backend running on port ${PORT}`);
});
