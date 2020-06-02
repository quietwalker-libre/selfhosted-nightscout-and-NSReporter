# Selfhosted Nightscout and NightscoutReporter

I made this project some weeks ago just to try learn and practice Kubernetes. 
Of course this task could be accomplished by Docker Compose or similar, but I wrote it is just a practice test about Kubernetes. 

Right now, everything is supposed to work fine but let me know if you will find something wrong.
I've tested it in a kubernetes single node "cluster" made using vagrant (using Virtualbox), but you can test it wherever you want. Let me know
if you will find something wrong or something that could be enhanced in any step.

## How to install
To install everything from scratch you should follow the steps below on kubernetes master node: 
- Clone this repo

  `git clone https://github.com/quietwalker-libre/selfhosted-nightscout-and-NSReporter.git`

- Execute the build.sh:
```
  cd selfhosted-nightscout-and-NSReporter
  chmod +x build.sh 
  ./build.sh 
```

## Usefull informations
If the build.sh script will terminate with success, at the end of its execution it will print all the necessary information 
needed to start to use nightscout and nightscout reporter. 
The summary should looks like this: 
```
  [INFO] Report of the most usefull informations:
  XDrip+ Cloud Upload connection string: abcder6374fgfg
  Nightscout APISECRET: fgdghgj245hhk
  MongoDB Admin user: mongouser
  MongoDB Admin passwd: srjrtmrhd4gf
  MongoDB Nightscout user: nightscout
  MongoDB Nightscout password: hrmweot72olgd

  [INFO] List of services IP/ports:
  [-->] Nighscout Site: http://192.168.0.120:30101
  [-->] Nighscout Reporter Site: http://192.168.0.120:30102
  [-->] MongoDB Service: mongo://192.168.0.120:30100
```
### Kubernetes services and port
To expose the MongoDB, Nightcout and NightScout Reporter pods I used the NodePort Kubernetes Service. As I wrote above,
the external MongoDB service will be removed in the coming versions.
The External Service in this version are:
- MongoDB: reachable at port **30100**
- NightScout: reachable at port **30101**
- NightScout Reporter: reachable at port **30102**  

## TO DO
After some weeks I see that I should change something in the build.sh script: 
- all the *docker build* in the build.sh command should have the * -f * option with the specified dockerfile. I will fix it as soon as I can. 
- It's not necessary to externally expose the MongoDB service. The service should be declared as ClusterIP
- Something else that I don't remember :P 
