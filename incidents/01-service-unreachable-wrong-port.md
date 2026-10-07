\# Incident 01 — Service Unreachable Due to Incorrect Docker Port Mapping



\## Summary



The Cloud Operations Lab application was running successfully inside its Docker container, but requests from the host machine to the published application port failed.



The incident was caused by an incorrect Docker port mapping.



The host port `8080` was incorrectly mapped to container port `8081`, while the Flask application was listening on container port `8080`.



\---



\## Impact



Users attempting to access:



```text

http://127.0.0.1:8080

```



could not reach the application.



The application itself remained healthy inside the container.



\---



\## Expected Behavior



The application should be reachable through:



```text

Host 8080 -> Container 8080

```



The health endpoint should return:



```json

{

&#x20; "status": "ok"

}

```



\---



\## Symptoms



A request from the host failed:



```powershell

Invoke-RestMethod http://127.0.0.1:8080/health

```



Observed error:



```text

The underlying connection was closed:

The connection was closed unexpectedly.

```



Docker showed the container as running.



\---



\## Investigation



\### 1. Check container status and published ports



Command:



```powershell

docker ps --filter "name=cloud-operations-lab" --format "table {{.Names}}\\t{{.Status}}\\t{{.Ports}}"

```



Observed:



```text

cloud-operations-lab   Up   0.0.0.0:8080->8081/tcp

```



This showed that host port `8080` was forwarded to container port `8081`.



\---



\### 2. Check application logs



Command:



```powershell

docker logs cloud-operations-lab

```



Observed:



```text

Running on all addresses (0.0.0.0)

Running on http://127.0.0.1:8080

Running on http://172.19.0.2:8080

```



The logs confirmed that Flask was listening on port `8080` inside the container.



\---



\### 3. Inspect Docker network port mapping



Command:



```powershell

docker inspect cloud-operations-lab --format '{{json .NetworkSettings.Ports}}'

```



Observed:



```json

{

&#x20; "8081/tcp": \[

&#x20;   {

&#x20;     "HostIp": "0.0.0.0",

&#x20;     "HostPort": "8080"

&#x20;   },

&#x20;   {

&#x20;     "HostIp": "::",

&#x20;     "HostPort": "8080"

&#x20;   }

&#x20; ]

}

```



Docker was forwarding traffic from host port `8080` to container port `8081`.



\---



\### 4. Test the service from inside the container



Command:



```powershell

docker exec cloud-operations-lab python -c "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8080/health').read().decode())"

```



Observed:



```json

{"status":"ok"}

```



This confirmed that:



\- the container was running

\- Flask was running

\- the application was healthy

\- the failure existed between the host port and the container port



\---



\## Root Cause



The Docker Compose configuration contained:



```yaml

ports:

&#x20; - "8080:8081"

```



Docker Compose port mappings use:



```text

HOST\_PORT:CONTAINER\_PORT

```



Therefore the configuration instructed Docker to forward:



```text

Host port 8080

&#x20;     |

&#x20;     v

Container port 8081

```



However, the Flask application was listening on:



```text

Container port 8080

```



Nothing was listening on container port `8081`.



\---



\## Resolution



The Docker Compose port mapping was corrected to:



```yaml

ports:

&#x20; - "8080:8080"

```



The container was then recreated.



\---



\## Verification



The corrected architecture is:



```text

Client

&#x20;  |

&#x20;  v

127.0.0.1:8080

&#x20;  |

&#x20;  v

Docker published port

&#x20;  |

&#x20;  v

Container :8080

&#x20;  |

&#x20;  v

Flask application

```



The health endpoint was tested again:



```powershell

Invoke-RestMethod http://127.0.0.1:8080/health

```



Expected result:



```text

status

\------

ok

```



\---



\## Prevention



Possible prevention measures include:



\- document expected host and container ports

\- verify Docker Compose configuration during code review

\- add automated health checks

\- validate container connectivity after deployment

\- include integration tests that access the service through the published host port

\- monitor application health endpoints



\---



\## Troubleshooting Lessons



This incident demonstrates why a running container does not necessarily mean that an application is reachable.



The investigation separated the system into layers:



```text

Application process

&#x20;       |

&#x20;       v

Container networking

&#x20;       |

&#x20;       v

Docker port publishing

&#x20;       |

&#x20;       v

Host networking

&#x20;       |

&#x20;       v

Client

```



Testing each layer independently made it possible to isolate the failure.



\---



\## Commands Used



```text

docker ps

docker logs

docker inspect

docker exec

Invoke-RestMethod

```



\---



\## Status



Resolved.

