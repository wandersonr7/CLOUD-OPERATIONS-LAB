\# Incident 02 — Container Health Check Failure



\## Summary



The Cloud Operations Lab application was running and responding successfully, but Docker reported the container as unhealthy.



The incident was caused by an incorrectly configured Docker health check.



The application was listening on container port `8080`, while the Docker health check attempted to connect to port `9999`.



\---



\## Impact



The application remained available to users, but the container health status was:



```text

unhealthy

```



In a production environment, an incorrect health check could cause:



\- unnecessary container restarts

\- failed deployments

\- load balancer target removal

\- ECS task replacement

\- misleading monitoring alerts



\---



\## Symptoms



Docker reported:



```text

cloud-operations-lab   Up ... (unhealthy)

```



However, the application health endpoint still worked:



```powershell

Invoke-RestMethod http://127.0.0.1:8080/health

```



Observed:



```text

status

\------

ok

```



This indicated that the application itself was operational.



\---



\## Investigation



\### 1. Check container health status



Command:



```powershell

docker ps --filter "name=cloud-operations-lab" --format "table {{.Names}}\\t{{.Status}}\\t{{.Ports}}"

```



Observed:



```text

cloud-operations-lab   Up ... (unhealthy)   0.0.0.0:8080->8080/tcp

```



The container was running, but Docker considered it unhealthy.



\---



\### 2. Test the application directly



Command:



```powershell

Invoke-RestMethod http://127.0.0.1:8080/health

```



Observed:



```text

status

\------

ok

```



This confirmed that the application was still available.



\---



\### 3. Inspect the Docker health check configuration



Command:



```powershell

docker inspect cloud-operations-lab --format '{{json .Config.Healthcheck}}'

```



Observed health check:



```text

http://127.0.0.1:9999/health

```



The application was not listening on port `9999`.



\---



\### 4. Inspect health-check execution history



Command:



```powershell

docker inspect cloud-operations-lab --format '{{range .State.Health.Log}}{{.End}} | ExitCode={{.ExitCode}} | {{.Output}}{{println}}{{end}}'

```



Observed:



```text

ExitCode=1

ConnectionRefusedError: \[Errno 111] Connection refused

```



Repeated health-check attempts failed because nothing was listening on port `9999`.



\---



\## Root Cause



The Docker Compose health check contained an incorrect application port.



Incorrect:



```yaml

healthcheck:

&#x20; test:

&#x20;   - CMD

&#x20;   - python

&#x20;   - -c

&#x20;   - "import urllib.request; urllib.request.urlopen('http://127.0.0.1:9999/health', timeout=2)"

```



The Flask application actually listens on:



```text

127.0.0.1:8080

```



Therefore Docker was testing the wrong endpoint.



\---



\## Resolution



The health check was changed to use port `8080`.



Correct configuration:



```yaml

healthcheck:

&#x20; test:

&#x20;   - CMD

&#x20;   - python

&#x20;   - -c

&#x20;   - "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/health', timeout=2)"

```



The container was then recreated.



\---



\## Verification



After recreating the container, Docker should report:



```text

healthy

```



The application health endpoint should continue returning:



```json

{

&#x20; "status": "ok"

}

```



\---



\## Prevention



Possible prevention measures include:



\- keep application ports defined consistently

\- review health-check endpoints during configuration changes

\- test health checks during CI

\- validate Docker health status after deployment

\- use configuration variables instead of duplicated port values

\- monitor both application health and container health



\---



\## Troubleshooting Lessons



An application can be healthy while its container health status is unhealthy.



These are separate signals:



```text

Application health

&#x20;       |

&#x20;       +--> Is the service responding?



Container health check

&#x20;       |

&#x20;       +--> Is Docker testing the correct endpoint?

```



Health-check failures should therefore be investigated independently from application availability.



\---



\## Commands Used



```text

docker ps

docker inspect

Invoke-RestMethod

```



\---



\## Status



Resolved.

