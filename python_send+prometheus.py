#!/usr/bin/python

import requests
import json
import time

md_url = "http://localhost:8008"
Apikey = "***************************"
prefix = "metadefender"
env = "alpha"
default_inactive_engines = ["compression_13_windows", "dlp_13_windows", "oesis_13_windows"]

# Issue a request to the given Meta Defender api and return the response in json
def request_endpoint(path, Apikey):
    try:
        response = requests.get(md_url+path, headers={'apikey': Apikey})
        res_json = json.loads(response.text)
        return res_json
    except Exception as ex:
        print 'ERROR: Failed to request endpoint [%s]' % path
        print 'Exception: ', str(ex)
    return {}

def write_metrics():
    metrics_list = []
    # Get MD current load and queue
    try:
        res = request_endpoint("/stat/nodes", Apikey)
        load = res["statuses"][0]["load"]
        scan_queue = res["statuses"][0]["scan_queue"]

        metrics_list.append({"load": load})
        metrics_list.append({"scan_queue": scan_queue})
    except Exception as ex:
        print "ERROR: Failed to get load or queue metrics"
        print 'Exception: ', str(ex)
        
    # Get the number of active/inactive engines
    try:
        active_engines = 0
        inactive_engines = 0
        res = request_endpoint("/stat/nodes", Apikey)

        for engine in res["statuses"][0]["engines"]:
            if engine["id"] not in default_inactive_engines:
                if engine["active"] is True:
                    active_engines += 1
                else:
                    inactive_engines += 1

        metrics_list.append({"active_engines": active_engines})
        metrics_list.append({"inactive_engines": inactive_engines})
    except Exception as ex:
        print "ERROR: Failed to get the number of active/inactive engines"
        print 'Exception: ', str(ex)
        
    # Get the version
    try:
        res = request_endpoint("/stat/nodes", Apikey)
        ver = res["statuses"][0]["version"]
        metrics_list.append({"version": ver})
    except Exception as ex:
        print "ERROR: Failed to get the version"
        print 'Exception: ', str(ex)
        
    # Get the uptime
    try:
        res = request_endpoint("/stat/nodes", Apikey)
        uptime = res["statuses"][0]["uptime"]
        metrics_list.append({"uptime": uptime})
    except Exception as ex:
        print "ERROR: Failed to get the uptime"
        print 'Exception: ', str(ex)
        
    # Get the total scan queue
    try:
        res = request_endpoint("/stat/nodes", Apikey)
        total_scan_queue = res["statuses"][0]["total_scan_queue"]
        metrics_list.append({"total_scan_queue": total_scan_queue})
    except Exception as ex:
        print "ERROR: Failed to get the uptime"
        print 'Exception: ', str(ex)
        
    # Get MD license info
    try:
        res = request_endpoint("/admin/license", Apikey)
        #deployment = res.get("deployment")
        days_left = res.get("days_left", 0)

        if res.get("online_activated"):
            online_activated = 0
        else:
            online_activated = 1

        metrics_list.append({"online_activated": online_activated})
        metrics_list.append({"days_left": days_left})
    except Exception as ex:
        print "ERROR: Failed to get license info"
        print 'Exception: ', str(ex)
        
    # Get the total number of processed objects by the MD
    try:
        total_processed = 0
        res = request_endpoint("/stat/status", Apikey)
        total_processed = res["data"]["statistics"]["summary"]["total_processed"]

        metrics_list.append({"total_processed": total_processed})
    except Exception as ex:
        print "ERROR: Failed to get the total number of processed objects"
        print 'Exception: ', str(ex)
        
    # nburnham: Get Average processing time of files, last 50 scans
    try:
        process_times = []
        res = request_endpoint("/stat/log/scan", Apikey)
        scanned_file_list = res["scans"]

        for i in scanned_file_list:
            p_time = i["scan_results"]["total_time"]
            process_times.append(p_time)
        average_file_proccessing_time = sum(process_times) / len(process_times)
        metrics_list.append({"average_file_proccessing_time": average_file_proccessing_time})
    except Exception as ex:
        print "ERROR: Failed to get the file process duration"
        print 'Exception: ', str(ex)
    
    with open("./prommetrics/metrics.prom", 'w') as f:
        f.seek(0)
        for metric in metrics_list:
            name = metric.keys()[0]
            value = metric.values()[0]
            metric_str = "{name}{{role=\"{prefix}\",env=\"{env}\"}} {value}\n".format(prefix=prefix,name=name,value=value, env=env)
            f.write(metric_str) 
        f.truncate()


if __name__ == '__main__':
    while True:
        write_metrics()
        time.sleep(10)  # Adjust the interval as needed
        
# curl --request GET --url 'http://localhost:8008/stat/nodes' --header 'apikey:**********************' | jq

