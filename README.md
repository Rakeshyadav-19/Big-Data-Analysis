# Web Log Analysis on Hadoop + Spark

A concise, faculty-oriented overview of what we built, why these technologies were chosen, and how the analysis works end-to-end. Includes an architecture view, core methods, and a short demo flow.

---

## Executive summary

- Goal: Analyze NASA HTTP server logs (July 1995) at scale.
- Approach: Store data in HDFS and process with PySpark running on YARN; visualize basic insights in a Jupyter notebook.
- Outcome: Parsed raw Apache logs into structured columns using regex; computed request volume, top endpoints and hosts, status-code distribution, and average response size; rendered a simple bar chart.

---

## What we used

- Apache Hadoop
  - HDFS: Reliable distributed storage
  - YARN: Cluster resource management and job scheduling
- Apache Spark (PySpark)
  - Distributed data processing, resilient in-memory computation
- Jupyter Notebook
  - Interactive development and demonstration
- Python libraries
  - pyspark, pandas, matplotlib (and optionally seaborn)
- OS: Fedora Linux (local single-node cluster)
- Dataset: NASA HTTP Web Server Logs (July 1995), gzip-compressed

---

## Why these tools

- HDFS: Handles large files efficiently and exposes a stable URI (`hdfs://...`) for compute frameworks.
- YARN: Lets Spark scale out compute and manage resources (even on a single machine, it mimics real clusters).
- Spark: Expressive APIs to parse, transform, and aggregate logs at scale. Transparent reading of gzip files and strong regex support.
- Jupyter: Ideal for iterative ETL/EDA, clear for classroom demonstrations.

---

## Architecture (local, single-node)

```
+------------------------------+
| NASA_access_log_Jul95.gz     |
+--------------+---------------+
               |
               v
        +-------------+
        | HDFS (Data) |
        +------+------+
               |
               v
+-------------------------------+
| Spark on YARN (Computation)   |
+-------------------------------+
               |
               v
     +-------------------+
     | Notebook + Charts |
     +-------------------+
```

---

## How it works (end-to-end)

1. Data in HDFS

- We place `NASA_access_log_Jul95.gz` under `/input` in HDFS: `hdfs://localhost:9000/input/NASA_access_log_Jul95.gz`.

2. Spark session (YARN + HDFS)

- The notebook creates a SparkSession with:

```python
spark = (SparkSession.builder
    .appName("Web Log Analysis on Hadoop")
    .master("yarn")
    .config("spark.hadoop.fs.defaultFS", "hdfs://localhost:9000")
    .getOrCreate())
```

3. Read raw logs (text)

```python
logs_df = spark.read.text("hdfs://localhost:9000/input/NASA_access_log_Jul95.gz")
```

4. Parse Apache log lines with regex

- Patterns extract:
  - host, timestamp, method, endpoint, protocol, status, content_size
- Example pattern names (from the notebook):
  - `host_pattern`, `timestamp_pattern`, `method_uri_protocol_pattern`, `status_pattern`, `bytes_pattern`
- We apply `regexp_extract` and create structured columns in the same DataFrame.

5. Aggregations and stats

- Total request count
- Requests grouped by `status`
- Top `endpoint` and top `host` by frequency
- Average `content_size` after casting to integer

6. Visualization

- Convert grouped status counts to Pandas and plot a bar chart of HTTP status distribution using matplotlib.

---

## Methods: parsing details

- The notebook uses `regexp_extract` to split the Common Log Format-style lines into fields:
  - `host`: `(^\S+)\s`
  - `timestamp`: `\[(.*?)\]`
  - `method`, `endpoint`, `protocol`: `\"(\S+)\s(\S+)\s*(\S*)\"`
  - `status`: `\s(\d{3})\s`
  - `content_size`: `\s(\d+)$`
- After extraction:
  - We select and preview `host`, `timestamp`, `method`, `endpoint`, `status`, `content_size`.
  - We cast `content_size` to integer to compute averages.

---

## Reproducibility (demo flow)

- Start services:

```bash
start-dfs.sh
start-yarn.sh
```

- Put dataset into HDFS:

```bash
hdfs dfs -mkdir -p /input
hdfs dfs -put NASA_access_log_Jul95.gz /input/
```

- Run the notebook `WebLog_Analysy-HHS.ipynb` in this folder and execute cells in order.
- Expected outputs:
  - Total line and request counts printed
  - Aggregation tables for status, endpoint, host
  - Average content size (bytes)
  - A bar chart showing HTTP status distribution

---

## Results (what to highlight in a viva)

- Demonstrate how raw, unstructured text logs become structured analytics-ready tables via regex.
- Explain the difference between storage (HDFS) and compute (Spark on YARN) and why each matters.
- Show how gzip compression is handled transparently by Spark.
- Discuss simple metrics:
  - Which status codes dominate (e.g., 200 vs 404)?
  - Which endpoints are most requested?
  - Which hosts are most active?
  - What’s the average response size?

---

## Limitations and next steps

- Timestamps are left as raw strings; we could parse to `TimestampType` and analyze trends per hour/day.
- 404 analysis: identify top missing resources and potential causes.
- Persist cleaned data as Parquet in HDFS and query via Spark SQL or Hive.
- Scale-out testing: run with additional months (e.g., Aug 1995) and compare traffic patterns.
- Avoid `.toPandas()` on very large data—sample or aggregate first, or plot with Spark-native connectors.

---

## Environment and versions

- Hadoop 3.3.6, Spark 3.5.6, Hive 4.0.1 (optional), OpenJDK 11, Python 3.11.x
- HDFS default FS: `hdfs://localhost:9000`
- Notebook path: `WebLog_Analysy-HHS.ipynb`
- OS: Fedora Linux (local, single-node setup)

---

## References

- NASA HTTP Web Server Logs: https://ita.ee.lbl.gov/html/contrib/NASA-HTTP.html
- Apache Spark: https://spark.apache.org/
- Apache Hadoop: https://hadoop.apache.org/

---

## License

MIT License © 2025
