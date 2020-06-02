#!/bin/bash

## Bash colors 
NOCOLOR='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'

# important env
#image_tag=$(date +"%d%m%Y")
image_tag=latest
WORKDIR=$PWD
NS_REP_WEBAPP_DIR=$WORKDIR/ns-reporter-webapp
NS_CGM_DIR=$WORKDIR/nightscout-cgm-remote-monitor
DOCKER_IMAGES_DIR=$WORKDIR/docker_images
MONGO_DIR=$WORKDIR/mongodb

test -d $DOCKER_IMAGES_DIR || mkdir -p $DOCKER_IMAGES_DIR

# if already exist an old build dir, remove it and recreate a new one
# if it doesn't exist, create it from scratch
test -d $NS_REP_WEBAPP_DIR/build && rm -rf $NS_REP_WEBAPP_DIR/build; mkdir -p $NS_REP_WEBAPP_DIR/build || mkdir -p $NS_REP_WEBAPP_DIR/build

echo -e "[*] Downloading the NS Reporter zipfile..."
wget -q --tries=10 --timeout=20 --spider http://google.com
if [[ $? != 0 ]]; then
  echo -e "${RED}[!] It seems that you are offline. Please check your Internet connection and retry again.${NOCOLOR}"
  exit 1 
else 
  if [ -f "$WORKDIR/ns-reporter-build.zip" ]; then
    echo -e "${RED}[!] Found an old zipfile. Deleting it..${NOCOLOR}"
    rm -f $WORKDIR/ns-reporter-build.zip
  fi
  echo -e "[*] Starting download..."
  wget https://nightscout-reporter.zreptil.de/nightscout-reporter_local.zip -O ns-reporter-build.zip > /dev/null 2>&1

fi
# Unzip the file if it exists
if [ -f "$WORKDIR/ns-reporter-build.zip" ]; then
  echo -e "${GREEN}[*] NS Reporter build download correctly! Unzipping it...${NOCOLOR}"
  unzip ns-reporter-build.zip -d $NS_REP_WEBAPP_DIR/build > /dev/null 2>&1
else
  echo -e "${RED}[!] Error downloading NS Reporter zip archive.${NOCOLOR}"
  exit 1
fi 

echo -e "[*] Copying NS Reporter WebApp's Dockerfile in the build directory..."
cp $WORKDIR/Dockerfiles/ns-reporter-dockerfile $NS_REP_WEBAPP_DIR/Dockerfile

echo -e "[*] Building the container..."
cd $NS_REP_WEBAPP_DIR
docker build -t ns-reporter-webapp:$image_tag . > /dev/null 2>&1
status=$?
if [ $status -eq 0 ]; then
    echo -e "${GREEN}[*] NighScout Reporter container created successfully!${NOCOLOR}"
else
    echo -e "${RED}[!] Error creating the NS Reporter container${NOCOLOR}"
    exit 1
fi

cd $WORKDIR
echo -e "[*] Generating tar archive for the NightScout Reporter container"
docker save -o $DOCKER_IMAGES_DIR/ns-reporter-webapp-$image_tag.tar ns-reporter-webapp:$image_tag 
if [ -f "$DOCKER_IMAGES_DIR/ns-reporter-webapp-$image_tag.tar" ]; then
  echo -e "${GREEN}[*] Created tar archive: ns-reporter-webapp-$image_tag.tar${NOCOLOR}"
else
  echo -e "${RED}[!] Error creating ns-reporter-webapp-$image_tag.tar image archive${NOCOLOR}"
  exit 1
fi 

### Nightscout Remote CMG webapp 
echo -e "[*] Copying NightScout 'CGM Remote Monitor' Dockerfile in the build directory..." 
test -d $NS_CGM_DIR && rm -rf $NS_CGM_DIR; mkdir -p $NS_CGM_DIR|| mkdir -p $NS_CGM_DIR
cp $WORKDIR/Dockerfiles/ns-cgm-remote-monitor-dockerfile $NS_CGM_DIR/Dockerfile

echo -e "[*] Building the container..."
cd $NS_CGM_DIR
docker build -t ns-cgm-webapp:$image_tag . > /dev/null 2>&1
status=$?
if [ $status -eq 0 ]; then
    echo -e "${GREEN}[*] NighScout 'CGM Remote Monitor' container created successfully!${NOCOLOR}"
else
    echo -e "${RED}[!] Error creating the Nightscout 'CGM Remote Monitor' container${NOCOLOR}"
    exit 1
fi

cd $WORKDIR
echo -e "[*] Generating tar archive for the NighScout 'CGM Remote Monitor' container"
docker save -o $DOCKER_IMAGES_DIR/ns-cgm-webapp-$image_tag.tar ns-cgm-webapp:$image_tag 
if [ -f "$DOCKER_IMAGES_DIR/ns-cgm-webapp-$image_tag.tar" ]; then
  echo -e "${GREEN}[*] Created tar archive: ns-cgm-webapp-$image_tag.tar ${NOCOLOR}"
else
  echo -e "${RED}[!] Error creating ns-cgm-webapp-$image_tag image archive ${NOCOLOR}"
  exit 1
fi 

### MongoDB container

# Generate random string, necessary for the secret and for the MongoDB users passwords
RANDOM_MONGOUSER_PWD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 30)
RANDOM_KEYFILE=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 30 | base64)
RANDOM_NIGHTSCOUT_USER_PWD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 30)

