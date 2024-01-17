# Install Prometheus

sudo useradd \
--system \   # this is a system account
--no-create-home \   # do not create a home directory for this user
--shell /bin/false prometheus  # do not allow this user to login

# download prometheus via wget
wget https://github.com/prometheus/prometheus/releases/download/v2.32.1/prometheus-2.32.1.linux-amd64.tar.gz

# unzip the prometheus folder
tar -xvf prometheus-2.32.1.linux-amd64.tar.gz

# create data and /etc/prometheus folder that are needed 
# data is where the database files of prometheus will be saved
sudo mkdir -p /data /etc/prometheus

# move to the unzipped folder
cd prometheus-2.32.1.linux-amd64

# move prometheus binary and promtool to the local bin folder
sudo mv prometheus promtool /usr/local/bin

# for extra console templates for prometheus
sudo mv consoles/ console_libraries/ /etc/prometheus/

# move the main prom yaml file (its config file) to the /etc folder
sudo mv prometheus.yml /etc/prometheus/prometheus.yml

# give full access to /etc/prometheus/ and /data directories
sudo chown -R prometheus:prometheus /etc/prometheus/ /data/

# remove the zipped and unzipped folders
cd
rm -rf prometheus*

# here we create a systemd process file for prometheus, so we can easily start and stop it
sudo vim /etc/systemd/system/prometheus.service

####################################  prometheus.service file
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

StartLimitIntervalSec=500
StartLimitBurst=5

[Service]
User=prometheus
Group=prometheus
Type=simple
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/data \
  --web.console.templates=/etc/prometheus/consoles \ 
  --web.console.libraries=/etc/prometheus/console_libraries \
  --web.listen-address=0.0.0.0:9090 \  # where should prometheus listen to
  --web.enable-lifecycle  # allows prometheus to reload configuration without restarting the whole application

[Install]
WantedBy=multi-user.target
####################################

# enable the prometheus service
sudo systemctl enable prometheus

# start prometheus
sudo systemctl start prometheus

# make sure it is running
sudo systemctl status prometheus

# in case of any issues, check the logs related to prometheus and search for errors
journalctl -u prometheus -f --no-pager

# to check the prometheus webUI go here: http://<IP-ADDRESS>:9090
# the only target here is prometheus itself, it is scraping its own api each 15 seconds


# Install NodeExporter
# node exporter is used to collect linux system metrics such as cpu load and disk I/O

# create node exporter username
sudo useradd \
     --system \
     --no-create-home \
     --shell /bin/false node_exporter

# download node exporter and unzip it
wget https://github.com/prometheus/node_exporter/releases/download/v1.3.1/node_exporter-1.3.1.linux-amd64.tar.gz
tar -xvf node_exporter-1.3.1.linux-amd64.tar.gz

# move node exporter binary also to /local/bin
sudo mv \
  node_exporter-1.3.1.linux-amd64/node_exporter \
  /usr/local/bin

# then clean up
rm -rf node_exporter*

# make sure you can run the binary
node_exporter --version

# we also create systemd service file for node exporter
sudo vim /etc/systemd/system/node_exporter.service

####################################  node_exporter.service file
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

StartLimitIntervalSec=500
StartLimitBurst=5

[Service]
User=node_exporter
Group=node_exporter
Type=simple
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/bin/node_exporter \
    --collector.logind

[Install]
WantedBy=multi-user.target
####################################

# enable the service, start it and check its status
sudo systemctl enable node_exporter
sudo systemctl start node_exporter
sudo systemctl status node_exporter

# same as prometheus, check journalctl in case of any errors
journalctl -u node_exporter -f --no-pager

# as of now, we only have on target for prometheus (itself), here we add a new static target to it
# node exporter is exposed on port 9100, so prometheus will read its metrics from there
sudo vim /etc/prometheus/prometheus.yml

# prometheu.yml
...
  - job_name: node_export   # each job in prometheus is a new data source
    static_configs:
      - targets: ["localhost:9100"]

# check to make sure the prometheus config is correct
promtool check check config /etc/prometheus/prometheus.yml

# after any change to prometheus config, we have to relaod it
curl -X POST http://localhost:9090/-/reload

# now go to prometheus webUI, there should be a new target

# Install Grafana

# install the dependancies
sudo apt-get install -y apt-transport-https software-properties-common

# add GPG key
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -

# add grafana repository to apt-get links
echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list

# now install grafana from apt-get
sudo apt-get update
sudo apt-get -y install grafana

