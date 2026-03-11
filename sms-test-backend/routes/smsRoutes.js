const express = require('express');
const router = express.Router();
const db = require('../database');

// 1. Create SMS Job
router.post('/send-sms', (req, res) => {
    const { phone, message } = req.body;
    if (!phone || !message) {
        return res.status(400).json({ success: false, error: 'Phone and message are required' });
    }

    const sql = `INSERT INTO sms_jobs (phone, message, status) VALUES (?, ?, 'pending')`;
    db.run(sql, [phone, message], function (err) {
        if (err) {
            return res.status(500).json({ success: false, error: err.message });
        }
        res.json({ success: true, job_id: this.lastID });
    });
});

// 2. Gateway Poll Jobs
router.get('/gateway/jobs', (req, res) => {
    // console.log(`[GATEWAY] Poll request received`); // Log every poll if needed
    const sql = `SELECT id, phone, message FROM sms_jobs WHERE status = 'pending'`;
    db.all(sql, [], (err, rows) => {
        if (err) {
            return res.status(500).json({ error: err.message });
        }

        if (rows.length > 0) {
            const ids = rows.map(row => row.id);
            const updateSql = `UPDATE sms_jobs SET status = 'processing' WHERE id IN (${ids.join(',')})`;
            db.run(updateSql, [], (updateErr) => {
                if (updateErr) console.error('Update to processing failed:', updateErr);
                res.json({ jobs: rows });
            });
        } else {
            res.json({ jobs: [] });
        }
    });
});

// 3. Mark SMS Sent
router.post('/gateway/job-complete', (req, res) => {
    const { job_id } = req.body;
    const sql = `UPDATE sms_jobs SET status = 'sent' WHERE id = ?`;
    db.run(sql, [job_id], (err) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json({ success: true });
    });
});

// 4. Mark SMS Failed
router.post('/gateway/job-failed', (req, res) => {
    const { job_id, error } = req.body;
    console.log(`[GATEWAY] Job ${job_id} FAILED: ${error}`);
    const sql = `UPDATE sms_jobs SET status = 'failed', error_message = ? WHERE id = ?`;
    db.run(sql, [error, job_id], (err) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json({ success: true, logged_error: error });
    });
});

// Admin: Get all jobs for the table
router.get('/admin/jobs', (req, res) => {
    db.all(`SELECT id, phone, message, status, error_message, created_at FROM sms_jobs ORDER BY created_at DESC LIMIT 50`, [], (err, rows) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json(rows);
    });
});

module.exports = router;
