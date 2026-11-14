#!/bin/bash
# Usage: ./search.sh "your question"
OLLAMA_URL=${OLLAMA_URL:-http://localhost:11434}

question_embedding=$(curl -s "$OLLAMA_URL/api/embed" \
    -d "$(jq -n --arg t "$1" '{model: "nomic-embed-text", input: $t}')" \
  | jq -r '.embeddings[0] | "{" + (map(tostring) | join(",")) + "}"')

psql -d aidb -v q="$question_embedding" <<'SQL'
SELECT round(cosine_similarity(embedding, :'q')::numeric, 3) AS similarity,
       content
FROM sentences
ORDER BY similarity DESC;
SQL
