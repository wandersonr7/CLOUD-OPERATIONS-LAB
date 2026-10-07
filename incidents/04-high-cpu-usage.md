\# Incident 04 — High CPU Usage Inside a Container



\## Summary



The Cloud Operations Lab application remained available and healthy while the Docker container experienced sustained CPU usage close to 100%.



The incident was caused by a separate Python process running an infinite CPU-bound loop inside the same container.



The Flask application itself was not responsible for the excessive CPU consumption.



\---



\## Impact



The application continued responding successfully during the incident.



However, sustained CPU saturation can cause:



\- increased response latency

\- request timeouts

\- degraded application performance

\- contention between processes

\- container throttling

\- infrastructure scaling events

\- higher cloud resource usage

\- reduced capacity for legitimate workloads



\---



\## Symptoms



Docker resource monitoring showed:



```text

CPU %: 99.82%

```



At the same time, the application remained healthy:



```powershell

Invoke-RestMethod http://127.0.0.1:8080/health

```



Observed:



```text

status

\------

ok

```



This demonstrated that a successful health check does not necessarily mean that the system is operating normally.



\---



\## Investigation



\### 1. Check container resource consumption



Command:



```powershell

docker stats cloud-operations-lab --no-stream

```



Observed:



```text

CPU %     MEM USAGE

99.82%    33.3MiB

```



CPU consumption was close to one full CPU core.



Memory consumption remained low.



This suggested a CPU-bound process rather than a memory problem.



\---



\### 2. Confirm application health



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



The application remained operational despite the resource problem.



\---



\### 3. Inspect running processes



Command:



```powershell

docker top cloud-operations-lab -eo pid,ppid,pcpu,pmem,args

```



Observed:



```text

python app/main.py

```



using approximately:



```text

0.0% CPU

```



A second Python process was using approximately:



```text

99.9% CPU

```



Its command contained:



```text

exec('while True: pass')

```



This isolated the high CPU usage to a background Python process rather than the Flask application.



\---



\### 4. Identify the process inside the container



The test process stored its container PID in:



```text

/tmp/cpu-stress.pid

```



Command:



```powershell

docker exec cloud-operations-lab cat /tmp/cpu-stress.pid

```



Observed:



```text

597

```



The process was confirmed as running:



```powershell

docker exec cloud-operations-lab python -c "p=open('/tmp/cpu-stress.pid').read().strip(); print('PID:',p); print('ALIVE:',\_\_import\_\_('os').path.exists('/proc/'+p)); print('CMD:',open('/proc/'+p+'/cmdline','rb').read().replace(b'\\x00',b' ').decode())"

```



Observed:



```text

PID: 597

ALIVE: True

CMD: python -c ... exec('while True: pass')

```



\---



\## PID Namespace Observation



The PID observed from inside the container differed from the PID displayed by:



```text

docker top

```



Inside the container:



```text

PID 597

```



From the host:



```text

PID 7563

```



This is expected because containers use Linux PID namespaces.



The process has one PID inside the container namespace and another representation from the host namespace.



\---



\## Root Cause



A CPU-bound Python process was intentionally started inside the container:



```python

while True:

&#x20;   pass

```



The loop continuously executed without sleeping or waiting for I/O.



As a result, it consumed nearly all of one available CPU core.



The Flask application itself was not responsible for the CPU saturation.



\---



\## Resolution



The offending process was terminated using its PID inside the container:



```powershell

docker exec cloud-operations-lab python -c "import os,signal; p=int(open('/tmp/cpu-stress.pid').read()); os.kill(p,signal.SIGTERM)"

```



After termination, container CPU usage returned to normal.



The Flask application continued operating normally.



\---



\## Verification



Resource usage was checked again:



```powershell

docker stats cloud-operations-lab --no-stream

```



The high-CPU process no longer appeared in:



```powershell

docker top cloud-operations-lab -eo pid,ppid,pcpu,pmem,args

```



Application health remained:



```text

ok

```



\---



\## Prevention



Possible prevention measures include:



\- monitor CPU utilization

\- configure CPU limits

\- alert on sustained CPU saturation

\- inspect per-process resource usage

\- avoid uncontrolled CPU-bound loops

\- test workloads under resource limits

\- use observability tooling

\- define container resource requests and limits in orchestration platforms



In production environments, systems such as Docker, ECS, Kubernetes, CloudWatch, Prometheus, and Grafana can provide resource monitoring and alerts.



\---



\## Troubleshooting Lessons



A healthy application endpoint does not prove that the system is operating normally.



During this incident:



```text

Application health    = healthy

Container health      = healthy

CPU utilization       = critical

```



Operational troubleshooting therefore requires both:



```text

Availability signals

```



and:



```text

Resource metrics

```



The investigation also demonstrated the importance of identifying which process is consuming resources rather than assuming the main application is responsible.



\---



\## Useful Troubleshooting Flow



```text

High CPU detected

&#x20;     |

&#x20;     v

Check docker stats

&#x20;     |

&#x20;     v

Check application health

&#x20;     |

&#x20;     v

Inspect processes

&#x20;     |

&#x20;     v

Identify high-CPU PID

&#x20;     |

&#x20;     v

Inspect process command

&#x20;     |

&#x20;     v

Terminate or correct process

&#x20;     |

&#x20;     v

Verify resource recovery

```



\---



\## Commands Used



```text

docker stats

docker top

docker exec

/proc

Invoke-RestMethod

```



\---



\## Status



Resolved.

