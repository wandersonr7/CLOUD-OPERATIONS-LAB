# Cloud Operations Lab

Cloud Operations Lab is a hands-on troubleshooting and incident-response environment designed to practice Linux, containers, networking, monitoring, logging, and cloud operations.

The project intentionally creates operational failures and documents how to investigate, identify, fix, verify, and prevent them.

## Purpose

Many infrastructure projects demonstrate how to deploy a service.

This lab focuses on what happens when the service stops working.

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

The default network path is:

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

## Incident Progress

| Incident | Scenario | Status |
|---|---|---|
| 01 | Service unreachable due to incorrect Docker port mapping | Completed |
| 02 | Container health check failure | Planned |
| 03 | Application process failure | Planned |
| 04 | High CPU usage | Planned |
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

This approach helps isolate failures instead of making changes before the root cause is understood.

## Lab Areas

The project will cover scenarios involving:

- service availability
- incorrect application ports
- container health checks
- application crashes
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
- HTTP
- TCP/IP
- Git
- PowerShell

Planned additions:

- Linux troubleshooting tools
- process inspection
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
- application health checks
- log inspection
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

**Completed incidents: 1**