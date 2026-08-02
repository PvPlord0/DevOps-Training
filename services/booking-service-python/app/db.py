import os
from pymongo import MongoClient

_client = None

def get_db():
    global _client
    if _client is None:
        _client = MongoClient(os.environ.get("MONGO_URI", "mongodb://localhost:27017"))
    return _client[os.environ.get("MONGO_DB", "eventhub_bookings")]
