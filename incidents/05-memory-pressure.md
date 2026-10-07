\# Incident 05 — Memory Pressure Inside a Container



\## Summary



The Cloud Operations Lab application remained available while the Docker container experienced high memory utilization.



The container had a configured memory limit of `256 MiB`.



A separate Python process allocated approximately `180 MiB` of memory and kept that allocation active.



Docker reported memory utilization above 80% while the Flask application continued responding successfully.



\---



\## Impact



The application remained operational during the incident.



However, sustained memory pressure can lead to:



\- degraded application performance

\- allocation failures

\- process termination

\- container instability

\- Out Of Memory events

\- container restarts

\- failed requests

\- service disruption



In a production environment, memory pressure can eventually cause the operating system or container runtime to terminate processes.



\---



\## Baseline



The container was configured with:



```yaml

mem\_limit: 256m

```



The applied Docker memory limit was verified with:



```powershell

docker inspect cloud-operations-lab --format 'MemoryLimit={{.HostConfig.Memory}} bytes'

```



Observed:



```text

MemoryLimit=268435456 bytes

```



This corresponds to:



```text

256 MiB

```



\---



\## Symptoms



Docker resource monitoring showed:



```text

MEM USAGE / LIMIT

213.3MiB / 256MiB

```



Memory utilization reached:



```text

83.31%

```



CPU utilization remained low.



The application continued responding successfully:



```powershell

Invoke-RestMethod http://127.0.0.1:8080/health

```



Observed:



```text

status

\------

ok

```



\---



\## Investigation



\### 1. Verify the container memory limit



Command:



```powershell

docker inspect cloud-operations-lab --format 'MemoryLimit={{.HostConfig.Memory}} bytes'

```



Observed:



```text

MemoryLimit=268435456 bytes

```



This confirmed that the container had a real memory limit rather than unrestricted access to host memory.



\---



\### 2. Check container resource consumption



Command:



```powershell

docker stats cloud-operations-lab --no-stream

```



Observed:



```text

CPU:        0.01%

Memory:     213.3MiB / 256MiB

Memory %:   83.31%

PIDS:       2

```



The high memory usage occurred without corresponding high CPU consumption.



This suggested a memory allocation problem rather than CPU saturation.



\---



\### 3. Confirm application availability



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



The service remained available despite the resource pressure.



\---



\### 4. Inspect running processes



Command:



```powershell

docker top cloud-operations-lab -eo pid,ppid,pcpu,pmem,args

```



Two relevant Python processes were present:



```text

python app/main.py

```



and:



```text

python -c ... data=bytearray(180\*1024\*1024) ...

```



The second process intentionally allocated approximately `180 MiB`.



\---



\### 5. Identify the process inside the container



The memory-pressure process stored its PID in:



```text

/tmp/memory-stress.pid

```



Command:



```powershell

docker exec cloud-operations-lab cat /tmp/memory-stress.pid

```



Observed:



```text

85

```



The process was then verified:



```powershell

docker exec cloud-operations-lab python -c "p=open('/tmp/memory-stress.pid').read().strip(); print('PID:',p); print('ALIVE:',\_\_import\_\_('os').path.exists('/proc/'+p)); print('CMD:',open('/proc/'+p+'/cmdline','rb').read().replace(b'\\x00',b' ').decode())"

```



Observed:



```text

PID: 85

ALIVE: True

```



The command confirmed that the process had allocated a large byte array and was keeping it resident.



\---



\## Root Cause



A background Python process allocated approximately `180 MiB` inside a container limited to `256 MiB`.



The process used:



```python

data = bytearray(180 \* 1024 \* 1024)

```



and then remained alive.



This caused container memory usage to increase to more than 80% of its configured limit.



The Flask application itself was not responsible for the majority of memory consumption.



\---



\## Resolution



The memory-consuming process was terminated using its PID:



```powershell

docker exec cloud-operations-lab python -c "import os,signal; p=int(open('/tmp/memory-stress.pid').read()); os.kill(p,signal.SIGTERM)"

```



The temporary PID file was removed:



```powershell

docker exec cloud-operations-lab rm -f /tmp/memory-stress.pid

```



After terminating the process, container memory usage returned toward its normal baseline.



\---



\## Verification



Resource usage was checked again:



```powershell

docker stats cloud-operations-lab --no-stream

```



The additional memory-consuming process no longer appeared in:



```powershell

docker top cloud-operations-lab -eo pid,ppid,pcpu,pmem,args

```



The application remained healthy:



```powershell

Invoke-RestMethod http://127.0.0.1:8080/health

```



Expected:



```text

status

\------

ok

```



\---



\## Memory Limit Protection



The container uses:



```yaml

mem\_limit: 256m

```



This provides a controlled boundary for the laboratory environment.



Without a container memory limit, an uncontrolled process could potentially consume significantly more host memory.



Resource limits reduce the blast radius of application failures.



\---



\## Prevention



Possible prevention measures include:



\- configure memory limits

\- monitor container memory utilization

\- alert before containers approach their limits

\- investigate memory growth trends

\- inspect per-process memory usage

\- detect memory leaks

\- load-test applications

\- configure orchestration resource limits

\- monitor OOM events

\- establish capacity thresholds



Production environments can use:



\- Docker metrics

\- Amazon CloudWatch

\- ECS task metrics

\- Kubernetes metrics

\- Prometheus

\- Grafana



\---



\## Troubleshooting Lessons



A healthy endpoint does not guarantee healthy resource utilization.



During this incident:



```text

Application health    = healthy

Container health      = healthy

CPU utilization       = normal

Memory utilization    = high

```



This reinforces the need to monitor multiple dimensions of system health.



```text

Availability

&#x20;  +

CPU

&#x20;  +

Memory

&#x20;  +

Disk

&#x20;  +

Network

&#x20;  =

Operational health

```



Resource limits are also an important reliability control.



They help prevent one faulty process from consuming unlimited host resources.



\---



\## Troubleshooting Flow



```text

High memory detected

&#x20;       |

&#x20;       v

Check docker stats

&#x20;       |

&#x20;       v

Verify memory limit

&#x20;       |

&#x20;       v

Check application health

&#x20;       |

&#x20;       v

Inspect processes

&#x20;       |

&#x20;       v

Identify memory-consuming process

&#x20;       |

&#x20;       v

Terminate or remediate process

&#x20;       |

&#x20;       v

Verify memory recovery

```



\---



\## Commands Used



```text

docker stats

docker top

docker inspect

docker exec

/proc

Invoke-RestMethod

```



\---



\## Status



Resolved.