# enable grafana-server
sudo systemctl enable grafana-server
sudo systemctl start grafana-server
sudo systemctl status grafana-server

'''
you can login to grafana at http://<IP-ADDRESS>:3000 , default username/password are "admin"
to add data source for visualization:
        - click Add data source
        - select prometheus
        - add url http://localhost:9090
        - now metrics should be visible
'''

# another way is to save these configurations in a yaml file to create a data source for grafana
sudo vim /etc/grafana/provisioning/datasources/datasources.yaml

################################
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    url: http://localhost:9090
    isDefault: true
################################

# restart grafana to reload this new config
sudo systemctl restart grafana-server


# Secure Prometheus with Basic Auth
# prometheus doesn't save your passwords, it compares it's hash to the one that it saves

# install bcrypt python module, for hashing the password
sudo apt-get install python3-bcrypt

# create a simple script to return password hash
vim generate_password.py

#######################
import getpass
import bcrypt

password = getpass.getpass("password: ")
hashed_password = bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt())
print(hashed_password.decode())
#########################

# give it the custom password
python3 generate_password.py

# save the hash in a prometheus configuration file
# "admin" is the current username
sudo vim /etc/prometheus/web.yml

###########################
---
basic_auth_users:
    admin: $2b$12$CVcceMyfix1Qa7Kupisfe.JVHXG.U4PWFUculUnGlxPrTlBxfNGRe
###########################

# next we have to update the prometheus service file for authentication to work
sudo vim /etc/systemd/system/prometheus.service

##########################
...
ExecStart=/usr/local/bin/prometheus \
  ...
  --web.config.file=/etc/prometheus/web.yml  #add it in the last line of ExecStart commaand
##########################

# reload the service
sudo systemctl daemon-reload
# restart prometheus
sudo systemctl restart prometheus
# check status to make sure it is working
sudo systemctl status prometheus

# now if you go to the prometheus webUI, it requires username and password to login

# next we add password for prometheus to grafana data sources, so it can read from there
sudo vim /etc/grafana/provisioning/datasources/datasources.yaml

###########################
---
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    url: http://localhost:9090
    isDefault: true
    basicAuth: true
    basicAuthUser: admin
    secureJsonData:
      basicAuthPassword: devops123
#########################

# then restart grafana for changes to take effect
sudo systemctl restart grafana-server

# next we have to add username/password to the job section of prometheus config file, since prometheus needs authentication to scrape its own metrics
sudo vim /etc/prometheus/prometheus.yml
###########################
...
  - job_name: "prometheus"
    basic_auth:
      username: admin
      password: devops123
    static_configs:
      - targets: ["localhost:9090"]
#########################

# check to make sure there is no error
promtool check config /etc/prometheus/prometheus.yml

# reload the perometheus
curl -X POST -u admin:devops123 http://localhost:9090/-/reload

# now grafana should be able to read metrics from prometheus


# Install AlertManager
# we use Alertmanager to send alerts to email,slack,... it integrates with prometheus

# create user for alert manager
sudo useradd \
     --system
     --no-create-home \
     --shell /bin/false alertmanager

# download alert manager zip file and unzip it
wget https://github.com/prometheus/alertmanager/releases/download/v0.23.0/alertmanager-0.23.0.linux-amd64.tar.gz
tar -xvf alertmanager-0.23.0.linux-amd64.tar.gz

# for alertmanager we need a data forlder to save its notifications,... and also a folder in /etc
sudo mkdir -p /alertmanager-data /etc/alertmanager

# move alertmanager executable and config files
sudo mv alertmanager-0.23.0.linux-amd64/alertmanager /usr/local/bin/
sudo mv alertmanager-0.23.0.linux-amd64/alertmanager.yml /etc/alertmanager/

# remove the zip files
rm -rf alertmanager*

# check if you can run it
alertmanager --version

# create systemd service for it
sudo vim /etc/systemd/system/alertmanager.service

##################################
[Unit]
Description=Alertmanager
Wants=network-online.target
After=network-online.target

StartLimitIntervalSec=500
StartLimitBurst=5

[Service]
User=alertmanager
Group=alertmanager
Type=simple
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/bin/alertmanager \
  --storage.path=/alertmanager-data \
  --config.file=/etc/alertmanager/alertmanager.yml

[Install]
WantedBy=multi-user.target
##################################

# enable and start alertmanager service
sudo systemctl enable alertmanager
sudo systemctl start alertmanager
sudo systemctl status alertmanager

# alertmanager will be exposed at http://<IP_ADDRESS>:9093
