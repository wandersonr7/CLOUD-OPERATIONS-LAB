\# Incident 08 — Internal Network Connectivity Failure



\## Summary



A dependency container remained running and resolvable through Docker DNS, but its application port stopped accepting TCP connections.



The main Cloud Operations Lab application remained healthy.



The incident was caused by the dependency's HTTP server process being terminated while the container itself continued running.



This demonstrated the difference between:



```text

Container availability

Service availability

DNS resolution

TCP connectivity

HTTP availability

```



\---



\## Architecture



Two containers were connected to the same Docker network:



```text

cloud-operations-lab

&#x20;       |

&#x20;       | Docker network

&#x20;       |

&#x20;       v

lab-dependency:9090

```



The dependency ran:



```text

python -m http.server 9090

```



Docker DNS allowed the main application container to resolve:



```text

lab-dependency

```



to its internal container IP.



\---



\## Baseline



The dependency container was running:



```text

lab-dependency   Up

```



DNS resolution succeeded:



```text

lab-dependency -> 172.19.0.3

```



TCP connectivity succeeded:



```text

TCP lab-dependency:9090 = OK

```



HTTP connectivity succeeded:



```text

HTTP STATUS: 200

```



The main application was also healthy:



```text

status

\------

ok

```



\---



\## Symptoms



The HTTP server process inside the dependency container was terminated.



The dependency container itself continued running.



Docker still reported:



```text

lab-dependency   Up

```



DNS resolution also continued to succeed:



```text

lab-dependency -> 172.19.0.3

```



However, TCP connections to:



```text

lab-dependency:9090

```



failed.



Observed:



```text

ConnectionRefusedError: \[Errno 111] Connection refused

```



\---



\## Investigation



\### 1. Confirm dependency container state



Command:



```powershell

docker ps --filter "name=lab-dependency" --format "table {{.Names}}\\t{{.Status}}"

```



Observed:



```text

lab-dependency   Up

```



This confirmed that the container itself had not stopped.



\---



\### 2. Verify DNS resolution



Command:



```powershell

docker exec cloud-operations-lab python -c "import socket; print('lab-dependency ->', socket.gethostbyname('lab-dependency'))"

```



Observed:



```text

lab-dependency -> 172.19.0.3

```



Docker DNS was operating normally.



\---



\### 3. Test TCP connectivity



Command:



```powershell

docker exec cloud-operations-lab python -c "import socket; s=socket.create\_connection(('lab-dependency',9090),3); print('TCP = OK'); s.close()"

```



Observed:



```text

ConnectionRefusedError: \[Errno 111] Connection refused

```



The destination host was reachable, but nothing was listening on TCP port `9090`.



\---



\### 4. Verify main application health



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



The main application was unaffected.



\---



\### 5. Inspect processes inside the dependency



Command:



```powershell

docker top lab-dependency

```



Observed processes included:



```text

sh -c ...

tail -f /dev/null

```



The expected process:



```text

python -m http.server 9090

```



was missing.



This identified the actual failure.



\---



\## Root Cause



The dependency container used a long-running process:



```text

tail -f /dev/null

```



to keep the container alive.



The HTTP server ran as a separate background process:



```text

python -m http.server 9090

```



When the HTTP process was terminated:



```text

Container        remained running

Docker DNS       remained functional

Container IP     remained reachable

TCP port 9090    stopped listening

HTTP service     became unavailable

```



The root cause was therefore:



```text

Dependency application process stopped

```



rather than:



```text

Container failure

DNS failure

Docker network failure

```



\---



\## Connection Refused vs Timeout



The observed error was:



```text

Connection refused

```



This is significant.



A refused connection generally indicates:



```text

Destination reachable

&#x20;       |

&#x20;       v

TCP stack responds

&#x20;       |

&#x20;       v

No service listening on requested port

```



This differs from a timeout, which may indicate:



```text

Packet filtering

Routing failure

Network outage

Unreachable destination

```



\---



\## Resolution



The HTTP listener was restarted inside the dependency container:



```powershell

docker exec lab-dependency sh -c 'python -m http.server 9090 >/tmp/http.log 2>\&1 \& echo $! >/tmp/http.pid'

```



The service began listening on port `9090` again.



\---



\## Verification



DNS resolution was tested again:



```text

lab-dependency -> Docker network IP

```



TCP connectivity returned:



```text

TCP lab-dependency:9090 = OK

```



HTTP returned:



```text

HTTP STATUS: 200

```



The main application remained:



```text

healthy

```



\---



\## Layer Isolation



The incident demonstrated the following diagnostic model:



```text

Container state

&#x20;     |

&#x20;     +--> Is the container running?



DNS

&#x20;     |

&#x20;     +--> Does the hostname resolve?



Network path

&#x20;     |

&#x20;     +--> Can the destination IP be reached?



TCP

&#x20;     |

&#x20;     +--> Is the destination port accepting connections?



Application

&#x20;     |

&#x20;     +--> Is the service responding correctly?



HTTP

&#x20;     |

&#x20;     +--> Is the expected application protocol working?

```



During the incident:



```text

Container    OK

DNS          OK

Network      OK

TCP :9090    FAIL

HTTP         FAIL

Main app     OK

```



\---



\## Prevention



Possible prevention measures include:



\- add health checks to dependency containers

\- monitor service ports rather than container state alone

\- monitor process state

\- restart failed application processes

\- use process supervisors where appropriate

\- configure orchestration health checks

\- alert on dependency connection failures

\- monitor service-level availability



In orchestrated environments such as ECS or Kubernetes, health checks can cause unhealthy tasks or containers to be replaced automatically.



\---



\## Troubleshooting Flow



```text

Dependency unreachable

&#x20;       |

&#x20;       v

Check container state

&#x20;       |

&#x20;       v

Check DNS

&#x20;       |

&#x20;       v

Test TCP connection

&#x20;       |

&#x20;       v

Inspect processes

&#x20;       |

&#x20;       v

Identify missing listener

&#x20;       |

&#x20;       v

Restart service

&#x20;       |

&#x20;       v

Verify TCP and HTTP

```



\---



\## Commands Used



```text

docker run

docker ps

docker exec

docker top

socket.gethostbyname

socket.create\_connection

urllib.request

Invoke-RestMethod

```



\---



\## Status



Resolved.

