#!/bin/bash
# 🚀 Automated Setup Script for Hadoop + Spark + Hive + Pyenv on Fedora (zsh-friendly, idempotent)

set -euo pipefail

# Detect shell rc file (zsh preferred per environment)
RC_FILE="$HOME/.bashrc"
if [ -n "${ZSH_VERSION-}" ] || [ "$(basename "${SHELL:-}")" = "zsh" ]; then
	RC_FILE="$HOME/.zshrc"
fi

append_if_missing() {
	local line="$1" file="$2"
	grep -Fqx "$line" "$file" 2>/dev/null || echo "$line" >> "$file"
}

echo "=== Updating System Packages ==="
sudo dnf update -y
sudo dnf install -y wget tar ssh openssh-server openssh-clients git python3 python3-pip

echo "=== Installing Java 11 ==="
sudo dnf install -y java-11-openjdk java-11-openjdk-devel
java -version || true

echo "=== Ensuring SSH server for Hadoop is running (passwordless localhost) ==="
sudo systemctl enable --now sshd
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
if [ ! -f "$HOME/.ssh/id_rsa" ]; then
	ssh-keygen -t rsa -N '' -f "$HOME/.ssh/id_rsa" <<< y >/dev/null 2>&1
fi
cat "$HOME/.ssh/id_rsa.pub" >> "$HOME/.ssh/authorized_keys"
chmod 600 "$HOME/.ssh/authorized_keys"

echo "=== Setting Up Hadoop ==="
cd /opt
if [ ! -d /opt/hadoop ]; then
	sudo wget -q https://downloads.apache.org/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz
	sudo tar -xzf hadoop-3.3.6.tar.gz
	sudo mv hadoop-3.3.6 hadoop
	sudo chown -R "$USER":"$USER" /opt/hadoop
fi

echo "=== Setting Up Spark ==="
if [ ! -d /opt/spark ]; then
	sudo wget -q https://downloads.apache.org/spark/spark-3.5.6/spark-3.5.6-bin-hadoop3.tgz
	sudo tar -xzf spark-3.5.6-bin-hadoop3.tgz
	sudo mv spark-3.5.6-bin-hadoop3 spark
	sudo chown -R "$USER":"$USER" /opt/spark
fi

echo "=== Setting Up Hive (optional) ==="
if [ ! -d /opt/hive ]; then
	sudo wget -q https://downloads.apache.org/hive/hive-4.0.1/apache-hive-4.0.1-bin.tar.gz
	sudo tar -xzf apache-hive-4.0.1-bin.tar.gz
	sudo mv apache-hive-4.0.1-bin hive
	sudo chown -R "$USER":"$USER" /opt/hive
fi

echo "=== Configuring Environment Variables in $RC_FILE ==="
append_if_missing "export JAVA_HOME=/usr/lib/jvm/java-11-openjdk" "$RC_FILE"
append_if_missing "export HADOOP_HOME=/opt/hadoop" "$RC_FILE"
append_if_missing "export HADOOP_CONF_DIR=\$HADOOP_HOME/etc/hadoop" "$RC_FILE"
append_if_missing "export SPARK_HOME=/opt/spark" "$RC_FILE"
append_if_missing "export HIVE_HOME=/opt/hive" "$RC_FILE"
append_if_missing "export PATH=\$PATH:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin:\$SPARK_HOME/bin:\$SPARK_HOME/sbin:\$HIVE_HOME/bin" "$RC_FILE"

echo "=== Installing Pyenv (then wiring it into $RC_FILE) ==="
if [ ! -d "$HOME/.pyenv" ]; then
	curl -fsSL https://pyenv.run | bash
fi
append_if_missing 'export PATH="$HOME/.pyenv/bin:$PATH"' "$RC_FILE"
append_if_missing 'eval "$(pyenv init -)"' "$RC_FILE"
append_if_missing 'eval "$(pyenv virtualenv-init -)"' "$RC_FILE"

# Load env for current session
source "$RC_FILE" || true

echo "=== Installing Python 3.11.9 via pyenv and core Python packages ==="
pyenv install -s 3.11.9 || true
pyenv global 3.11.9 || true
python -m pip install --upgrade pip
pip install -q pyspark findspark jupyter pandas matplotlib seaborn

echo "=== Configuring Hadoop XMLs (core-site, hdfs-site, yarn-site, mapred-site) ==="
mkdir -p /opt/hadoop/dfs/name /opt/hadoop/dfs/data
sudo chown -R "$USER":"$USER" /opt/hadoop/dfs

sudo bash -c 'cat > /opt/hadoop/etc/hadoop/core-site.xml <<EOF
<?xml version="1.0"?>
<configuration>
	<property>
		<name>fs.defaultFS</name>
		<value>hdfs://localhost:9000</value>
	</property>
</configuration>
EOF'

sudo bash -c 'cat > /opt/hadoop/etc/hadoop/hdfs-site.xml <<EOF
<?xml version="1.0"?>
<configuration>
	<property>
		<name>dfs.replication</name>
		<value>1</value>
	</property>
	<property>
		<name>dfs.namenode.name.dir</name>
		<value>file:/opt/hadoop/dfs/name</value>
	</property>
	<property>
		<name>dfs.datanode.data.dir</name>
		<value>file:/opt/hadoop/dfs/data</value>
	</property>
</configuration>
EOF'

sudo bash -c 'cat > /opt/hadoop/etc/hadoop/yarn-site.xml <<EOF
<?xml version="1.0"?>
<configuration>
	<property>
		<name>yarn.nodemanager.aux-services</name>
		<value>mapreduce_shuffle</value>
	</property>
</configuration>
EOF'

sudo bash -c 'cat > /opt/hadoop/etc/hadoop/mapred-site.xml <<EOF
<?xml version="1.0"?>
<configuration>
	<property>
		<name>mapreduce.framework.name</name>
		<value>yarn</value>
	</property>
</configuration>
EOF'

echo "=== Setting JAVA_HOME in hadoop-env.sh ==="
if ! grep -q "^export JAVA_HOME=" /opt/hadoop/etc/hadoop/hadoop-env.sh; then
	echo "export JAVA_HOME=/usr/lib/jvm/java-11-openjdk" | sudo tee -a /opt/hadoop/etc/hadoop/hadoop-env.sh >/dev/null
else
	sudo sed -i 's|^export JAVA_HOME=.*|export JAVA_HOME=/usr/lib/jvm/java-11-openjdk|' /opt/hadoop/etc/hadoop/hadoop-env.sh
fi

echo "=== Formatting and Starting Hadoop Cluster ==="
if [ ! -d "/opt/hadoop/dfs/name/current" ]; then
	hdfs namenode -format -nonInteractive
fi
start-dfs.sh || true
start-yarn.sh || true

echo "✅ Hadoop + Spark (+ optional Hive) setup complete!"
echo "➡️  Open a new terminal or 'source $RC_FILE' to load environment variables."
echo "➡️  Then run: jupyter notebook"

