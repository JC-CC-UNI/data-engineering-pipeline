
# Streaming data from Kafka to S3 using Kafka Connect

<img width="5884" height="2848" alt="image" src="https://github.com/user-attachments/assets/4ccecf46-b038-4112-bd57-4ce503eba86f" />


This uses Docker Compose to run the Kafka Connect worker.

1. Create the S3 bucket, make a note of the region
2. Obtain your access key pair
3. Update `aws_credentials`
** Alternatively, uncomment the `environment` lines for `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` and set the values here instead
4. Bring the Docker Compose up


```bash
docker-compose up -d
```

5. Make sure everything is up and running

```bash
$ docker-compose ps
     Name                  Command               State                    Ports
---------------------------------------------------------------------------------------------
broker            /etc/confluent/docker/run   Up             0.0.0.0:9092->9092/tcp
kafka-connect     bash -c #                   Up (healthy)   0.0.0.0:8083->8083/tcp, 9092/tcp
                  echo "Installing ...
ksqldb            /usr/bin/docker/run         Up             0.0.0.0:8088->8088/tcp
schema-registry   /etc/confluent/docker/run   Up             0.0.0.0:8081->8081/tcp
zookeeper         /etc/confluent/docker/run   Up             2181/tcp, 2888/tcp, 3888/tcp
```

6. Create the Source connector

```bash
curl -i -X PUT -H "Accept:application/json" \
-H "Content-Type:application/json" http://localhost:8083/connectors/source-debezium-mssql-unified-multidb/config \
-d '{
  "connector.class": "io.debezium.connector.sqlserver.SqlServerConnector",
  "tasks.max": "1",
  "database.hostname": "mssql",
  "database.port": "1433",
  "database.user": "sa",
  "database.password": "Admin123",
  "database.server.name": "my_unified_sql_server_v3",
  "database.names": "demo",
  "topic.prefix": "sqlserver_cdc",
  "schema.history.internal.kafka.bootstrap.servers": "broker:29092",
  "schema.history.internal.kafka.topic": "dbz_dbhistory.my_unified_sql_server_v3",
  "database.encrypt": "false",
  "database.trustServerCertificate": "true",
  "decimal.handling.mode":"double",
  "key.converter": "org.apache.kafka.connect.json.JsonConverter",
  "key.converter.schemas.enable": "false",
  "value.converter": "org.apache.kafka.connect.json.JsonConverter",
  "value.converter.schemas.enable": "false",
  "transforms": "routeToTableName",
  "transforms.routeToTableName.type":"org.apache.kafka.connect.transforms.RegexRouter",
  "transforms.routeToTableName.regex":"sqlserver_cdc\\.(.*)\\.(.*)\\.(.*)",
  "transforms.routeToTableName.replacement":"$3"
}'
```


7. Create the Sink connector

```bash
curl -i -X PUT -H "Accept:application/json" \
    -H  "Content-Type:application/json" http://localhost:8083/connectors/sink-s3-voluble/config \
    -d '
 {
                "connector.class": "io.confluent.connect.s3.S3SinkConnector",
                "tasks.max": "1",
                "value.converter":"org.apache.kafka.connect.json.JsonConverter",
        "value.converter.schemas.enable": "false",
                "topics": "ORDERS,CLIENTS",
                "s3.region": "us-east-2",
                "s3.bucket.name": "snowflake-jlca-1",
                "flush.size": "4000000",
                "rotate.schedule.interval.ms": "60000",
                "storage.class": "io.confluent.connect.s3.storage.S3Storage",
                "format.class": "io.confluent.connect.s3.format.json.JsonFormat",
                "schema.compatibility": "NONE",
        "partitioner.class": "io.confluent.connect.storage.partitioner.TimeBasedPartitioner",
                "path.format": "YYYY/MM/dd",
                "locale": "US",
                "timezone": "UTC",
                "partition.duration.ms": "86400000",
                "timestamp.extractor": "Wallclock",
                "timestamp.field": "CreateTime",
                "file.name.template": "${topic}-${year}${month}${day}-${hour}${minute}${second}_p${partition}_o${offset}.json",
                "s3.compression.type": "gzip",
        "transforms": "hoist,AddMetadata",
                "transforms.hoist.type": "org.apache.kafka.connect.transforms.HoistField$Value",
                "transforms.hoist.field": "content",
                "transforms.AddMetadata.type": "org.apache.kafka.connect.transforms.InsertField$Value",
                "transforms.AddMetadata.offset.field": "offset",
                "transforms.AddMetadata.partition.field":"partition",
                "transforms.AddMetadata.topic.field":"topic",
                "transforms.AddMetadata.timestamp.field":"CreateTime"
        }
'
```


Things to customise for your environment:

* `topics` :  the source topic(s) you want to send to S3
* `key.converter` : match the serialisation of your source data (see https://www.confluent.io/blog/kafka-connect-deep-dive-converters-serialization-explained/[here])
* `value.converter` : match the serialisation of your source data (see https://www.confluent.io/blog/kafka-connect-deep-dive-converters-serialization-explained/[here])
* `transforms` : remove this if you don't want partition and offset added to each message


If you want to create the data generator and view the data in ksqlDB: 

```bash
docker exec -it ksqldb ksql http://ksqldb:8088
```

```bash
SHOW TOPICS;
SHOW CONNECTORS;
PRINT ORDERS;
```
