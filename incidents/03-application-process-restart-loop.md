\# Incident 03 — Application Process Failure and Container Restart Loop



\## Summary



The Cloud Operations Lab container entered a restart loop and the application became unavailable.



Docker successfully created and started the container, but the container's main process attempted to execute a Python file that did not exist.



The configured command was:



```text

python app/missing.py

```



Because the file was missing, the Python process exited immediately.



The Docker restart policy then repeatedly restarted the container.



\---



\## Impact



The application was unavailable to users.



Requests to:



```text

http://127.0.0.1:8080/health

```



failed because the Flask application never successfully started.



The container repeatedly restarted instead of remaining in a stable running state.



\---



\## Symptoms



Docker showed:



```text

Restarting (...)

```



The application health endpoint failed:



```powershell

Invoke-RestMethod http://127.0.0.1:8080/health

```



Observed:



```text

Unable to connect to the remote server

```



\---



\## Investigation



\### 1. Check container state



Command:



```powershell

docker ps -a --filter "name=cloud-operations-lab" --format "table {{.Names}}\\t{{.Status}}\\t{{.Ports}}"

```



Observed:



```text

cloud-operations-lab   Restarting (2) ...

```



This indicated that the container was repeatedly restarting.



\---



\### 2. Test application availability



Command:



```powershell

Invoke-RestMethod http://127.0.0.1:8080/health

```



Observed:



```text

Unable to connect to the remote server

```



The application was unavailable.



\---



\### 3. Inspect container logs



Command:



```powershell

docker logs cloud-operations-lab

```



Observed repeatedly:



```text

python: can't open file '/app/app/missing.py': \[Errno 2] No such file or directory

```



The repeated message showed that the same process failure occurred after every restart.



\---



\### 4. Inspect restart count and runtime state



Command:



```powershell

docker inspect cloud-operations-lab --format 'Status={{.State.Status}} ExitCode={{.State.ExitCode}} Restarting={{.State.Restarting}} RestartCount={{.RestartCount}}'

```



Observed during investigation:



```text

Status=running ExitCode=0 Restarting=false RestartCount=8

```



Because restart loops can happen quickly, runtime state may be captured between restart attempts.



The important signal was:



```text

RestartCount=8

```



Combined with repeated process errors in the logs, this confirmed a restart loop.



\---



\### 5. Inspect the configured container command



Command:



```powershell

docker inspect cloud-operations-lab --format '{{json .Config.Cmd}}'

```



Observed:



```json

\["python","app/missing.py"]

```



The container was configured to start a Python file that did not exist.



\---



\## Root Cause



The Docker Compose configuration overrode the normal container command with:



```yaml

command:

&#x20; - python

&#x20; - app/missing.py

```



The file:



```text

/app/app/missing.py

```



did not exist inside the container.



As a result:



```text

Container starts

&#x20;     |

&#x20;     v

Python attempts missing.py

&#x20;     |

&#x20;     v

Process exits

&#x20;     |

&#x20;     v

Docker restart policy

&#x20;     |

&#x20;     v

Container starts again

```



This created a restart loop.



\---



\## Resolution



The incorrect command override was removed.



The container returned to the default command defined in the Dockerfile:



```dockerfile

CMD \["python", "app/main.py"]

```



The container was then recreated.



\---



\## Verification



After the correction, Docker should show the container as:



```text

Up ... (healthy)

```



The health endpoint should return:



```json

{

&#x20; "status": "ok"

}

```



The restart count should no longer increase.



\---



\## Prevention



Possible prevention measures include:



\- avoid unnecessary command overrides

\- verify application entrypoints during deployment

\- validate required files during image build

\- test container startup in CI

\- monitor restart counts

\- alert on restart loops

\- inspect container logs before making infrastructure changes



\---



\## Troubleshooting Lessons



A container being created successfully does not mean the application process inside it started successfully.



These are separate layers:



```text

Docker image

&#x20;   |

&#x20;   v

Container

&#x20;   |

&#x20;   v

Main process

&#x20;   |

&#x20;   v

Application

&#x20;   |

&#x20;   v

Health endpoint

```



A failure in the main process can cause the entire container lifecycle to repeatedly restart.



Fast restart loops can also make a single runtime-state snapshot misleading.



For example:



```text

Status=running

```



may appear briefly even though the container is repeatedly crashing and restarting.



More reliable signals include:



```text

RestartCount

docker logs

configured command

application availability

```



\---



\## Commands Used



```text

docker ps -a

docker logs

docker inspect

Invoke-RestMethod

```



\---



\## Status



Resolved.

