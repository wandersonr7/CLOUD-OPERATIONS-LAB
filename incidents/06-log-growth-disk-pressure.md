\# Incident 06 — Log Growth and Disk Pressure



\## Summary



The Cloud Operations Lab application remained available and healthy while a large log file caused significant growth in the container filesystem.



A simulated application log grew from a small baseline to approximately `64 MiB`.



The incident demonstrated how uncontrolled log growth can consume container disk space even when the application itself continues operating normally.



\---



\## Impact



The service remained available during the incident.



However, uncontrolled log growth can eventually cause:



\- disk exhaustion

\- application write failures

\- container instability

\- failed deployments

\- database or application errors

\- inability to create temporary files

\- log ingestion failures

\- node-level disk pressure

\- service outages



In production environments, a full filesystem can affect multiple services running on the same host.



\---



\## Baseline



Before the simulated incident, `/var/log` used approximately:



```text

212K

```



Command:



```powershell

docker exec cloud-operations-lab sh -c "du -sh /var/log 2>/dev/null || true"

```



Observed:



```text

212K    /var/log

```



The filesystem reported:



```text

Filesystem      Size  Used Avail Use% Mounted on

overlay        1007G  4.3G  952G   1% /

```



Because the underlying filesystem was very large, a `64 MiB` increase did not visibly change the overall filesystem percentage.



\---



\## Symptoms



A simulated application log was created:



```text

/var/log/cloud-operations-lab.log

```



The file size reached:



```text

64M

```



Command:



```powershell

docker exec cloud-operations-lab ls -lh /var/log/cloud-operations-lab.log

```



Observed:



```text

\-rw-r--r-- 1 root root 64M ... /var/log/cloud-operations-lab.log

```



\---



\## Investigation



\### 1. Measure the log file directly



Command:



```powershell

docker exec cloud-operations-lab du -h /var/log/cloud-operations-lab.log

```



Observed:



```text

64M     /var/log/cloud-operations-lab.log

```



\---



\### 2. Inspect `/var/log`



Command:



```powershell

docker exec cloud-operations-lab sh -c "du -ah /var/log | sort -h | tail -10"

```



Observed:



```text

4.0K    /var/log/alternatives.log

12K     /var/log/apt/eipp.log.xz

12K     /var/log/apt/history.log

48K     /var/log/apt/term.log

76K     /var/log/apt

128K    /var/log/dpkg.log

64M     /var/log/cloud-operations-lab.log

65M     /var/log

```



The simulated application log clearly dominated disk consumption inside `/var/log`.



\---



\### 3. Check filesystem usage



Command:



```powershell

docker exec cloud-operations-lab df -h /

```



Observed:



```text

Filesystem      Size  Used Avail Use% Mounted on

overlay        1007G  4.3G  952G   1% /

```



The percentage did not visibly increase because the filesystem was much larger than the test file.



This demonstrated why filesystem percentages alone may hide smaller but still abnormal growth.



\---



\### 4. Inspect the container writable layer



Command:



```powershell

docker ps -s --filter "name=cloud-operations-lab"

```



Observed:



```text

SIZE

67.1MB (virtual 207MB)

```



The writable container layer had grown significantly.



\---



\### 5. Verify application availability



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



The application remained healthy despite the abnormal filesystem growth.



\---



\## Root Cause



A simulated application log grew without rotation or retention controls.



The generated file was:



```text

/var/log/cloud-operations-lab.log

```



and reached approximately:



```text

64 MiB

```



The root cause was uncontrolled log-file growth.



No mechanism was limiting:



\- file size

\- retention period

\- number of log files

\- rotation frequency



\---



\## Resolution



The oversized simulated log was removed:



```powershell

docker exec cloud-operations-lab rm -f /var/log/cloud-operations-lab.log

```



Disk usage inside `/var/log` was then checked again.



The application remained available throughout the cleanup.



\---



\## Verification



The log directory was inspected again:



```powershell

docker exec cloud-operations-lab sh -c "du -sh /var/log 2>/dev/null || true"

```



The large simulated log no longer appeared in:



```powershell

docker exec cloud-operations-lab sh -c "du -ah /var/log | sort -h | tail -10"

```



Application health remained:



```text

ok

```



\---



\## Why `df` Alone Was Not Enough



The container filesystem had approximately:



```text

1007G

```



of total capacity.



A `64 MiB` file therefore did not visibly change:



```text

Use%

```



from `1%`.



More targeted tools provided better evidence:



```text

du

ls

docker ps -s

```



This illustrates an important troubleshooting principle:



```text

High-level metric

&#x20;       |

&#x20;       v

May hide local growth

&#x20;       |

&#x20;       v

Inspect directories and files

```



\---



\## Prevention



Possible prevention measures include:



\- configure log rotation

\- define retention limits

\- limit log-file size

\- centralize application logs

\- monitor filesystem utilization

\- monitor directory growth

\- alert on writable-layer growth

\- avoid storing persistent logs inside container writable layers

\- ship logs to external logging systems



Production systems may use:



\- Docker log rotation

\- journald

\- CloudWatch Logs

\- Fluent Bit

\- Prometheus exporters

\- Grafana

\- centralized log platforms



\---



\## Container Logging Considerations



Containers should generally avoid depending on unlimited local log-file growth.



A common container pattern is:



```text

Application

&#x20;    |

&#x20;    v

stdout / stderr

&#x20;    |

&#x20;    v

Container runtime

&#x20;    |

&#x20;    v

Centralized logging platform

```



This makes retention and rotation easier to manage outside the application container.



\---



\## Troubleshooting Flow



```text

Disk growth detected

&#x20;      |

&#x20;      v

Check filesystem usage

&#x20;      |

&#x20;      v

Inspect directory sizes

&#x20;      |

&#x20;      v

Find largest files

&#x20;      |

&#x20;      v

Identify source

&#x20;      |

&#x20;      v

Remove / rotate / archive

&#x20;      |

&#x20;      v

Verify disk recovery

&#x20;      |

&#x20;      v

Add retention controls

```



\---



\## Commands Used



```text

df

du

ls

docker exec

docker ps -s

Invoke-RestMethod

```



\---



\## Status



Resolved.

