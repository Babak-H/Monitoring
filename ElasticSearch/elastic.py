
from elasticsearch import Elasticsearch

# CREATING ELASTICSEARCH CONNECTION
host = '192.168.1.12'
port =9200
es = Elasticsearch([{'host':host, 'port':port}])
es.cat.indices()

# Creating ingesting pipeline
body = {
  "description" : "Extract attachment information",
  "processors" : [
    {
      "attachment" : {
        "field" : "data"
      }
    }
  ]
}
es.index(index='_ingest', doc_type='pipeline', id='attachment', body=body)

# Pushin some example documents
result1 = es.index(index='my_index', doc_type='my_type', pipeline='attachment',
                  body={'data': "e1xydGYxXGFuc2kNCkxvcmVtIGlwc3VtIGRvbG9yIHNpdCBhbWV0DQpccGFyIH0="})
result1

# _source_exclude not retrive source file.
es.get(index='my_index', doc_type='my_type', id=result1['_id'], _source_exclude=['data'])


# Dowloading PDF file
import requests
url = 'http://www.cbu.edu.zm/downloads/pdf-sample.pdf'
response = requests.get(url)

# Transforming it into base64 encoding
import base64

data = base64.b64encode(response.content).decode('ascii')


result2 = es.index(index='my_index', doc_type='my_type', pipeline='attachment',
                  body={'data': data})
result2

doc = es.get(index='my_index', doc_type='my_type', id=result2['_id'], _source_exclude=['data'])
doc

es.search(index='my_index', doc_type='my_type', q='Adobe', _source_exclude=['data'])

print(doc['_source']['attachment']['content'])
# From stackoverflow
import base64
from uuid import uuid4
from elasticsearch.client.ingest import IngestClient
from elasticsearch.exceptions import NotFoundError

from elasticsearch_dsl import analyzer, DocType, Index
from elasticsearch_dsl.connections import connections
from elasticsearch_dsl.field import Attachment, Text



# Establish a connection
host = '192.168.1.12'
port = 9200
es = connections.create_connection(host=host, port=port)

# Some custom analyzers
html_strip = analyzer('html_strip', tokenizer="standard", filter=["standard", "lowercase", "stop", "snowball"],
                      char_filter=["html_strip"])
lower_keyword = analyzer('keyword', tokenizer="keyword", filter=["lowercase"])


class ExampleIndex(DocType):
    class Meta:
        index = 'example'
        doc_type = 'Example'

    id = Text()
    uuid = Text()
    name = Text()
    town = Text(analyzer=lower_keyword)
    my_file = Attachment(analyzer=html_strip)


def save_document(doc):
    """

    :param obj doc: Example object containing values to save
    :return:
    """
    try:
        # Create the Pipeline BEFORE creating the index
        p = IngestClient(es)
        p.put_pipeline(id='myattachment', body={
            'description': "Extract attachment information",
            'processors': [
                {
                    "attachment": {
                        "field": "my_file"
                    }
                }
            ]
        })

        # Create the index. An exception will be raise if it already exists
        i = Index('example')
        i.doc_type(ExampleIndex)
        i.create()
    except Exception:
        # todo - should be restricted to the expected Exception subclasses
        pass

    indices = ExampleIndex()
    try:
        s = indices.search()
        r = s.query('match', uuid=doc.uuid).execute()
        if r.success():
            for h in r:
                indices = ExampleIndex.get(id=h.meta.id)
                break
    except NotFoundError:
        # New record
        pass
    except Exception:
        print("Unexpected error")
        raise

    # Now set the doc properties
    indices.uuid = doc.uuid
    indices.name = doc.name
    indices.town = doc.town
    if doc.my_file:
        with open(doc.my_file, 'rb') as f:
            contents = f.read()
        indices.my_file = base64.b64encode(contents).decode("ascii")

    # Save the index, using the Attachment pipeline if a file was attached
    return indices.save(pipeline="myattachment") if indices.my_file else indices.save()


class MyObj(object):
    uuid = uuid4()
    name = ''
    town = ''
    my_file = ''

    def __init__(self, name, town, file):
        self.name = name
        self.town = town
        self.my_file = file


me = MyObj("Steve", "London", '/home/steve/Documents/test.txt')

res = save_document(me)
