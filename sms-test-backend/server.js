const express = require('express');
const cors = require('cors');
const path = require('path');
const smsRoutes = require('./routes/smsRoutes');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Routes
app.use('/', smsRoutes);

// Health Check
app.get('/ping', (req, res) => {
    res.json({ status: "SMS backend running" });
});

// Serve frontend
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`-----------------------------------------`);
    console.log(`SMS Gateway Test Server Running!`);
    console.log(`URL: http://localhost:${PORT}`);
    console.log(`-----------------------------------------`);
});
