# Cloud Operations Lab

Cloud Operations Lab is a hands-on troubleshooting and incident-response environment designed to practice Linux, containers, networking, monitoring, logging, and cloud operations.

The project intentionally creates operational failures and documents how to investigate, identify, fix, verify, and prevent them.

## Purpose

Many infrastructure projects demonstrate how to deploy a service.

This lab focuses on what happens when the service stops working, when infrastructure reports an incorrect operational state, or when the application remains available while the underlying system is degraded.

Each scenario follows an incident-response workflow:

```text
Incident
   |
   v
Symptoms
   |
   v
Investigation
   |
   v
Root Cause
   |
   v
Resolution
   |
   v
Verification
   |
   v
Prevention
```

## Current Lab Service

The lab runs a small Flask application inside Docker.

Endpoints:

```text
GET /
GET /health
```

Healthy response:

```json
{
  "status": "ok"
}
```

Normal request path:

```text
Client
   |
   v
localhost:8080
   |
   v
Docker published port
   |
   v
Container :8080
   |
   v
Flask application
```

Docker also monitors the service with a health check.

The container currently has a memory limit of:

```text
256 MiB
```

## Incident Progress

| Incident | Scenario | Status |
|---|---|---|
| 01 | Service unreachable due to incorrect Docker port mapping | Completed |
| 02 | Container health check failure | Completed |
| 03 | Application process failure and restart loop | Completed |
| 04 | High CPU usage | Completed |
| 05 | Memory pressure | Completed |
| 06 | Log growth and disk pressure | Completed |
| 07 | DNS resolution failure | Completed |
| 08 | Network connectivity failure | Planned |

## Completed Incidents

### Incident 01 — Service Unreachable Due to Incorrect Docker Port Mapping

The application was healthy inside the container but unreachable from the host.

Observed:

```text
Host 8080 -> Container 8081
```

Root cause:

```text
Incorrect Docker Compose port mapping
```

Full report:

[Incident 01 — Service Unreachable Due to Incorrect Docker Port Mapping](incidents/01-service-unreachable-wrong-port.md)

---

### Incident 02 — Container Health Check Failure

The application remained available while Docker reported the container as unhealthy.

Docker was checking:

```text
127.0.0.1:9999/health
```

while Flask was listening on:

```text
127.0.0.1:8080
```

Root cause:

```text
Incorrect health-check port
```

Full report:

[Incident 02 — Container Health Check Failure](incidents/02-container-healthcheck-failure.md)

---

### Incident 03 — Application Process Failure and Restart Loop

Docker repeatedly restarted the container because the configured application entrypoint did not exist.

Logs showed:

```text
python: can't open file '/app/app/missing.py'
```

Root cause:

```text
Invalid application entrypoint
```

After remediation:

```text
Container status: healthy
Application health: ok
RestartCount: 0
```

Full report:

[Incident 03 — Application Process Failure and Restart Loop](incidents/03-application-process-restart-loop.md)

---

### Incident 04 — High CPU Usage

The application remained healthy while CPU utilization reached approximately:

```text
99.82%
```

Process-level investigation identified a background Python process executing:

```python
while True:
    pass
```

After terminating it:

```text
CPU: 0.01%
PIDS: 1
Application health: ok
```

Full report:

[Incident 04 — High CPU Usage](incidents/04-high-cpu-usage.md)

---

### Incident 05 — Memory Pressure

The container memory limit was:

```text
256 MiB
```

During the incident:

```text
Memory: 213.3 MiB / 256 MiB
Usage: 83.31%
Application health: ok
```

After identifying and terminating the memory-consuming process:

```text
Memory: 28.97 MiB / 256 MiB
Usage: 11.32%
Application health: ok
```

Full report:

[Incident 05 — Memory Pressure](incidents/05-memory-pressure.md)

---

### Incident 06 — Log Growth and Disk Pressure

A simulated log file grew to:

```text
64M
```

The `/var/log` directory increased from:

```text
212K
```

to:

```text
65M
```

Docker reported the writable layer growing to:

```text
67.1MB
```

After cleanup:

```text
/var/log:       212K
Writable layer: 20.5kB
Application:    healthy
```

Full report:

[Incident 06 — Log Growth and Disk Pressure](incidents/06-log-growth-disk-pressure.md)

---

### Incident 07 — DNS Resolution Failure

The container lost hostname resolution while general TCP connectivity remained functional.

Normal DNS:

```text
example.com -> IP address
```

After changing the resolver:

```text
socket.gaierror:
Temporary failure in name resolution
```

However, direct TCP connectivity still worked:

```text
TCP 1.1.1.1:443 = OK
```

