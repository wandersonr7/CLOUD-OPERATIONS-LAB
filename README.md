# Cloud Operations Lab

Cloud Operations Lab is a hands-on troubleshooting and incident-response environment designed to practice Linux, containers, networking, monitoring, logging, and cloud operations.

The project intentionally creates operational failures and documents how to investigate, identify, fix, verify, and prevent them.

## Purpose

Many infrastructure projects demonstrate how to deploy a service.

This lab focuses on what happens when the service stops working, when infrastructure reports an incorrect operational state, or when the application is available but operating under resource pressure.

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

The lab currently runs a small Flask application inside Docker.

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

The normal network path is:

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

Docker also monitors the application through a container health check:

```text
Docker Health Check
        |
        v
127.0.0.1:8080/health
        |
        v
Flask
        |
        v
healthy
```

The container currently has a memory limit:

```text
256 MiB
```

This keeps memory experiments isolated from the host system.

## Incident Progress

| Incident | Scenario | Status |
|---|---|---|
| 01 | Service unreachable due to incorrect Docker port mapping | Completed |
| 02 | Container health check failure | Completed |
| 03 | Application process failure and restart loop | Completed |
| 04 | High CPU usage | Completed |
| 05 | Memory pressure | Completed |
| 06 | Log growth / disk pressure | Planned |
| 07 | DNS resolution failure | Planned |
| 08 | Network connectivity failure | Planned |

## Completed Incidents

### Incident 01 — Service Unreachable Due to Incorrect Docker Port Mapping

The application was healthy inside the container but unreachable from the host.

Observed Docker mapping:

```text
Host 8080 -> Container 8081
```

Actual application listener:

```text
Container 8080
```

Investigation used:

```text
docker ps
docker logs
docker inspect
docker exec
Invoke-RestMethod
```

Root cause:

```text
Incorrect Docker Compose port mapping
```

Incorrect configuration:

```yaml
ports:
  - "8080:8081"
```

Correct configuration:

```yaml
ports:
  - "8080:8080"
```

Full incident report:

[Incident 01 — Service Unreachable Due to Incorrect Docker Port Mapping](incidents/01-service-unreachable-wrong-port.md)

---

### Incident 02 — Container Health Check Failure

The application remained available but Docker reported:

```text
unhealthy
```

The application itself continued returning:

```text
ok
```

The investigation showed that Docker was testing:

```text
127.0.0.1:9999/health
```

while Flask was listening on:

```text
127.0.0.1:8080
```

The Docker health-check history showed repeated:

```text
ConnectionRefusedError
ExitCode=1
```

Root cause:

```text
Incorrect health-check port
```

After correcting the endpoint, Docker returned to:

```text
healthy
```

Full incident report:

[Incident 02 — Container Health Check Failure](incidents/02-container-healthcheck-failure.md)

---

### Incident 03 — Application Process Failure and Restart Loop

The container was successfully created, but the application did not start.

Docker repeatedly restarted the container.

Observed:

```text
Restarting (...)
```

Logs showed:

```text
python: can't open file '/app/app/missing.py': [Errno 2] No such file or directory
```

The container was configured to execute:

```json
["python","app/missing.py"]
```

The restart count increased as Docker retried the failed process.

Root cause:

```text
Invalid application entrypoint
```

After removing the invalid command override:

```text
Container status: healthy
Application health: ok
RestartCount: 0
```

Full incident report:

[Incident 03 — Application Process Failure and Restart Loop](incidents/03-application-process-restart-loop.md)

---

### Incident 04 — High CPU Usage

The application remained healthy while container CPU utilization reached nearly 100%.

Observed:

```text
CPU: 99.82%
```

Application health remained:

```text
ok
```

Process inspection identified a second Python process consuming approximately:

```text
99.9% CPU
```

The process contained:

```python
while True:
    pass
```

The Flask application itself was using essentially no CPU.

After terminating the CPU-bound process:

```text
CPU: 0.01%
PIDS: 1
Application health: ok
```

This demonstrated that:

```text
Application health != Resource health
```

Full incident report:

[Incident 04 — High CPU Usage](incidents/04-high-cpu-usage.md)

---

### Incident 05 — Memory Pressure

The container remained healthy and the application continued responding while memory utilization rose above 80%.

The container memory limit was:

```text
256 MiB
```

Verified through Docker:

```text
MemoryLimit=268435456 bytes
```

A background Python process allocated approximately:

```text
180 MiB
```

Docker reported:

```text
Memory: 213.3 MiB / 256 MiB
Usage: 83.31%
PIDS: 2
```

At the same time:

```text
Application health: ok
CPU usage: normal
```

The memory-consuming process was identified through:

```text
docker stats
docker top
docker exec
/proc
```

Its internal container PID was:

```text
85
```

The process command showed a large allocation:

```python
data = bytearray(180 * 1024 * 1024)
```

After terminating the process:

```text
Memory: 28.97 MiB / 256 MiB
Usage: 11.32%
PIDS: 1
Application health: ok
```

Only the normal Flask process remained:

```text
python app/main.py
```

The incident demonstrated that:

```text
Application health != Memory health
```

and showed how container memory limits reduce the blast radius of faulty processes.

Full incident report:

[Incident 05 — Memory Pressure](incidents/05-memory-pressure.md)

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

Resource incidents add additional dimensions:

```text
Operational Health
       |
       +--> Availability
       |
       +--> CPU
       |
       +--> Memory
       |
       +--> Disk
       |
       +--> Network
       |
       +--> Logs
```

Different signals are evaluated independently.

For example:

```text
Application health != Container health status
Container running   != Application running
Health endpoint ok  != CPU usage normal
Health endpoint ok  != Memory usage normal
```

This approach helps isolate failures before changes are made.

## Lab Areas

The project covers or plans scenarios involving:

- service availability
- incorrect application ports
- container health checks
- application crashes
- restart loops
- CPU saturation
- memory pressure
- excessive log growth
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
- container resource limits
- HTTP
- TCP/IP
- Git
- PowerShell

Planned additions:

- disk inspection
- filesystem troubleshooting
- system logs
- DNS tools
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

A healthy container should show:

```text
(healthy)
```

Test the application:

```bash
curl http://127.0.0.1:8080/health
```

Windows PowerShell:

```powershell
Invoke-RestMethod http://127.0.0.1:8080/health
```

Expected:

```text
status
------
ok
```

Inspect resource usage:

```bash
docker stats cloud-operations-lab --no-stream
```

Inspect processes:

```bash
docker top cloud-operations-lab
```

Inspect logs:

```bash
docker logs cloud-operations-lab
```

Inspect container configuration:

```bash
docker inspect cloud-operations-lab
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

This intentionally limits container memory consumption during troubleshooting exercises.

Future incidents may introduce additional resource controls.

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
- container resource limits
- process-level resource analysis
- Linux PID namespaces
- `/proc` inspection
- Docker resource metrics
- log inspection
- configuration troubleshooting
- root-cause analysis
- incident response
- HTTP troubleshooting
- network troubleshooting
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

**Completed incidents: 5**