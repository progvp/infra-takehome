# Infrastructure Take Home

## Installation

Install a fresh Ubuntu 24.04 server LTS  
Copy the `ubuntu-bootstrap.sh` file into the home dir of `ubuntu` user  
Run this script as `ubuntu` user, it will install all necessary packages  
Log out and log in back  
Copy this folder or clone this repo to ~/infra-takehome  

## Running
Enter `infra-takehome` directory and run these commands:
```
make up
make argocd
make app
```
Wait until application is created and started (it make take several minutes) and run
```
curl --fail --silent http://localhost:8080/todos
```

You should get an output like this:
```
$ curl --fail --silent http://localhost:8080/todos
[{"id":1,"done":false,"task":"review the take-home solution","due":null},
 {"id":2,"done":true,"task":"bootstrap k3d with opentofu","due":null},
 {"id":3,"done":false,"task":"deploy postgrest through argocd","due":null}]
```
