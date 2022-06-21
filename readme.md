# Speckle on Azure

A minimal serverless environment for running Speckle Server on Azure (AKS). This is a proof of concept exploring a basic set of production concerns, it is *NOT* intended to be used as a template for standing up a production environment. If you want to get a *full* production environment up and running quickly, check out [Speckle Enterprise](https://speckle.systems/getstarted/). 

## Overview

![](./images/speckle-aks-highlevel.drawio.png)

1. Persistance Layer: Postgres & Redis (PaaS)
2. Ingress Controller
3. Certificate Manager
4. Certificate Issuer
5. Speckle Services

## Tech Stack

* Speckle - 
* Terraform - for provisioning infrasture
* Docker - container virtualization
* Kubernetes - container orchestration
* Helm - Package Manager for Kubernetes
* Speckle Dependancies
* Azure Services
    * AKS
    * Postgres

## Prerequisites

* Azure Account
* Helm CLI
* Kubectl CLI
* AZ CLI
* Terraform CLI

## Getting Started

### 1. Deploy Persistance layer

1. Configure resources to be created.
    1. Create an azure resource group:
        ```
        az group create -l eastus -n saz-resources
        ```
    1. Create `/terraform/terraform.tfvars` file:
        ```
        resource_group_name = "saz-resources"
        db_username         = "psqladmin"
        db_password         = "passWORD123!"
        external_ip         = <your_external_ip>
        ``` 
    * Notes:
        * resource_group_name is from step 1
        * db_username/password can be anything
        * can get your external ip with: `curl "http://myexternalip.com/raw"`
1. Create resources
    1. Initialize terraform and provision cloud resources. 
        ```sh
        # from `/terraform` directory:
        terraform init
        terraform plan
        terraform apply
        ```
    * Notes:
        * if not using TLS/SSL, or would like to disable restriction for testing, then: 
            1. disable "Enforce SSL connection" in portal > postgres server > "Connection Security"
            2. disable "Allow access only via SSL" in portal > redis > "Adv Settings", and use port 6379
1. Perform sanity checks on newly created cloud services
    1. connect to postgres instance
        ```sh
        # 1. get connection details (can get from azure portal)
        # host:     saz-dev-psql-server.postgres.database.azure.com
        # port:     5432
        # server:   saz-dev-psql-server
        # db name:  saz-dev-psql-db
        # db user:  psqladmin@saz-dev-psql-server
        # db pass:  passWORD123!

        # 2. connect to postgres instance
        psql 'postgresql://psqladmin%40saz-dev-psql-server:passWORD123!@saz-dev-psql-server.postgres.database.azure.com:5432/saz-dev-psql-db'
        > \d
        ```
    1. connect to redis
        ```sh
        # 1. get connection details (including access key from azure portal)
        # hostname:     saz-dev-redis-cache.redis.cache.windows.net
        # port:         6380
        # access key:   <access_key>

        # 2a. connect: unencrypted (see notes above)
        redis-cli -h saz-dev-redis-cache.redis.cache.windows.net -c -p 6379 -a <access_key>
        > PING

        # 2b. connect: SSL
        # _1. configure stunnel /etc/stunnel/azure-cache.conf
        pid = /tmp/stunnel.pid
        delay = yes
        [redis-cli]
            client = yes
            accept = 127.0.0.1:8000
            connect = saz-dev-redis-cache.redis.cache.windows.net:6380
        # _2. start stunnel
        sudo service stunnel4 start
        # _3. connect through stunnel
        redis-cli -h localhost -p 8000 -a PqkrPFGwuMOwws4iqDHGu6gaIdbdUUJFRAzCaHjJoOA=
        > PING
        ```
1. [optional] connect to services with locally running speckle server
    1. clone speckle-server
        ```
        git clone git@github.com:specklesystems/speckle-server.git
        ```
    1. configure local environment
        ```
        cd speckle-server\packages\server
        cp .env-example .env
        ```
    1. edit `.env` file with postgres/redis connection details, e.g.,:
        ```
        REDIS_URL="redis://:<access_key>@saz-dev-redis-cache.redis.cache.windows.net:6379"
        POSTGRES_URL="saz-dev-psql-server.postgres.database.azure.com:5432"
        POSTGRES_USER="psqladmin@saz-dev-psql-server"
        POSTGRES_PASSWORD="passWORD123!"
        POSTGRES_DB="saz-dev-psql-db"
        ```
    1. start local server
        ```
        npm install
        npm run dev
        ```
        * note: had to fix npm run script bug (see below. should be fixed now)    
    1. check `localhost:3000/graphql`
        * note: can't run queries. This is expected b/c need frontend for auth flow.

### 2. Deploy Kubernetes Cluster

1. Configure resources to be created.
    1. Create `/infra-compute/terraform.tfvars` file:
        ```
        resource_group_name = "saz-resources"
        ssh_public_key      = "~/.ssh/id_rsa.pub"
        ``` 
    * Notes, 
        * if you don't have an ssh key pair, [create one](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/ssh-from-windows#create-an-ssh-key-pair)
1. Create cloud resources
    1. Initialize terraform and provision cloud resources. 
        ```sh
        # from `/infra-compute` directory:
        terraform init
        terraform plan
        terraform apply
        ```
1. Perform sanity checks
    1. connect to cluster
        ```
        az aks get-credentials 
            --resource-group "saz-resources" 
            --name "saz-dev-aks-cluster"
        ```
    1. inspect cluster
        ```
        kubectl get all
        kubectl describe svc kubernetes
        ```

### 3. Deploy Ingress Controller

1. Provision dependancies
    1. get resource group
        ```
        az aks show --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER --query nodeResourceGroup -o tsv
        ```
    1. create static ip
        ```
        az network public-ip create \
            --resource-group MC_dt-sandbox-resources_saz-dev-akscluster_eastus \
            --name sazDevPip \
            --sku Standard \
            --allocation-method static \
            --query publicIp.ipAddress \
            -o tsv
        ```
    1. Import nginx images into your Azure Container Registry (ACR)
        ```
        REGISTRY_NAME="sazacr"
        SOURCE_REGISTRY=k8s.gcr.io
        CONTROLLER_IMAGE=ingress-nginx/controller
        CONTROLLER_TAG=v1.0.4
        PATCH_IMAGE=ingress-nginx/kube-webhook-certgen
        PATCH_TAG=v1.1.1
        DEFAULTBACKEND_IMAGE=defaultbackend-amd64
        DEFAULTBACKEND_TAG=1.5
        CERT_MANAGER_REGISTRY=quay.io
        CERT_MANAGER_TAG=v1.5.4
        CERT_MANAGER_IMAGE_CONTROLLER=jetstack/cert-manager-controller
        CERT_MANAGER_IMAGE_WEBHOOK=jetstack/cert-manager-webhook
        CERT_MANAGER_IMAGE_CAINJECTOR=jetstack/cert-manager-cainjector

        az acr import --name $REGISTRY_NAME --source $SOURCE_REGISTRY/$CONTROLLER_IMAGE:$CONTROLLER_TAG --image $CONTROLLER_IMAGE:$CONTROLLER_TAG
        az acr import --name $REGISTRY_NAME --source $SOURCE_REGISTRY/$PATCH_IMAGE:$PATCH_TAG --image $PATCH_IMAGE:$PATCH_TAG
        az acr import --name $REGISTRY_NAME --source $SOURCE_REGISTRY/$DEFAULTBACKEND_IMAGE:$DEFAULTBACKEND_TAG --image $DEFAULTBACKEND_IMAGE:$DEFAULTBACKEND_TAG
        az acr import --name $REGISTRY_NAME --source $CERT_MANAGER_REGISTRY/$CERT_MANAGER_IMAGE_CONTROLLER:$CERT_MANAGER_TAG --image $CERT_MANAGER_IMAGE_CONTROLLER:$CERT_MANAGER_TAG
        az acr import --name $REGISTRY_NAME --source $CERT_MANAGER_REGISTRY/$CERT_MANAGER_IMAGE_WEBHOOK:$CERT_MANAGER_TAG --image $CERT_MANAGER_IMAGE_WEBHOOK:$CERT_MANAGER_TAG
        az acr import --name $REGISTRY_NAME --source $CERT_MANAGER_REGISTRY/$CERT_MANAGER_IMAGE_CAINJECTOR:$CERT_MANAGER_TAG --image $CERT_MANAGER_IMAGE_CAINJECTOR:$CERT_MANAGER_TAG

        az acr repository list --name $ACR --output table
        ```
1. Configure ingress controller to be installed
    1. Update `containers/ingress-nginx/values.yaml` file with your values:
1. Install nginx ingress controller
    1. Register helm repository
        ```
        helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
        ```
    2. Install container
        ```
        helm install nginx-ingress ingress-nginx/ingress-nginx 
            --version 4.0.13 
            --namespace default 
            -f ./ingress-nginx/values.yaml
        ```
1. Perform sanity checks
    1. Verify static IP address is assigned (It may take a few minutes for the LoadBalancer IP to be available)
        ```
        kubectl --namespace default get services -o wide -w nginx-ingress-ingress-nginx-controller
        ```
    1. Verify that the DNS name label has been applied by querying the FQDN on the public IP
        ```
        az network public-ip list --resource-group MC_dt-sandbox-resources_saz-dev-akscluster_eastus --query "[?name=='sazDevPip'].[dnsSettings.fqdn]" -o tsv
        ```
    1. Ensure that no event errors
        ```
        kubectl describe svc nginx-ingress
        ```

### 4. Deploy Certificate Manager

1. Configure resources
    1. Update `containers/cert-manager/values.yaml` with your values
    1. Update `containers/cert-manger/cluster-issuer.yaml` with your values
1. Install cert manager
    1. Label the cert-manager namespace to disable resource validation
        ```
        kubectl label namespace default cert-manager.io/disable-validation=true
        ```
    1. add to repo
        ```
        helm repo add jetstack https://charts.jetstack.io
        helm repo update
        ```
    1. install in default namespace
        ```
        helm install cert-manager jetstack/cert-manager \
            --namespace default \
            --version $CERT_MANAGER_TAG \
            -f ./cert-manager/values.yaml
        ```
    1. validate install
        ```
        helm list
        ```
    * notes:
        * https://docs.microsoft.com/en-us/azure/aks/ingress-static-ip?tabs=azure-cli#install-cert-manager
        * https://github.com/cert-manager/cert-manager/blob/master/deploy/charts/cert-manager/values.yaml
1. Create a CA cluster issuer
    1. create issuer 
        ```
        kubectl apply -f ./cert-manager/cluster-issuer.yaml --namespace default
        ```
    1. validate
        ```
        kubectl get clusterissuer
        ```
    * notes:
        * see https://docs.microsoft.com/en-us/azure/aks/ingress-static-ip?tabs=azure-cli#create-a-ca-cluster-issuer

### 5. Deploy Speckle

1. Configure Speckle
    1. Update `containers/speckle/values.yaml` with your values
    1. Create `containers/speckle/secrets.yaml`, for example:
        ```
        apiVersion: v1
        kind: Secret
        metadata:
            name: server-vars
            namespace: default
        stringData:
            postgres_url: 'postgresql://<psql_username>%40saz-dev-psql-server:<psql_password>@saz-dev-psql-server.postgres.database.azure.com:5432/saz-dev-psql-db'
            redis_url: 'redis://:<access_key>@saz-dev-redis-cache.redis.cache.windows.net:6379'
            session_secret: 'auniquesecretforthisserver'
            email_password: ''
            # s3_secret_key: minioadmin
            google_client_secret: ''
        ```
1. Install Containers
    1. install **helm chart** repo
        ```
        helm repo add speckle https://specklesystems.github.io/helm
        ```
    1. check avail repos/releases
        ```
        helm repo list
        helm list
        ```
    1. install speckle server
        ```sh
        helm install speckle-server speckle/speckle-server -f ./speckle/values.yaml
        ```
    1. create secret object (secrets.yml) and apply:
        ```sh
        kubectl apply -f ./speckle/secrets.yaml
        ```
        * see also: https://kubernetes.io/docs/tasks/configmap-secret/managing-secret-using-config-file/
    1. create priority classes
        ```sh
        kubectl apply -f ./speckle/high-priority-class.yaml
        kubectl apply -f ./speckle/low-priority-class.yaml
        ```
1. Perform sanity checks
    1. Check that Pods are running
        ```sh
        kubectl get pods -o wide
        ```
    1. Check for errors
        ```sh
        kubectl describe deployment speckle-server
        ```
    1. Try endpoints!
        ```
        https://saz-dev.eastus.cloudapp.azure.com/
        https://saz-dev.eastus.cloudapp.azure.com/graphql
        ```

### 6. CLEAN UP

