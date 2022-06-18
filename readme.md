# Speckle on Azure

A minimal serverless environment for running Speckle Server on Azure (AKS). This is a proof of concept for exploring a subset of production concerns, it is *NOT* intended to be used as a template for standing up a production environment. If you want to get a *full* production environment up and running quickly, check out [Speckle Enterprise](https://speckle.systems/getstarted/). 

## Overview

![](.\images\speckle-aks-highlevel.drawio.png)

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
        <details> Notes, 
            * resource_group_name is from step 1
            * db_username/password can be anything
            * can get your external ip with: `curl "http://myexternalip.com/raw"`
        <details>
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

### 3. Deploy Certificate Manager
### 4. Deploy Certificate Authority (CA) Issuer
### 5. Deploy Speckle
### 6. CLEAN UP
