# Big Data Web Log Analysis with Spark on Hadoop (HDFS + YARN)

Analyze the NASA HTTP Web Server Logs (July 1995) at scale using PySpark running on YARN with data stored in HDFS. This README walks you end-to-end: environment setup, dataset loading to HDFS, running the provided Jupyter notebook, interpreting results, and troubleshooting.

---

## What’s in this project

- `WebLog_Analysy-HHS.ipynb` — the main notebook that parses logs, computes aggregates, and makes a simple visualization.
- `Big Data Web Log Analysis.md` — this guide.
- `Automated Setup.sh` — a helper script to set up dependencies locally.

---

## Components and versions

These are the versions used while building and validating the notebook. Other nearby versions may work, but start here if you’re reproducing exactly.

| Component      | Purpose                                                | Version |
| -------------- | ------------------------------------------------------ | ------- |
| Hadoop         | Distributed File System (HDFS) + YARN Resource Manager | 3.3.6   |
| Spark          | In-memory compute engine                               | 3.5.6   |
| Hive           | SQL on HDFS (optional in this project)                 | 4.0.1   |
| Java (OpenJDK) | JVM for Hadoop/Spark/Hive                              | 11      |
| Python         | Runtime for PySpark                                    | 3.11.x  |
| Jupyter        | Interactive environment                                | Latest  |

---

## Architecture (local, single-machine cluster)

```
             +-------------------------------+
             |    NASA Web Log Dataset       |
             |  (NASA_access_log_Jul95.gz)   |
             +-------------------------------+
                            |
                            v
                 +------------------+
                 |    HDFS Storage  |
                 +------------------+
                            |
                            v
          +---------------------------------------+
          | Spark (PySpark) on YARN (Computation) |
          +---------------------------------------+
                            |
                            v
                 +-----------------------+
                 |  Analysis & Charts    |
                 +-----------------------+
```

---

## Prerequisites

- Linux machine (validated on Fedora). macOS can work with minor changes; Windows via WSL2 recommended.
- OpenJDK 11
- Hadoop 3.x (HDFS + YARN) installed and runnable locally
- Spark 3.5.x with Hadoop 3 profile
- Python 3.11 with the following packages:
  - pyspark
  - findspark (optional, helpful)
  - pandas, matplotlib, seaborn (for plotting)
- Jupyter Notebook/Lab

If you already have an automated installer in this folder (e.g., `Automated Setup.sh`), you can run it; otherwise follow the manual steps.

---

## Manual setup (summary)

1. Install base tools

```bash
sudo dnf update -y
sudo dnf install -y wget tar ssh openssh-server openssh-clients git python3 python3-pip
```

2. Java 11

```bash
sudo dnf install -y java-11-openjdk java-11-openjdk-devel
java -version
```

3. Hadoop 3.3.6

```bash
cd /opt
sudo wget https://downloads.apache.org/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz
sudo tar -xvzf hadoop-3.3.6.tar.gz
sudo mv hadoop-3.3.6 hadoop
sudo chown -R $USER:$USER /opt/hadoop
```

Add to `~/.bashrc`:

```bash
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk
export HADOOP_HOME=/opt/hadoop
export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin
export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
```

Reload and format NameNode (first time only), then start HDFS and YARN:

```bash
source ~/.bashrc
hdfs namenode -format
start-dfs.sh
start-yarn.sh
```

4. Spark 3.5.6 (Hadoop 3 build)

```bash
cd /opt
sudo wget https://downloads.apache.org/spark/spark-3.5.6/spark-3.5.6-bin-hadoop3.tgz
sudo tar -xvzf spark-3.5.6-bin-hadoop3.tgz
sudo mv spark-3.5.6-bin-hadoop3 spark
sudo chown -R $USER:$USER /opt/spark
```

Add to `~/.bashrc`:

```bash
export SPARK_HOME=/opt/spark
export PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin
```

Reload:

```bash
source ~/.bashrc
```

5. Python packages

```bash
python3 -m pip install --upgrade pip
pip install pyspark findspark jupyter pandas matplotlib seaborn
```

---

## Get the dataset and load into HDFS

We use the compressed NASA July 1995 access logs (Spark can read GZip transparently).

```bash
# Create a workspace folder (optional)
mkdir -p ~/data/nasa && cd ~/data/nasa

# Download the log (you can also use another mirror/source)
wget https://ita.ee.lbl.gov/html/contrib/NASA-HTTP.html -O NASA-HTTP.html  # reference page
# Example direct file name typically used in exercises (adjust if your source differs)
# If you already have NASA_access_log_Jul95.gz locally, skip the next line.

# Place the file into HDFS at /input
hdfs dfs -mkdir -p /input
hdfs dfs -put NASA_access_log_Jul95.gz /input/

# Verify it’s in HDFS
hdfs dfs -ls /input
```

