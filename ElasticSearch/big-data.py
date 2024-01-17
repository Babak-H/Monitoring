'''
what is big data:
5 V => Volume , Velocity, Variety , Veracity , Value

Volume => massive amount of data, terabytes, petabytes,...
1 terabyte => 1000 gigabytes

Velocity => the speed that data is being generated, and the speed at which data is moved around

Variety => the different types of data that are available today.
structured, semi-structured, un-structured (videos, text files, sound files)

Veracity => quality and accuracy of data, can we trust this data?

Value => how can we extract value from big data

one of the biggest issues with Big Data is the lack of scalability in the system.


Data Storage solutions :
multiple databases for different bussines needs
centralized data repository, data warehouse
data lake => can store : structured, semi-structured, un-structured data types => single source of truth


Apache Spark :
=> Distributed computing engine
=> works with variety of data sources
=> accessable through many languages and APIs (R, Python, Scala, SQL)

A spark cluster is a set of computational resources that will power your queries.
when you need to run a spark query, you have to create a cluster for it first.
'''

# singer
import json

database_address = {
    "host": "10.0.0.5",
    "port": 8456
}

# Open the configuration file in writable mode
with open("database_config.json", "w") as fh:
    # Serialize the object in this file handle
    json.dump(obj=database_address, fp=fh)