echo -e "[*] Copying MongoDB Dockerfile in the build directory..." 
test -d $MONGO_DIR && rm -rf $MONGO_DIR; mkdir -p $MONGO_DIR|| mkdir -p $MONGO_DIR

cat << EOF > $MONGO_DIR/mongo-init.js
db.auth('mongouser', '$RANDOM_MONGOUSER_PWD')

db = db.getSiblingDB('nightscout')

db.createUser({
          user: 'nightscout',
          pwd: '$RANDOM_NIGHTSCOUT_USER_PWD',
          roles: [
                      {
                                    role: 'root',
                                    db: 'admin',
                                  },
                    ],
});
EOF

cp $WORKDIR/Dockerfiles/mongodb-dockerfile $MONGO_DIR/Dockerfile
cp $WORKDIR/Dockerfiles/mongo-docker-entrypoint.sh $MONGO_DIR/docker-entrypoint.sh 

cd $MONGO_DIR
docker build -t mongo-db:$image_tag . > /dev/null 2>&1
status=$?
if [ $status -eq 0 ]; then
    echo -e "${GREEN}[*] MongoDB container created successfully!${NOCOLOR}"
else
    echo -e "${RED}[!] Error creating MongoDB container${NOCOLOR}"
    exit 1
fi

cd $WORKDIR
echo -e "[*] Generating tar archive for the Mongo container"
docker save -o $DOCKER_IMAGES_DIR/mongo-db-$image_tag.tar mongo-db:$image_tag
if [ -f "$DOCKER_IMAGES_DIR/mongo-db-$image_tag.tar" ]; then
  echo -e "${GREEN}[*] Created tar archive: mongo-db-$image_tag.tar ${NOCOLOR}"
else
  echo -e "${RED}[!] Error creating mongo-db-$image_tag.tar image archive ${NOCOLOR}"
  exit 1
fi 

echo -e "[*] Build process Ended!"
echo -e "${GREEN}[*] Cleanup completed${NOCOLOR}"

echo -e "${GREEN}[*] Starting operations on the Kubernetes cluster...${NOCOLOR}"

echo -e "[*] Creating a secret yaml file for the MongoDB admin user: mongouser"

cat << EOF > kube-yamls/mongo-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: mongo-secret
type: Opaque
stringData:
  username: mongouser
  password: $RANDOM_MONGOUSER_PWD
data:
  keyfile: $RANDOM_KEYFILE
EOF

echo -e "[*] Creating a secret yaml file for the mongodb connection string..."

MDB_CON_STRING="mongodb://nightscout:$RANDOM_NIGHTSCOUT_USER_PWD@mongodb.default.svc.cluster.local:27017/nightscout"

cat << EOF > kube-yamls/mongo-connection-string.yaml
apiVersion: v1
kind: Secret
metadata:
  name: mongodbURI
type: Opaque
stringData:
  mongodburi: $MDB_CON_STRING
EOF

echo -e "[*] Creating a secret yaml file for the NightScout Site API_SECRET env..."

API_SECRET_ENV=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 12)

cat << EOF > kube-yamls/ns-apisecret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: nightscout-apisecret
type: Opaque
stringData:
  apisecret: $API_SECRET_ENV
EOF

echo "[*] Deploying MongoDB..."
kubectl apply -f kube-yamls/mongo-secret.yaml 
kubectl apply -f kube-yamls/mongo-headless-service.yaml
kubectl apply -f kube-yamls/mongo-nodeport-service.yaml
kubectl apply -f kube-yamls/mongo-statefulset.yaml

sleep 60
echo "[*] Deploying NighScout 'CGM Remote Monitor'..."
kubectl apply -f kube-yamls/mongo-connection-string.yaml
kubectl apply -f kube-yamls/ns-apisecret.yaml
kubectl apply -f kube-yamls/nightscout-cgm-deployment.yaml
kubectl apply -f kube-yamls/nightscout-cgm-service.yaml

echo "[*] Deploying NighScout Reporter deployment"
kubectl apply -f kube-yamls/ns-reporter-deployment.yaml
kubectl apply -f kube-yamls/ns-reporter-service.yaml
echo -e "${GREEN}[*] Kuberentes operations completed! Bye Bye${NOCOLOR}"
echo -e "[*] Cleaning the working environment..."
for element in $(ls | egrep -v "build.sh|Dockerfiles|docker_images|kube-yamls"); do rm -rf $element; done
echo -e ""
echo -e ""
NODE_IP=$(ip -o route get to 8.8.8.8 | sed -n 's/.*src \([0-9.]\+\).*/\1/p')
XDRIP_CON_STR=http://$API_SECRET_ENV@$NODE_IP/api/v1/
echo -e "${YELLOW}[INFO] Report of the most usefull informations:"
echo -e "[-->] XDrip+ Cloud Upload connection string: $XDRIP_CON_STR"
echo -e "[-->] Nightscout APISECRET: $API_SECRET_ENV"
echo -e "[-->] MongoDB Admin user: mongouser"
echo -e "[-->] MongoDB Admin passwd: $RANDOM_MONGOUSER_PWD"
echo -e "[-->] MongoDB Nightscout user: nightscout"
echo -e "[-->] MongoDB Nightscout password: $RANDOM_NIGHTSCOUT_USER_PWD"
echo -e ""
echo -e "[INFO] List of services IP/ports:"
echo -e "[-->] Nighscout Site: http://$NODE_IP:30101"
echo -e "[-->] Nighscout Reporter Site: http://$NODE_IP:30102"
echo -e "[-->] MongoDB Service: mongo://$NODE_IP:30100"