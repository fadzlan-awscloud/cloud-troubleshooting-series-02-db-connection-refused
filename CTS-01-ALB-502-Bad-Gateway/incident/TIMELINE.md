# Incident Timeline

- **12:00 PM** - Alert triggered: Ingress endpoint returning 502 Bad Gateway.
- **12:05 PM** - Triage initiated. AWS Target Group confirmed in an 'unhealthy' state.
- **12:15 PM** - Security Group updated to allow temporary administrative SSH traffic.
- **12:20 PM** - SSH session established; verified 0 running Python applications.
- **12:25 PM** - Daemon restarted manually via nohup.
- **12:30 PM** - Ingress endpoints recovered successfully. System restored.
