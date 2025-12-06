#!/bin/bash
POCKETBASE_URL="http://localhost:8090"
ADMIN_EMAIL="valov@example.com"
ADMIN_PASSWORD="GhbdtnRfrLtkf?1"

echo "Getting token..."
TOKEN=$(curl -s -X POST "$POCKETBASE_URL/api/admins/auth-with-password" \
    -H "Content-Type: application/json" \
    -d "{\"identity\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}" | grep -o '"token":"[^"]*' | sed 's/"token":"//')

echo "Token: $TOKEN"
echo ""
echo "Getting collections..."
curl -s -X GET "$POCKETBASE_URL/api/collections" -H "Authorization: $TOKEN" > collections.json

echo ""
echo "Collections saved to collections.json"
echo ""
echo "Looking for users collection..."
cat collections.json | grep -o '"id":"[^"]*","[^"]*","[^"]*","name":"users"'

echo ""
echo "Trying simpler grep..."
cat collections.json | grep '"name":"users"' -B 10 | grep '"id"'
