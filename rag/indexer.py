import os
import threading

import chromadb
import chromadb.utils.embedding_functions as embedding_functions
from chromadb.api.models.Collection import Collection
from confluent_kafka import Consumer
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroDeserializer
from confluent_kafka.serialization import SerializationContext, MessageField
from langchain_openai import OpenAIEmbeddings


def read_config(file):
    # reads the client configuration from client.properties
    # and returns it as a key-value map
    config = {}
    with open(file) as fh:
        for line in fh:
            line = line.strip()
            if len(line) != 0 and line[0] != "#":
                parameter, value = line.strip().split('=', 1)
                config[parameter] = value.strip()
    return config


def consume(topic, config, sr_config, record_consumer):

    schema_registry_client = SchemaRegistryClient(sr_config)

    avro_deserializer = AvroDeserializer(schema_registry_client)

    # creates a new consumer instance
    consumer = Consumer(config)

    # subscribes to the specified topic
    consumer.subscribe([topic])

    try:
        while True:
            # consumer polls the topic and prints any incoming messages
            msg = consumer.poll(1.0)
            if msg is not None and msg.error() is None and msg.key() is not None and msg.value() is not None:
                a= avro_deserializer(msg.value(), SerializationContext(msg.topic(), MessageField.VALUE))
                key=avro_deserializer(msg.key(), SerializationContext(msg.topic(), MessageField.KEY))
                print(key)
                print(a)
                record_consumer(str(key['key']),a)
    except KeyboardInterrupt:
        pass
    finally:
        # closes the consumer connection
        consumer.close()

def db(embeddings):
#    chroma_client = chromadb.Client()
    chroma_client = chromadb.HttpClient(host=os.environ['CHROMA_HOST'], port=8000)

    collection: Collection = chroma_client.create_collection(name="products", embedding_function=embeddings, get_or_create=True)
    return (chroma_client,collection)

def consume_records_builder(products: Collection):
    def consume_record(k,r):
        if r['uri'] is None : return
        if r['available_for_order'] :
            products.upsert(
                documents=[
                    (r['description_short'] or "") + (r['description'] or "")
                ],
                #metadatas={'url': os.environ['SHOP_BASE_URL'] + r['uri']},
                metadatas={'url': os.environ['SHOP_BASE_URL'] + r['uri'],'price': float(r['price'])},
                ids=[k],
            )
        else:
            products.delete(ids=[k])

    return consume_record




def main():
    config = read_config("client.properties")
    sr_config = read_config("sr.properties")
    topic = "products"

    openai_ef = embedding_functions.OpenAIEmbeddingFunction(
        api_key=os.getenv("OPENAI_API_KEY"),
        model_name="text-embedding-3-large"
    )

    (client, products) = db(openai_ef)
    consume(topic, config, sr_config, consume_records_builder(products))



main()
