"""Get an embedding from Ollama (the Python version of the curl + jq in load.sh)."""
import os

import requests

OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://localhost:11434")
MODEL = "nomic-embed-text"


def get_embedding(text):
    """Return the embedding of one text as a list of floats."""
    response = requests.post(f"{OLLAMA_URL}/api/embed",
                             json={"model": MODEL, "input": text},
                             timeout=60)
    response.raise_for_status()          # stop with an error on HTTP 4xx / 5xx
    return response.json()["embeddings"][0]