The application also remained:

```text
healthy
```

The diagnosis was therefore:

```text
DNS           FAIL
TCP           OK
Application   OK
```

The container resolver had been changed from Docker's internal resolver:

```text
127.0.0.11
```

to a non-functional resolver.

After restoring the original resolver:

```text
DNS           OK
TCP           OK
Application   OK
Container     healthy
```

This incident demonstrated how to distinguish:

```text
DNS failure
vs
TCP failure
vs
Application failure
```

Full report:

[Incident 07 — DNS Resolution Failure](incidents/07-dns-resolution-failure.md)

## Troubleshooting Method

Each incident is investigated layer by layer.

```text
Application
    |
    v
Process
    |
    v
Container
    |
    v
DNS
    |
    v
Network
    |
    v
Port Publishing
    |
    v
Host
    |
    v
Client
```

Resource incidents add:

```text
Operational Health
       |
       +--> Availability
       +--> CPU
       +--> Memory
       +--> Disk
       +--> DNS
       +--> Network
       +--> Logs
```

Different signals must be evaluated independently.

```text
Application health != Container health
Container running   != Application running
Health endpoint ok  != CPU usage normal
Health endpoint ok  != Memory usage normal
Health endpoint ok  != Disk usage normal
DNS failure         != Network outage
```

## Technologies

Current technologies:

- Python
- Flask
- Docker
- Docker Compose
- Linux process inspection
- Linux PID namespaces
- `/proc`
- filesystem inspection
- DNS troubleshooting
- TCP connectivity testing
- container resource limits
- HTTP
- TCP/IP
- Git
- PowerShell

Planned additions:

- additional network diagnostics
- Prometheus
- Grafana
- GitHub Actions
- AWS CloudWatch
- AWS ECS
- Terraform

## Run the Lab

Build and start:

```bash
docker compose up -d --build
```

Check container state:

```bash
docker ps
```

Test health:

```bash
curl http://127.0.0.1:8080/health
```

Windows PowerShell:

```powershell
Invoke-RestMethod http://127.0.0.1:8080/health
```

Inspect resources:

```bash
docker stats cloud-operations-lab --no-stream
```

Inspect processes:

```bash
docker top cloud-operations-lab
```

Inspect filesystem:

```bash
docker exec cloud-operations-lab df -h /
```

Inspect DNS:

```bash
docker exec cloud-operations-lab cat /etc/resolv.conf
```

Inspect logs:

```bash
docker logs cloud-operations-lab
```

Stop:

```bash
docker compose down
```

## Current Resource Controls

The lab currently uses:

```yaml
mem_limit: 256m
```

This limits the impact of memory experiments on the host system.

## Project Structure

```text
CLOUD-OPERATIONS-LAB/
|
+-- app/
|   +-- main.py
|
+-- incidents/
|   +-- 01-service-unreachable-wrong-port.md
|   +-- 02-container-healthcheck-failure.md
|   +-- 03-application-process-restart-loop.md
|   +-- 04-high-cpu-usage.md
|   +-- 05-memory-pressure.md
|   +-- 06-log-growth-disk-pressure.md
|   +-- 07-dns-resolution-failure.md
|
+-- docs/
|   +-- images/
|
+-- scripts/
|
+-- Dockerfile
+-- docker-compose.yml
+-- requirements.txt
+-- .gitignore
+-- README.md
```

## Incident Documentation Standard

Each incident contains:

```text
1. Summary
2. Impact
3. Expected behavior
4. Symptoms
5. Investigation
6. Commands used
7. Root cause
8. Resolution
9. Verification
10. Prevention
```

## Skills Demonstrated

This lab demonstrates practical work with:

- container troubleshooting
- Docker networking
- port publishing
- Docker health checks
- application health checks
- process troubleshooting
- restart loops
- application entrypoints
- CPU troubleshooting
- memory troubleshooting
- filesystem troubleshooting
- log growth analysis
- DNS troubleshooting
- TCP connectivity testing
- network-layer isolation
- Linux PID namespaces
- `/proc` inspection
- container resource limits
- root-cause analysis
- incident response
- operational documentation
- Git-based project management

## Portfolio Goal

This repository demonstrates troubleshooting skills relevant to roles such as:

- Cloud Support Engineer
- Junior Cloud Engineer
- DevOps Engineer
- Systems Administrator
- Infrastructure Support Engineer
- Site Reliability Engineering intern or junior roles

The focus is not only on building systems, but on diagnosing failures methodically and proving recovery with observable evidence.

## Status

Active hands-on cloud operations and incident-response lab.

**Completed incidents: 7**