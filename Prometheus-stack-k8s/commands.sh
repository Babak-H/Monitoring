# deploy redis and nodejs applications (we will scrape thess applications later)
kubectl apply -f redis.yml
kubectl apply -f node-app.yml

# use these commands to add prometheus operator helm chart (which includes all needed services) to the cluster
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# update the repository
helm repo update

# create prometheus cluster in its own namespace. so it won't be mixed we the main cluster
kubectl create namespace monitoring

# install the prometheus stack
# -n at the end specifies the name space to install it
# local name => monitoring
# repo name => prometheus-community/kube-prometheus-stack
helm install monitoring prometheus-community/kube-prometheus-stack -n monitoring



# show the installed charts
helm ls -n monitoring
kubectl get all -n monitoring
# here we can see all the deployments related to prometheus-kibana and also statefulsets related to alertManager and prometheus (its database for saving metrics)

# get all the configmaps related to the prometheus stack
kubectl get configmap -n monitoring
# prometheus-monitoring-kube-prometheus-prometheus-rulefiles-0 => the default monitoring rules file

# automatically generated secrets of the cluster (certificates, user/pass,..)
kubectl get secret -n monitoring

# the Custom Resource Definitions (CRD) for the cluster
kubectl get crd -n monitoring

# view the prometheus statefulSet configurations (converted to YAML file)
kubectl describe statefulset prometheus-monitoring-kube-prometheus-prometheus -n monitoring > prom.yml

# view the prometheus operator configurations
# the "prometheus" docker container runs from this file
# we also have "config-reloader" sidecar container here, it forces prometheus to reload each time we change some configuration
kubectl describe deployment monitoring-kube-prometheus-operator -n monitoring > oper.yml

 # prometheus operator extends the Kubernetes API => 
    # we create custom kubernetes resources => 
      # operator takes our custom resources and tells prometheus to reload its alert rules


# make prometheusUI available through port forwarding of its service to localhost
# & is for make the service running in the background
kubectl port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090 -n monitoring &  
# 127.0.0.1:9090

# "http://127.0.0.1:9090/config" the prometheus configuration can be viewed here
# scrape_configs / job => collection of instances that we want to scrape, with specific endpoint address and intervals,...
# an instance is an endpoint you can scrape (/metric, /health, ..)

# make Grafana avaialable through port forwarding of its service to localhost
kubectl port-forward service/monitoring-grafana 8080:80 -n monitoring  
# 127.0.0.1:8080

 # default user/pass for grafana
 # username: admin
 # password: prom-operator


# **** by default prometheus will scrape endpoints for all the pods/deployments in all namespaces (including itself) 
# as long as those namespaces having the /metric endpoint exposed (or having some sort of exporter)


# here we create a new deployment to test our cpu and memory usage
# run the image in interactive mode (-i --tty), remove it from cluster when we exit it (--rm)
kubectl run curl-test --image=radial/busyboxplus:curl -i --tty --rm
# create a simple script inside the pod
vi test.sh

# this will curl our application endpoint for 3000 times in a short loop
for i in $(seq 1 3000)
do
    curl [TARGET-SERVICE-ENDPOINT] > test.txt
done

# execute the script, now inside of the Grafana we should see spike of usage for the target pod
chmod +x test.sh
./test.sh

# another way of ramping up cpu usage for testing
# here we run docker image as a pod directly, without writing a yaml config file for it
kubectl run cpu-test --image=containerstack/cpustress -- --cpu 4 --timeout 30s --metric-brief


# prometheus stacks comes with a list of already applied Alerts that can be triggered, but we can also add extra alerts to the stack through yaml configuration files
# normally we should only write new alert rules to the main alerts files of prometheus, but because we are running it through kubernetes, we can create alerts in the form of CRDs and add them to the prometheus operator
# apply prometheus alert_rules file
kubectl apply -f alert_rules.yml

# check to see the object is created (shows all existing prometheus rules)
kubectl get PrometheusRule -n monitoring

# looking at the alert_manager UI
kubectl port-forward svc/monitoring-kube-prometheus-alertmanager -n monitoring 9093:9093 &   
# 127.0.0.1:9093

# alertmanager is its own application, and has a config file separate from prometheus
# this is our original alert manager  configuration file
kubectl get secret alertmanager-monitoring-kube-prometheus-alertmanager-generated -n monitoring -o yaml
 
# apply the alert manager config file (for sending alert emails) after this users should receive alert emails in case of the alert rules apply
# this is also a kubernetes CRD that we apply to alertmanager operator, it adds the new config to already existing alertmanager
kubectl apply -f email-secret.yaml
kubectl apply -f alert-manager-configuration.yaml

# view the CRD created for alertmanager
kubectl get alertmanagerconfig -n monitoring

# reload the configuration for alert-manager
# alertmanager-monitoring-kube-prometheus-alertmanager-0 => name of the alertmanager pod
kubectl logs alertmanager-monitoring-kube-prometheus-alertmanager-0 -n monitoring -c config-reloader

# by default we have several service monitors (needed for exporters) enabled in prom cluster
kubectl get servicemonitor -n monitoring

# to monitor the REDIS database inside our cluster we need extra packages to connect prometheus to redis endpoint since prometheus can't directly read redis logs
# this is called "Exporter", we use redis-exporter here
# here we use redis-exporter helm chart
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
# now install the chart with custom values inside the same namespace as redis-cart 
helm install redis-exporter prometheus-community/prometheus-redis-exporter -f redis-values.yml

# the pod "redis-exporter-prometheus-redis-exporter" should be running
kubectl get pod

# apply redis alert rules file
kubectl apply -f redis-rules.yml


'''
how to send metrics from custom application to prometheus

1. expose metrics for the app via using prom client library in the app and exposing metrics on /metric endpoint
2. deploy app to the cluster
3. *** Configure prometheus to Scrape new target (using ServiceMonitor) ***
'''
# create the serviceMonitor,so that prometheus can scrape our NodeJS app
kubectl apply -f node-service-monitor.yml