# Cloud Operations Lab

Cloud Operations Lab is a hands-on troubleshooting and incident-response environment designed to practice Linux, containers, networking, monitoring, logging, and cloud operations.

The project intentionally creates operational failures and documents how to investigate, identify, fix, verify, and prevent them.

## Purpose

Many infrastructure projects demonstrate how to deploy a service.

This lab focuses on what happens when the service stops working, when infrastructure reports an incorrect operational state, or when the application remains available while the underlying system is under stress.

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
| 07 | DNS resolution failure | Planned |
| 08 | Network connectivity failure | Planned |

## Completed Incidents

### Incident 01 — Service Unreachable Due to Incorrect Docker Port Mapping

The application was healthy inside the container but unreachable from the host.

Observed:

```text
Host 8080 -> Container 8081
```

Actual listener:

```text
Container 8080
```

Root cause:

```text
Incorrect Docker Compose port mapping
```

Full report:

[Incident 01 — Service Unreachable Due to Incorrect Docker Port Mapping](incidents/01-service-unreachable-wrong-port.md)

---

### Incident 02 — Container Health Check Failure

The application remained available but Docker reported:

```text
unhealthy
```

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

After correction:

```text
Container health: healthy
Application health: ok
```

Full report:

[Incident 02 — Container Health Check Failure](incidents/02-container-healthcheck-failure.md)

---

### Incident 03 — Application Process Failure and Restart Loop

The container was created successfully but the application did not start.

Docker repeatedly restarted the container.

Logs showed:

```text
python: can't open file '/app/app/missing.py': [Errno 2] No such file or directory
```

The configured command was:

```json
["python","app/missing.py"]
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

The application remained healthy while container CPU utilization reached nearly 100%.

Observed:

```text
CPU: 99.82%
```

Process inspection identified a Python process consuming approximately:

```text
99.9% CPU
```

The process contained:

```python
while True:
    pass
```

After termination:

```text
CPU: 0.01%
PIDS: 1
Application health: ok
```

This demonstrated:

```text
Application health != Resource health
```

Full report:

[Incident 04 — High CPU Usage](incidents/04-high-cpu-usage.md)

---

### Incident 05 — Memory Pressure

The container remained healthy while memory utilization rose above 80%.

Memory limit:

```text
256 MiB
```

During the incident:

```text
Memory: 213.3 MiB / 256 MiB
Usage: 83.31%
PIDS: 2
Application health: ok
```

A background Python process had allocated approximately:

```text
180 MiB
```

After termination:

```text
Memory: 28.97 MiB / 256 MiB
Usage: 11.32%
PIDS: 1
Application health: ok
```

Full report:

[Incident 05 — Memory Pressure](incidents/05-memory-pressure.md)

---

### Incident 06 — Log Growth and Disk Pressure

The application remained healthy while a simulated log file caused significant growth in the container writable filesystem.

Baseline:

```text
/var/log: 212K
```

A simulated application log grew to:

```text
64M
```

The log directory increased to:

```text
65M
```

Docker reported the writable container layer as:

```text
67.1MB
```

The application still returned:

```text
ok
```

The large file was identified using:

```text
df
du
ls
docker ps -s
```

The main evidence was:

```text
/var/log/cloud-operations-lab.log   64M
```

After the oversized log was removed:

```text
/var/log:        212K
Writable layer:  20.5kB
Application:     healthy
```

This demonstrated that high-level filesystem percentages may hide abnormal local growth.

The container filesystem was large enough that the `64 MiB` increase did not visibly change:

```text
df -h
```

from `1%`.

Targeted inspection with:

```text
du
ls
docker ps -s
```

provided the useful evidence.

Full report:

[Incident 06 — Log Growth and Disk Pressure](incidents/06-log-growth-disk-pressure.md)

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
Container Network
    |
    v
Port Publishing
    |
    v
Host Network
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
```

## Lab Areas

The project covers or plans scenarios involving:

- service availability
- incorrect application ports
- container health checks
- application crashes
- restart loops
- CPU saturation
- memory pressure
- log growth
- disk pressure
- DNS resolution
- TCP connectivity
- HTTP errors
- permissions
- configuration errors
- monitoring
- alerting
- incident documentation

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
- container resource limits
- HTTP
- TCP/IP
- Git
- PowerShell

Planned additions:

- DNS tools
- network diagnostic tools
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

Test the health endpoint:

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

Inspect filesystem usage:

```bash
docker exec cloud-operations-lab df -h /
```

Inspect directory sizes:

```bash
docker exec cloud-operations-lab du -sh /var/log
```

Inspect the writable container layer:

```bash
docker ps -s
```

Inspect logs:

```bash
docker logs cloud-operations-lab
```

Stop the lab:

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
- container restart loops
- application entrypoints
- CPU troubleshooting
- memory troubleshooting
- filesystem troubleshooting
- log growth analysis
- container writable-layer analysis
- container resource limits
- Linux PID namespaces
- `/proc` inspection
- `df`
- `du`
- log inspection
- configuration troubleshooting
- root-cause analysis
- incident response
- HTTP troubleshooting
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

The focus is not only on building systems, but on understanding how to diagnose and recover them when something goes wrong.

## Status

Active hands-on cloud operations and incident-response lab.

**Completed incidents: 6**