#!/bin/bash

apt-get update

# Install node-exporter

useradd --system --shell /sbin/nologin node_exporter

cd /tmp

wget https://github.com/prometheus/node_exporter/releases/download/v1.3.1/node_exporter-1.3.1.linux-amd64.tar.gz
tar -xvzf node_exporter-1.3.1.linux-amd64.tar.gz

cd node_exporter*/

cp node_exporter /usr/local/bin/

chown node_exporter:node_exporter /usr/local/bin/node_exporter

cat > /etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Node Exporter

[Service]
User=node_exporter
Group=node_exporter
EnvironmentFile=-/etc/sysconfig/node_exporter
ExecStart=/usr/local/bin/node_exporter $OPTIONS

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start node_exporter
systemctl enable node_exporter

# Install Prometheus

useradd --system --shell /sbin/nologin prometheus

cd /tmp

wget https://github.com/prometheus/prometheus/releases/download/v2.32.1/prometheus-2.32.1.linux-amd64.tar.gz
tar -xvzf prometheus-2.32.1.linux-amd64.tar.gz

cd prometheus*/

cp prometheus promtool /usr/local/bin/

chown prometheus:prometheus /usr/local/bin/prometheus /usr/local/bin/promtool

mkdir /var/lib/prometheus

for i in rules rules.d files_sd; do mkdir -p /etc/prometheus/${i}; done

cp /vagrant/prometheus.yml /etc/prometheus/prometheus.yml
cp -r consoles/ console_libraries/ /etc/prometheus/

for i in rules rules.d files_sd; do chown -R prometheus:prometheus /etc/prometheus/${i}; done
for i in rules rules.d files_sd; do chmod -R 775 /etc/prometheus/${i}; done
chown -R prometheus:prometheus /var/lib/prometheus/

cat > /etc/systemd/system/prometheus.service <<EOF
[Unit]
Description=Prometheus
Documentation=https://prometheus.io/docs/introduction/overview/
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=prometheus
Group=prometheus
ExecReload=/bin/kill -HUP \$MAINPID
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus \
  --web.console.templates=/etc/prometheus/consoles \
  --web.console.libraries=/etc/prometheus/console_libraries \
  --web.listen-address=0.0.0.0:9090 \
  --web.external-url=

SyslogIdentifier=prometheus
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start prometheus
systemctl enable prometheus

# Install Grafana

apt-get install -y adduser libfontconfig1

cd /tmp

wget https://dl.grafana.com/oss/release/grafana_8.3.4_amd64.deb
dpkg -i grafana_8.3.4_amd64.deb

systemctl enable  grafana-server
systemctl start  grafana-server
