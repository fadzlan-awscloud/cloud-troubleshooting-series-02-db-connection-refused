# Root Cause Analysis (RCA)

**Technical Breakdown:** The background Python daemon process executing the Flask application runtime (\pp.py\) on Port 5000 was manually terminated via system signal (\pkill python3\). While the underlying AWS EC2 compute hardware remained operational, the Application Load Balancer was unable to establish an upstream TCP socket handshake, resulting in an edge-layer proxy failure.
