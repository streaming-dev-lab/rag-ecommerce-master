import os
import chromadb 
import pandas as pd

class ChromaPeek:
    def __init__(self, path):
        #self.client = chromadb.PersistentClient(path)
        self.client = chromadb.HttpClient(host=os.environ['CHROMA_HOST'], port=8000)
    ## function that returs all collection's name
    def get_collections(self):
        collections = []

        for i in self.client.list_collections():
            collections.append(i)
        
        return collections
    
    ## function to return documents/ data inside the collection
    def get_collection_data(self, collection_name, dataframe=False):
        data = self.client.get_collection(name=collection_name).get(include=["embeddings","metadatas", "documents"])
        if dataframe:
            arr_t=[]
            for a in data['embeddings']:
                arr_t.append(a)
            #print(arr_t)
            data['embeddings']=arr_t
            #print(data['embeddings'])
            data['included'].extend([''] * (len(data['ids']) - len(data['included'])))
            print(data)
            return pd.DataFrame(data)
        return data
    
    ## function to query the selected collection
    def query(self, query_str, collection_name, k=3, dataframe=False):
        collection = self.client.get_collection(collection_name)
        res = collection.query(
            query_texts=[query_str], n_results=min(k, len(collection.get()))
        )
        out = {}
        for key, value in res.items():
            if value:
                out[key] = value[0]
            else:
                out[key] = value
        if dataframe:
            return pd.DataFrame(out)
        return out
