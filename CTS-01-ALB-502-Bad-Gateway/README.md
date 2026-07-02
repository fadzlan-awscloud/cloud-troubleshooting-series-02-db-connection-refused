# CTS-01: ALB 502 Bad Gateway (Flask Process Failure)

A production-level incident response case study isolating an application-layer outage behind an AWS Application Load Balancer (ALB). Part of the **Cloud Troubleshooting Series (CTS)**.

## Incident Profile
- **Date:** 23 June 2026
- **Severity:** P1 (Production Outage)
- **Status:** Resolved
- **Root Cause:** Intentional application termination (Flask daemon killed)
- **Impact:** External users received an \HTTP 502 Bad Gateway\ at the load balancer ingress point.

  cloud-troubleshooting-series-01-alb-502/
│
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── user-data.sh
│
├── app/
│   ├── app.py
│   └── requirements.txt
│
├── incident/
│   ├── INCIDENT.md
│   ├── ROOT-CAUSE.md
│   ├── TIMELINE.md
│   └── RECOVERY.md
│
├── screenshots/
│
├── README.md
│
└── .gitignore

---

## Architecture Layout
Traffic flows through a standard high-availability edge routing design:
\\\	ext
Internet ---> Application Load Balancer (Port 80) ---> Target Group ---> EC2 Instance ---> Flask App (Port 5000)
\\\
[ Internet ] ---> ( ALB:80 ) ---> [ Target Group ] --x--> ( EC2:5000 ) ---> [ Flask App ]
                                                       ^
                                            [ Connection Refused ]
                                            (Process was killed!)


---

## Phase 1: The Outage & Triage Timeline

### 1. Ingress Symptom
When visiting the Application Load Balancer URL, the edge proxy returned a definitive error:
- **Symptom:** \502 Bad Gateway\
- **Evidence Reference:**\'screenshots/502-bad-gateway-error.png\`
 ![Ingress symptom](screenshots/502-bad-gateway-error.png)
  
### 2. Target Group Audit
Inspected the AWS Target Group status to verify routing health:
- **Status:** \unhealthy\
- **Reason:** \Target.Timeout\ (Health checks failing on Port 5000)
- **Evidence Reference:**
  ![Target group_audit](cts-01-evidence-03-unhealthy-tg.png)

### 3. Compute Infrastructure Verification
Verified the core instance state via the AWS CLI/Console:
- **EC2 State:** \Running\
- **Conclusion:** The virtual machine was completely stable, indicating the failure was isolated to the internal networking layer or application runtime.

---

## Phase 2: Deep-Dive Linux Investigation

With the infrastructure verified as running, we initiated an internal systems audit via secure SSH tunnel to inspect the server internals.

### Execution Log & Commands Run:
1. **Process Inspection:** Checked for active python runtimes:
   \\\bash
   ps aux | grep python3
   \\\
   *Result:* Confirmed **0 active processes** for \pp.py\. The application process had ceased.

2. **Local Port Bind Verification:** Tested internal listener loopbacks:
   \\\bash
   curl localhost:5000
   \\\
   *Result:* \Failed to connect to localhost port 5000: Connection refused\.

3. **Deployment Log Audit:** Verified that the startup initialization executed successfully without installation errors:
   \\\bash
   cat /var/log/cloud-init-output.log
   \\\
   *Result:* Dependencies installed correctly during system boot; process was killed post-deployment.

---

## Phase 3: Recovery Actions

### 1. Manual Application Patch
Manually re-initialized the background daemon to restore immediate application delivery:
\\\ash
nohup python3 /home/ubuntu/app.py > /home/ubuntu/app.log 2>&1 &
\\\

### 2. Infrastructure Validation
- Checked the local socket: \curl localhost:5000\ returned \HTTP 200 OK\ (Hello from ip-...).
- Monitored the AWS Target Group until status transitioned back to **\healthy (1/1 targets)\**.

### 3. Final Verification
Refreshed the public-facing ALB endpoint string:
- **Link:** \
- **Result:** Successful text rendering. Code execution restored.
- **Evidence Reference:** \screenshots/cts-01-evidence-06-success-browser.png\

---

## Lessons Learned & Key Takeaways
1. **Isolate Layers Early:** A 502 error proves the ALB is alive but its backend target is unresponsive. Checking Target Group health immediately differentiates a network routing issue from a service crash.
2. **Declarative Code vs. Imperative State:** Changing infrastructure code (\main.tf\) to troubleshoot a runtime crash creates code drift. Live application processes must be investigated at the OS layer.
3. **Decouple Startup Scripts:** Utilizing an external \user-data.sh\ script maintains strict separation of concerns between underlying cloud components and bootstrap configurations.
