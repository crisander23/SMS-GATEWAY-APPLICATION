from flask import Flask, request, jsonify
from flask_cors import CORS
import time

app = Flask(__name__)
CORS(app, resources={r"/*": {"origins": "*"}}, supports_credentials=True)

@app.route('/', methods=['GET'])
def index():
    return "SMS Gateway 2.0 Backend is Running!"

# In-memory queue and logs
jobs = [
    {"id": 101, "phone": "+639171234567", "message": "OTP: 123456 - SMS Gateway 2.0 Test"},
    {"id": 102, "phone": "+639187654321", "message": "Welcome to the SMS Gateway! - SMS Gateway 2.0 Test"}
]
activity_logs = []

def add_log(msg, type="info"):
    activity_logs.insert(0, {
        "time": time.strftime("%H:%M:%S"),
        "message": msg,
        "type": type
    })
    if len(activity_logs) > 50: activity_logs.pop()

@app.route('/gateway/jobs', methods=['GET'])
def get_jobs():
    global jobs
    if jobs:
        current_jobs = [jobs.pop(0)]
        add_log(f"Gateway fetched job: {current_jobs[0]['id']} for {current_jobs[0]['phone']}")
        return jsonify({"jobs": current_jobs})
    return jsonify({"jobs": []})

@app.route('/gateway/job-complete', methods=['POST'])
def job_complete():
    data = request.json
    add_log(f"Job {data.get('job_id')} SENT successfully", "success")
    return jsonify({"status": "success"})

@app.route('/gateway/job-failed', methods=['POST'])
def job_failed():
    data = request.json
    add_log(f"Job {data.get('job_id')} FAILED: {data.get('error')}", "error")
    return jsonify({"status": "error_logged"})

@app.route('/admin/logs', methods=['GET'])
def get_admin_logs():
    return jsonify(activity_logs)

@app.route('/admin/queue', methods=['GET'])
def get_queue():
    return jsonify(jobs)

@app.route('/admin/send', methods=['POST'])
def add_job():
    data = request.json
    new_job = {
        "id": int(time.time()),
        "phone": data.get('phone'),
        "message": data.get('message')
    }
    jobs.append(new_job)
    add_log(f"Manual job added for {new_job['phone']}")
    return jsonify({"status": "queued", "job": new_job})

if __name__ == '__main__':
    print("SMS Gateway 2.0 Mock Backend with Dashboard Support...")
    app.run(host='0.0.0.0', port=5000)
