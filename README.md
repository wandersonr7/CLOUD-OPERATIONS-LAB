# Cloud Operations Lab

Cloud Operations Lab is a hands-on troubleshooting and incident-response environment designed to practice Linux, containers, networking, monitoring, logging, and cloud operations.

The project intentionally creates operational failures and documents how to investigate, identify, fix, verify, and prevent them.

## Purpose

Many infrastructure projects demonstrate how to deploy a service.

This lab focuses on what happens when the service stops working or when infrastructure reports an incorrect operational state.

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

## Incident Progress

| Incident | Scenario | Status |
|---|---|---|
| 01 | Service unreachable due to incorrect Docker port mapping | Completed |
| 02 | Container health check failure | Completed |
| 03 | Application process failure and restart loop | Completed |
| 04 | High CPU usage | Completed |
| 05 | Memory pressure | Planned |
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

The service was tested independently from inside the container, confirming that the application itself was healthy.

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

The application remained available and returned a successful health response, but Docker reported the container as:

```text
unhealthy
```

Application test:

```powershell
Invoke-RestMethod http://127.0.0.1:8080/health
```

Result:

```text
status
------
ok
```

The investigation showed that Docker was testing:

```text
127.0.0.1:9999/health
```

while Flask was actually listening on:

```text
127.0.0.1:8080
```

The health-check execution history showed repeated:

```text
ConnectionRefusedError
ExitCode=1
```

Root cause:

```text
Incorrect health-check port
```

After correcting the health-check endpoint and recreating the container, Docker reported:

```text
healthy
```

Full incident report:

[Incident 02 — Container Health Check Failure](incidents/02-container-healthcheck-failure.md)

---

### Incident 03 — Application Process Failure and Restart Loop

The container was successfully created, but the application never became available.

Docker repeatedly restarted the container.

Observed:

```text
Restarting (...)
```

Logs showed:

```text
python: can't open file '/app/app/missing.py': [Errno 2] No such file or directory
```

The container command was:

```json
["python","app/missing.py"]
```

The restart count increased as Docker continuously attempted to start the invalid command.

Root cause:

```text
Invalid application entrypoint
```

After removing the invalid command override, the container returned to:

```dockerfile
CMD ["python", "app/main.py"]
```

Verification:

```text
Container status: healthy
Application health: ok
RestartCount: 0
```

Full incident report:

[Incident 03 — Application Process Failure and Restart Loop](incidents/03-application-process-restart-loop.md)

---

### Incident 04 — High CPU Usage

The container remained healthy and the application continued responding, but CPU utilization reached almost 100%.

Observed with:

```powershell
docker stats cloud-operations-lab --no-stream
```

Result:

```text
CPU: 99.82%
```

At the same time:

```powershell
Invoke-RestMethod http://127.0.0.1:8080/health
```

continued returning:

```text
ok
```

Process inspection showed:

```text
python app/main.py
```

using essentially no CPU.

A second Python process was consuming approximately:

```text
99.9% CPU
```

The command contained:

```python
while True:
    pass
```

This identified the source of the CPU saturation.

The process was terminated using its PID inside the container.

After remediation:

```text
CPU: 0.01%
PIDS: 1
Application health: ok
```

This incident demonstrated that:

```text
Application health != Resource health
```

A service may respond successfully while operating under severe resource pressure.

It also demonstrated Linux PID namespaces. The same process appeared with different PID values inside the container and from the host.

Full incident report:

[Incident 04 — High CPU Usage](incidents/04-high-cpu-usage.md)

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

Resource-related incidents add another dimension:

```text
Application availability
        |
        +--> health endpoint

Container state
        |
        +--> running / healthy

Resource state
        |
        +--> CPU
        +--> memory
        +--> disk
        +--> process count
```

Different operational signals must be evaluated independently.

For example:

```text
Application health != Container health status
Container running   != Application running
Health endpoint ok  != Resource usage normal
```

This approach helps isolate failures instead of changing multiple components before the root cause is understood.

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
- `/proc`
- HTTP
- TCP/IP
- Git
- PowerShell

Planned additions:

- additional Linux troubleshooting tools
- memory analysis
- disk inspection
- system logs
- DNS tools
- Prometheus
- Grafana
- GitHub Actions
- AWS CloudWatch
- AWS ECS
- Terraform

## Run the Lab

Build and start the service:

```bash
docker compose up -d --build
```

Check the running container:

```bash
docker ps
```

A healthy container should eventually show:

```text
(healthy)
```

Test the health endpoint:

```bash
curl http://127.0.0.1:8080/health
```

Windows PowerShell:

```powershell
Invoke-RestMethod http://127.0.0.1:8080/health
```

Expected result:

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

Inspect container state:

```bash
docker inspect cloud-operations-lab
```

Stop the lab:

```bash
docker compose down
```

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
- entrypoint troubleshooting
- CPU troubleshooting
- process-level resource analysis
- Linux PID namespaces
- `/proc` inspection
- Docker resource metrics
- log inspection
- configuration troubleshooting
- service isolation
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

**Completed incidents: 4**