#!/bin/bash
# Create slots collection

POCKETBASE_URL="http://localhost:8090"
ADMIN_EMAIL="valov@example.com"
ADMIN_PASSWORD="GhbdtnRfrLtkf?1"

echo "🔐 Authenticating..."
TOKEN=$(curl -s -X POST "$POCKETBASE_URL/api/admins/auth-with-password" \
    -H "Content-Type: application/json" \
    -d "{\"identity\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}" | grep -o '"token":"[^"]*' | sed 's/"token":"//')

echo "📋 Getting users collection ID..."
COLLECTIONS_JSON=$(curl -s -X GET "$POCKETBASE_URL/api/collections" -H "Authorization: $TOKEN")
USERS_ID=$(echo "$COLLECTIONS_JSON" | sed 's/.*"id":"\([^"]*\)"[^}]*"name":"users".*/\1/')

echo "Users ID: $USERS_ID"
echo ""

read -p "Press Enter to create slots collection..."

echo "📦 Creating slots collection..."
curl -X POST "$POCKETBASE_URL/api/collections" \
    -H "Authorization: $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
  \"name\": \"slots\",
  \"type\": \"base\",
  \"schema\": [
    {\"name\": \"tutorId\", \"type\": \"relation\", \"required\": true, \"options\": {\"collectionId\": \"$USERS_ID\", \"cascadeDelete\": false, \"maxSelect\": 1}},
    {\"name\": \"date\", \"type\": \"date\", \"required\": true},
    {\"name\": \"startTime\", \"type\": \"text\", \"required\": true, \"options\": {\"min\": 5, \"max\": 5}},
    {\"name\": \"endTime\", \"type\": \"text\", \"required\": true, \"options\": {\"min\": 5, \"max\": 5}},
    {\"name\": \"isBooked\", \"type\": \"bool\", \"required\": false},
    {\"name\": \"isPaid\", \"type\": \"bool\", \"required\": false},
    {\"name\": \"studentId\", \"type\": \"relation\", \"required\": false, \"options\": {\"collectionId\": \"$USERS_ID\", \"cascadeDelete\": false, \"maxSelect\": 1}}
  ],
  \"listRule\": \"@request.auth.id != \\\"\\\"\",
  \"viewRule\": \"@request.auth.id != \\\"\\\"\",
  \"createRule\": \"tutorId = @request.auth.id\",
  \"updateRule\": \"tutorId = @request.auth.id || studentId = @request.auth.id\",
  \"deleteRule\": \"tutorId = @request.auth.id\"
}"

echo ""
echo "✅ Done! Check Admin UI"
