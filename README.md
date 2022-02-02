# wrc-mirror-issue

This is a temporary repository to reproduce a permission denied issue.  



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

```
docker-compose build --no-cache
docker-compose up
```

Wait each instance has the good mirror status.  It takes a while...
You should see theses messages in docker logs :  

```
mirror-demo-master | 01/09/22-11:02:08:227 (684) 1 [Utility.Event] Becoming primary mirror server
...
mirror-demo-backup | 01/09/22-11:03:06:398 (801) 0 [Utility.Event] Found MASTER as primary, becoming backup
...
mirror-demo-report | 01/09/22-11:03:10:745 (736) 0 [Generic.Event] MirrorClient: Connected to primary: MASTER (ver 4)
```


