# E-commerce RAG demo

This demo showcases an example about how to build a pipeline to keep a vector DB up to date and use it to always build a prompt with fresh data from an e-commerce shop.  
![architecture](./architecture.jpg)

![Demo](demo.gif)

This is based on a Prestashop sample that is running on top of a MySQL DB. The [MySQL CDC Source Connector](https://www.confluent.io/hub/debezium/debezium-connector-mysql) tracks changed in real time from the database.

A single [Flink](https://developer.confluent.io/courses/flink-sql/overview/) statement processes the changes coming from different tables in order to build an autonomous record to be stored in a [Chroma](https://www.trychroma.com/) vector database.

Between the Flink statement output topic and the vector DB, a Python app is consuming the records, applies an embedding to the description and stores is as a vector. 

A langchain pipeline is used to build the prompt based on a customer question, adds context based on a similarity search request applied to the vector DB and wrap the results into the prompt submitted to the OpenAI platform API.

## Run it
The provisioning process is fully automated with teh `setup_aws.sh`. 
- It creates an EC2 instance
- Installs the Docker daemon
- Sends all files 
- Start the containers: MySQL DB, Prestashop sample, the Chroma DB, the Python document indexer and the Langchain pipeline with the playground to emulate the agent integration within the shop. 
- Then it creates a [Confluent Cloud](https://confluent.cloud) from the ground with a Kafka cluster, the fully managed CDC source connector and a Flink pool with the statement to process the changes.

The `setup_aws.sh` script requires a configuration file defined with an environment variable holding the following variables:

```shell
AWS_REGION=<region>
AWS_PROFILE=<profile>
SSH_PUB_KEY_FILE='~/.ssh/id_rsa.pub'
VM_OWNER=<value to populate the owner s tag>

MYSQL_ROOT_PASSWORD=<password>
MYSQL_PASSWORD=<password>

CONFLUENT_CLOUD_API_KEY=<key>
CONFLUENT_CLOUD_API_SECRET=<secret>
CONFLUENT_CLOUD_REGION=$AWS_REGION
CONFLUENT_CLOUD_PROVIDER=AWS

OPENAI_API_KEY=<key>
```
```shell 
$ CONFIG_FILE=[..]/config_aws.properties ./aws_setup.sh 
Config file: [..]/config_aws.properties
Initializing the backend...
[...]
Now you can visit the shop at http://18.201.108.106
cluster = "SASL_SSL://pkc-[...].[region].aws.confluent.cloud:9092"
sr_endpoint = "https://psrc-[...].[region].aws.confluent.cloud"
urls = <<EOT
Shop: 			http://18.21.108.106
Backend:  		http://18.21.108.106/admin2 (demo@prestashop.com/prestashop_demo)
AI Playground: 	http://18.21.108.106:8001/chat/playground/

EOT
```

Now you can browse to the Langchain playground application and ask questions about the products for sale on the shop! 


⚠️ Don't forget that you will be charged for the provisioned resources, so as soon as you no longer need the demo, think about disposing everything, and the `teardown_aws.sh` script is here to destroy everything.

