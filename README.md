# Hadoop Docker Compose (infravibe/hadoop)

Multi-node Hadoop (HDFS + YARN + MR HistoryServer) using `infravibe/hadoop:3.4.1`.

- Reference: [Building a Multi-Node Hadoop Cluster with Docker](https://akashsahani2001.medium.com/building-a-multi-node-hadoop-cluster-with-docker-a-complete-production-ready-setup-by-akash-fa1adfd605ec)
- Docker Hub: [`https://hub.docker.com/r/infravibe/hadoop`](https://hub.docker.com/r/infravibe/hadoop)

## Quick start
```bash
./start-cluster.sh
```

## Web UIs
- NameNode: http://localhost:9870
- ResourceManager: http://localhost:8088
- NodeManager1: http://localhost:8042
- NodeManager2: http://localhost:8043
- DataNode1: http://localhost:9864
- DataNode2: http://localhost:9865
- History Server: http://localhost:19888

## Architecture
```
                          Host (CLI + Web UIs on localhost)
                                   |
                           Port mappings (-> containers)
                                   |
+--------------------------------------------------------------------------+
|                   Docker bridge network: "apache"                        |
|                                                                          |
|  +----------------+        RPC 9820         +-------------------------+  |
|  |    NameNode    |<----------------------->|       DataNode1         |  |
|  | HDFS metadata  |                         | HDFS blocks (9864 UI)   |  |
|  | UI:9870, RPC:9820                        +-------------------------+  |
|  +----------------+        RPC 9820         +-------------------------+  |
|          ^              (block locations)   |       DataNode2         |  |
|          |                                   | HDFS blocks (9864 UI)   |  |
|          |                                   +-------------------------+  |
|          |                                                     ^         |
|          |                                   writes/reads HDFS |         |
|          v                                                     |         |
|  +------------------+       Schedules apps        +-------------------+  |
|  | ResourceManager  |<--------------------------->|   NodeManager1    |  |
|  | YARN RM UI:8088  |                             | YARN NM UI:8042   |  |
|  +------------------+                             +-------------------+  |
|          ^                                                ^             |
|          |                                                |             |
|          |                                     +-------------------+    |
|          |                                     |   NodeManager2    |    |
|          |                                     | YARN NM UI:8042   |    |
|          |                                     +-------------------+    |
|          |                                                        ^      |
|          |                              app containers (AM + tasks)      |
|          v                                                        |      |
|  +------------------+                                           HDFS     |
|  |  HistoryServer   |<--------------------------------------------+      |
|  | MR UI:19888 RPC:10020 |   collects job history and counters           |
|  +------------------+                                                   |
+--------------------------------------------------------------------------+
```

- HDFS: `NameNode` holds filesystem metadata; `DataNode1/2` store actual blocks. Replication is set to 1 for local dev. Data persists via volumes: `namenode_data`, `datanode1_data`, `datanode2_data`. WebHDFS is enabled; `dfs.datanode.hostname=localhost` controls redirect host.
- YARN: `ResourceManager` schedules applications; `NodeManager1/2` run containers (Map/Reduce tasks and the ApplicationMaster). Output is written back to HDFS. `HistoryServer` exposes completed job history on 19888 and RPC on 10020.
- Networking: All containers join the external Docker network `apache`. Host ports are published for UIs: 9870, 8088, 8042/8043, 9864/9865, 19888.
- Config: `config/core-site.xml`, `hdfs-site.xml`, `yarn-site.xml`, `mapred-site.xml` set `fs.defaultFS=hdfs://namenode:9820`, data dirs, RM hostname, and MR JobHistory endpoints.

## Smoke test
```bash
# HDFS ops
docker exec -it namenode bash -lc 'hdfs dfs -mkdir -p /test; echo Hello Hadoop! > /tmp/test.txt; hdfs dfs -put -f /tmp/test.txt /test/test.txt; hdfs fsck /test/test.txt -files -blocks -locations'

# MapReduce wordcount

docker exec -it namenode bash -lc 'out=/output_$(date +%s); hadoop jar /opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.4.1.jar wordcount /test/test.txt $out; hdfs dfs -cat $out/part-r-00000'
```

## Stop
```bash
./stop-cluster.sh        # keep volumes
# docker compose down -v # remove volumes
```

## Cleanup (delete images and volumes)
- Targeted (this project only):
```bash
# stop and remove containers + named volumes used by this compose
docker compose down -v

# remove the external network used by this setup (optional)
docker network rm apache || true

# explicitly remove named volumes if they still exist
docker volume rm \
  hadoop-environment_namenode_data \
  hadoop-environment_datanode1_data \
  hadoop-environment_datanode2_data 2>/dev/null || true

# remove the pulled image
docker rmi -f infravibe/hadoop:3.4.1 || true
```

- Global (dangerous: deletes ALL unused containers, images, networks, and volumes):
```bash
docker system prune -a --volumes --force
```
