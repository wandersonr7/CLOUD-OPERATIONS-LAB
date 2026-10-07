\# Incident 07 — DNS Resolution Failure



\## Summary



The Cloud Operations Lab container lost DNS resolution while general TCP connectivity remained functional.



The application itself remained healthy and accessible from the host.



The incident was caused by replacing the container DNS resolver with a non-functional nameserver.



This demonstrated how to distinguish a DNS failure from a general networking or application failure.



\---



\## Impact



Applications that depend on hostnames would be unable to reach external services.



Examples include:



```text

api.example.com

database.example.internal

auth.example.com

```



Services accessed directly by IP address could still remain reachable.



The local Flask application was unaffected because it did not require external DNS resolution for its health endpoint.



\---



\## Baseline



Docker originally configured the container resolver as:



```text

nameserver 127.0.0.11

```



Docker's internal DNS resolver forwarded queries to the configured host DNS infrastructure.



The baseline DNS test succeeded:



```powershell

docker exec cloud-operations-lab python -c "import socket; print('example.com ->', socket.gethostbyname('example.com'))"

```



Observed:



```text

example.com -> 104.20.23.154

```



Direct TCP connectivity also worked:



```powershell

docker exec cloud-operations-lab python -c "import socket; s=socket.create\_connection(('1.1.1.1',443),5); print('TCP 1.1.1.1:443 = OK'); s.close()"

```



Observed:



```text

TCP 1.1.1.1:443 = OK

```



\---



\## Symptoms



The container DNS configuration was temporarily changed to:



```text

nameserver 203.0.113.1

options timeout:1 attempts:1

```



After the change, hostname resolution failed.



Command:



```powershell

docker exec cloud-operations-lab python -c "import socket; print(socket.gethostbyname('example.com'))"

```



Observed:



```text

socket.gaierror: \[Errno -3] Temporary failure in name resolution

```



\---



\## Investigation



\### 1. Inspect DNS configuration



Command:



```powershell

docker exec cloud-operations-lab cat /etc/resolv.conf

```



Observed:



```text

nameserver 203.0.113.1

options timeout:1 attempts:1

```



The resolver configuration had changed from Docker's internal DNS resolver.



\---



\### 2. Test hostname resolution



Command:



```powershell

docker exec cloud-operations-lab python -c "import socket; print(socket.gethostbyname('example.com'))"

```



Observed:



```text

Temporary failure in name resolution

```



This confirmed a DNS resolution problem.



\---



\### 3. Test connectivity without DNS



To determine whether the entire network path was broken, TCP connectivity was tested directly against an IP address.



Command:



```powershell

docker exec cloud-operations-lab python -c "import socket; s=socket.create\_connection(('1.1.1.1',443),5); print('TCP 1.1.1.1:443 = OK'); s.close()"

```



Observed:



```text

TCP 1.1.1.1:443 = OK

```



This proved that outbound TCP networking remained functional.



\---



\### 4. Verify local application health



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



The local application remained operational.



\---



\### 5. Verify container state



Command:



```powershell

docker ps --filter "name=cloud-operations-lab" --format "table {{.Names}}\\t{{.Status}}"

```



Observed:



```text

cloud-operations-lab   Up ... (healthy)

```



Docker continued reporting the container as healthy.



\---



\## Root Cause



The container DNS resolver was deliberately replaced with:



```text

203.0.113.1

```



The resulting resolver configuration was:



```text

nameserver 203.0.113.1

options timeout:1 attempts:1

```



The configured nameserver did not provide DNS resolution.



Therefore:



```text

Application

&#x20;    |

&#x20;    v

Hostname lookup

&#x20;    |

&#x20;    v

Invalid DNS resolver

&#x20;    |

&#x20;    v

Resolution failure

```



General IP connectivity remained available.



\---



\## Resolution



The original Docker DNS configuration had been saved before the experiment.



It was restored with:



```powershell

docker exec cloud-operations-lab sh -c "cat /tmp/resolv.conf.backup > /etc/resolv.conf"

```



The resolver returned to:



```text

nameserver 127.0.0.11

```



\---



\## Verification



Hostname resolution was tested again:



```powershell

docker exec cloud-operations-lab python -c "import socket; print('example.com ->', socket.gethostbyname('example.com'))"

```



Observed:



```text

example.com -> 172.66.147.243

```



The exact IP address may vary because DNS-backed services can return different addresses.



TCP connectivity remained functional:



```text

TCP 1.1.1.1:443 = OK

```



Application health remained:



```text

ok

```



Container state remained:



```text

healthy

```



\---



\## DNS vs TCP vs Application



The incident demonstrated three independent layers:



```text

DNS

&#x20;|

&#x20;+--> Can a hostname be translated into an IP?



TCP

&#x20;|

&#x20;+--> Can a connection be established to an IP and port?



Application

&#x20;|

&#x20;+--> Is the service itself responding correctly?

```



During the incident:



```text

DNS           FAIL

TCP           OK

Application   OK

```



This prevented the issue from being incorrectly diagnosed as a complete network outage.



\---



\## Docker DNS



Docker normally provides containers with an internal DNS resolver:



```text

127.0.0.11

```



The Docker resolver can handle:



\- external DNS queries

\- container-name resolution

\- Docker network service discovery



Incorrect resolver configuration can therefore affect both external services and communication between containers.



\---



\## Prevention



Possible prevention measures include:



\- avoid manually modifying container DNS configuration

\- validate resolver configuration

\- monitor DNS failures separately from TCP failures

\- use redundant DNS infrastructure

\- monitor dependency resolution errors

\- test both hostname and IP connectivity during incidents

\- use Docker or orchestration-provided service discovery correctly



Production environments may also monitor:



\- DNS query latency

\- DNS error rates

\- resolver availability

\- upstream resolver health



\---



\## Troubleshooting Flow



```text

External service unreachable

&#x20;       |

&#x20;       v

Test hostname resolution

&#x20;       |

&#x20;       +--> FAIL

&#x20;       |

&#x20;       v

Test direct IP connectivity

&#x20;       |

&#x20;       +--> SUCCESS

&#x20;       |

&#x20;       v

Inspect resolver configuration

&#x20;       |

&#x20;       v

Identify DNS failure

&#x20;       |

&#x20;       v

Restore resolver

&#x20;       |

&#x20;       v

Verify hostname resolution

```



\---



\## Commands Used



```text

cat /etc/resolv.conf

socket.gethostbyname

socket.create\_connection

docker exec

docker ps

Invoke-RestMethod

```



\---



\## Status



Resolved.