If you have multiple files (e.g., August 1995), you can load them all into `/input`.

---

## Run the notebook

1. Start the Hadoop daemons (if not already):

```bash
start-dfs.sh
start-yarn.sh
```

2. Launch Jupyter in this project folder and open `WebLog_Analysy-HHS.ipynb`:

```bash
cd path
jupyter notebook
```

3. Execute the notebook cells in order. Here’s what each section does:

- Cell 1 — Imports

  - `from pyspark.sql import SparkSession`
  - `from pyspark.sql.functions import regexp_extract`

- Cell 2 — Spark session + read logs from HDFS

  - Creates a session configured for YARN and sets the HDFS default FS:
    ```python
    spark = SparkSession.builder \
        .appName("Web Log Analysis on Hadoop") \
        .master("yarn") \
        .config("spark.hadoop.fs.defaultFS", "hdfs://localhost:9000") \
        .getOrCreate()
    ```
  - Reads the compressed log as text from HDFS: `hdfs://localhost:9000/input/NASA_access_log_Jul95.gz`
  - Prints Spark version, counts lines, and previews a few records.

- Cell 3 — Parse the Apache log format using regex

  - Extracts fields into columns:
    - `host` — client hostname or IP
    - `timestamp` — raw timestamp between brackets
    - `method`, `endpoint`, `protocol` — from the request line
    - `status` — HTTP status code
    - `content_size` — response size (bytes)
  - This uses `regexp_extract` with patterns tailored to common Apache log lines.

- Cell 4 — Basic count

  - `print("Total requests:", logs_df.count())`

- Cell 5 — Top-level aggregations

  - Requests by status: `logs_df.groupBy("status").count()`
  - Most-hit endpoints: `logs_df.groupBy("endpoint").count()`
  - Most-active hosts: `logs_df.groupBy("host").count()`

- Cell 6 — Content size stats

  - Casts `content_size` to integer and computes average with `avg("content_size")`.

- Cell 7 — Visualization
  - Converts grouped status counts to Pandas and plots a bar chart of HTTP status distribution using Matplotlib.

4. Optional: Running without YARN

If you don’t have YARN running, you can switch to local mode by changing the builder in the notebook:

```python
spark = SparkSession.builder \
    .appName("Web Log Analysis (Local)") \
    .master("local[*]") \
    .getOrCreate()

# And read from local filesystem instead of HDFS, e.g.:
logs_df = spark.read.text("/path/to/NASA_access_log_Jul95.gz")
```

---

## Data model produced by parsing

After parsing, the Spark DataFrame has these columns:

- `host` (string)
- `timestamp` (string; raw log timestamp e.g., `01/Jul/1995:00:00:01 -0400`)
- `method` (string; GET/POST/…)
- `endpoint` (string; requested path)
- `protocol` (string; HTTP version)
- `status` (string; HTTP code; 200, 404, …)
- `content_size` (string → cast to integer for stats)

You can easily extend this to parse dates to proper timestamps, filter bots, detect 404s, or compute per-day aggregates.

---

## Web UIs you can open locally

| Service                | URL                   |
| ---------------------- | --------------------- |
| NameNode (HDFS)        | http://localhost:9870 |
| ResourceManager (YARN) | http://localhost:8088 |
| Spark UI (active app)  | http://localhost:4040 |

---

## Troubleshooting

- YARN or HDFS not started

  - Start them before running the notebook: `start-dfs.sh` and `start-yarn.sh`.

- HDFS path not found or permission denied

  - Ensure the file exists in HDFS and you can read it:
    ```bash
    hdfs dfs -ls /input
    hdfs dfs -cat /input/NASA_access_log_Jul95.gz | head -n 1
    ```

- Spark can’t connect to HDFS (`FileNotFoundException` or `Connection refused`)

  - Verify the default FS is set in the Spark session (`hdfs://localhost:9000`) and that NameNode is up (check http://localhost:9870).

- Matplotlib windows don’t show in headless environments

  - In Jupyter, plots show inline by default. If you’re running non-notebook scripts, use a non-interactive backend or save figures to files.

- Memory or driver errors when converting to Pandas
  - Avoid calling `.toPandas()` on very large DataFrames. For larger datasets, sample or aggregate before collecting to the driver.

---

## Extend the analysis (ideas)

- Parse timestamps to Spark TimestampType and compute per-hour/day traffic.
- Identify top 404 endpoints and their referrers.
- Compute unique hosts per day and top talkers.
- Join July and August logs to compare trends.
- Write cleaned data to Parquet in HDFS and query with Spark SQL or Hive.

---

## Stop services

```bash
stop-yarn.sh
stop-dfs.sh
```

---

## License

MIT License © 2025
