# app/app.py
from flask import Flask
import socket

app = Flask(__name__)

@app.route('/')
def home():
    container_id = socket.gethostname()
    return f"<h1>🎯 Containerized Production Environment Live! Host: {container_id}</h1>"

@app.route('/health')
def health_check():
    return "OK", 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
    