# Cloud Incident Response Series: Case Study 02
## P1 Production Outage: Database Connection Refused

| Incident Metrics | Details |
| :--- | :--- |
| **Incident ID** | CTS-02 |
| **Company** | NovaRetail Sdn. Bhd. |
| **Severity** | P1 (Critical System Outage) |
| **Category** | Database Connectivity & Network ACL Boundaries |
| **Assigned Engineer** | Fadzlan Omar |
| **Status** | Closed / Resolved |

---

## ?? Incident Triage Timeline

### ?? 09:32 AM – Production Alarm Triggered
CloudWatch triggered a critical alert across the e-commerce customer portal: \Database Connection Refused\. Concurrently, customer support channels reported that users were entirely locked out from completing session logins.

### ?????? 09:40 AM – Diagnostic Discovery & Network Probing
Dropped into the web server frontend node via SSH and ran a network diagnostic check using the Netcat tool to probe the target PostgreSQL private socket connection:
\
c -zv 172.31.31.106 5432\

**Diagnostic Output Obtained:**
\
c: connect to 172.31.31.106 port 5432 (tcp) failed: Connection timed out\

### ?? Deep-Dive Engineering Analysis
The diagnostic return code dropped a critical indicator: **\Connection timed out\**. 
* Had the response read *\Connection Refused\*, the infrastructure routing path would be intact, indicating a dead database application service process. 
* Because it read *\Connection timed out\*, it proved that packets were being silently dropped/swallowed at a network boundary firewall layer before reaching the operating system kernel.

Further evaluation using \ping -c 4 172.31.31.106\ yielded \100% packet loss\, confirming that strict stateful ingress filters were dropping non-authorized protocol lines.

---

## ?? Root Cause Analysis (RCA)
Auditing the AWS infrastructure security configuration groups revealed that an entry rule governing ingress paths to the data tier was completely missing. The inbound TCP protocol configuration for port \5432\ originating from the authorized web tier application cluster security group (\
ovaretail-prod-web-sg\) had been deleted from the active \
ovaretail-prod-postgres-sg\ template ruleset.

---

## ??? Recovery Action & Verification Steps
1. **Infrastructure Rule Rectification:** Executed an AWS API action via CLI to dynamically re-authorize the targeted data ingestion pathway:
   \ws ec2 authorize-security-group-ingress --group-name "novaretail-prod-postgres-sg" --protocol tcp --port 5432 --source-group "novaretail-prod-web-sg" --region ap-southeast-1\

2. **Validation Verification Probe:** Re-executed the network boundary check directly from the web server shell:
   \Connection to 172.31.31.106 5432 port [tcp/postgresql] succeeded!\

**Service Status:** Fully operational. Data pipeline links are green. Incident officially closed.
