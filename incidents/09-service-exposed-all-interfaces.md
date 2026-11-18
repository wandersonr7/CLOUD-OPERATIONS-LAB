# Incident 09 — Service Exposed on All Network Interfaces

## Summary

A review of the services running on the lab host found that the Cloud Operations Lab container was published on every host network interface instead of only the loopback interface.

The application was healthy and working as expected. The problem was not availability, it was exposure: any device that could reach the host on port `8080` could reach the service.

The cause was the Docker Compose port mapping `"8080:8080"`, which Docker binds to `0.0.0.0` (and `[::]` for IPv6) when no host IP is given.

---

## Impact

No outage occurred. Every health signal stayed green.

The risk was security-related:

- the service was reachable from the local network, not only from the host
- the lab is a troubleshooting environment, not a hardened service
- the lab deliberately runs fault-injection scenarios, so it should never be reachable from other machines
- in a cloud environment, the same mistake combined with an open security group would publish the service to the internet

---

## Expected Behavior

The lab is meant to be used only from the host machine.

Expected binding:

```text
127.0.0.1:8080 -> container :8080
```

---

## Symptoms

There were no functional symptoms. The health check passed and the application answered normally:

```json
{
  "status": "ok"
}
```

This is what makes the issue easy to miss: an exposure problem does not show up in availability monitoring.

---

## Investigation

### 1. Check published ports

Command:

```bash
docker port cloud-operations-lab
```

Observed:

```text
8080/tcp -> 0.0.0.0:8080
8080/tcp -> [::]:8080
```

The service was published on every IPv4 and IPv6 interface.

---

### 2. Inspect the port binding configuration

Command:

```bash
docker inspect cloud-operations-lab --format '{{json .HostConfig.PortBindings}}'
```

Observed:

```json
{"8080/tcp":[{"HostIp":"","HostPort":"8080"}]}
```

`HostIp` was empty. Docker treats an empty host IP as "all interfaces".

---

### 3. Confirm from the host operating system

Command (Windows host):

```powershell
netstat -ano | findstr ":8080" | findstr LISTENING
```

Observed:

```text
TCP    0.0.0.0:8080           0.0.0.0:0              LISTENING
TCP    [::]:8080              [::]:0                 LISTENING
```

The host itself confirmed the listener was open on all interfaces.

---

## Root Cause

The Docker Compose file published the port without a host IP:

```yaml
ports:
  - "8080:8080"
```

The short syntax `HOST:CONTAINER` binds to `0.0.0.0` by default.

---

## Resolution

The port mapping was restricted to the loopback interface:

```yaml
ports:
  - "127.0.0.1:8080:8080"
```

The container was then recreated:

```bash
docker compose up -d --force-recreate
```

---

## Verification

Published ports after the fix:

```text
8080/tcp -> 127.0.0.1:8080
```

Port binding configuration:

```json
{"8080/tcp":[{"HostIp":"127.0.0.1","HostPort":"8080"}]}
```

Host listener:

```text
TCP    127.0.0.1:8080         0.0.0.0:0              LISTENING
```

Application health:

```json
{"status":"ok"}
```

The service stayed fully available to the host and stopped being reachable from other machines.

---

## Prevention

- always include the host IP in Compose port mappings for local-only services
- add an automated check that fails when a lab service is bound to `0.0.0.0` (now part of `chaos/lab.sh verify`)
- review listening ports periodically (`docker port`, `netstat`, `ss -tlnp`)
- in the cloud, pair private bindings with restrictive security groups and no public IP by default
- treat exposure as its own signal, separate from health

---

## Troubleshooting Lessons

Availability monitoring cannot detect exposure problems.

```text
Health check ok    != Safely exposed
Service reachable  != Reachable only by the intended clients
"8080:8080"        == 0.0.0.0:8080
```

Security posture needs its own checks, just like CPU, memory, disk and DNS.

---

## Reproduce

```bash
chaos/lab.sh drill 09
```

The drill publishes the service on all interfaces, confirms the exposure through `docker port`, restores the loopback-only binding and re-runs every baseline check.

---

## Commands Used

```text
docker port
docker inspect
netstat
docker compose up --force-recreate
curl
```

---

## Status

Resolved.
