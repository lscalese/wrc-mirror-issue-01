# wrc-mirror-issue

This is a temporary repository to reproduce a privileges mirror issue with Virtual IP.  



## Prepare your system

### Get an IRIS License

If you don't have a valid Docker License for IRIS yet connect to [Worldwide Respnse Center (WRC)](https://wrc.interystems.com) with your credentials.  
Click "Actions" --> "Online distribtion", then "Evaluations" button and select "Evaluation License", fill the form.  
Copy the `iris.key` to this repository directory.  


### Login to Intersystems Containers Registry

Our [docker-compose.yml](./docker-compose.yml) uses references to `containers.intersystems.com`.  
So you need to login to Intersystems Containers Registry to pull the used images.  
If you don't remember your password for the docker login to ICR, open this page https://login.intersystems.com/login/SSO.UI.User.ApplicationTokens.cls and you can retrieve your docker token.  


```bash
docker login -u="YourWRCLogin" -p="YourPassWord" containers.intersystems.com
```

### Build and run containers

```bash
docker-compose build --no-cache
docker-compose up
```

### Reproduce the problem

```bash
docker exec -it mirror-demo-master bash
cd /
. ./init_mirror.sh
```

you can see these messages : 

```
2022-02-06 09:47:56  * Security.Services
2022-02-06 09:47:56    + Update %Service_Mirror ... OK
2022-02-06 09:47:56  * SYS.MirrorMaster
2022-02-06 09:47:56    + Create Demo ... 
2022-02-06 09:48:02    = Wait became primary, checking while max 120 sec.  
2022-02-06 09:48:07      - Current status WAITING
2022-02-06 09:48:12      - Current status TRANSITION
```

Now, see the docker log

Wait each instance has the good mirror status.  It takes a while...
You should see theses messages.log or in docker logs :  

```
mirror-demo-master | 02/06/22-09:50:00:545 (749) 0 [Utility.Event] Manager initialized for DEMO
mirror-demo-master | 02/06/22-09:50:00:545 (749) 0 [Utility.Event] No other mirror members configured, becoming primary mirror server
mirror-demo-master | 02/06/22-09:50:03:018 (647) 0 [Database.MountedRW] Mounted database /usr/irissys/mgr/myappdata/ (SFN 5) read-write.
mirror-demo-master | 02/06/22-09:50:03:188 (749) 2 [Utility.Event] AddVirtualAddress failed, cannot become primary: AddVirtualAddress Failed - could not assign IP to interface, error: Need root privileges to run this script
```


