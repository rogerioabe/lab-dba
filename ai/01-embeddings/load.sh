#!/bin/bash
# Embeds each line of sentences.txt with Ollama and stores it in PostgreSQL.
OLLAMA_URL=${OLLAMA_URL:-http://localhost:11434}

while read -r sentence; do
  # 1. Ask Ollama for the embedding and turn the JSON array into a PostgreSQL array literal: {0.1,0.2,...}
  embedding=$(curl -s "$OLLAMA_URL/api/embed" \
      -d "$(jq -n --arg t "$sentence" '{model: "nomic-embed-text", input: $t}')" \
    | jq -r '.embeddings[0] | "{" + (map(tostring) | join(",")) + "}"')

  # 2. Insert it; psql variables (:'t', :'e') quote the values safely.
  psql -d aidb -q -v t="$sentence" -v e="$embedding" <<'SQL'
INSERT INTO sentences (content, embedding) VALUES (:'t', :'e');
SQL
  echo "loaded: $sentence"
done < sentences.txt
