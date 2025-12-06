#!/bin/bash
# Create messages collection

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

read -p "Press Enter to create messages collection..."

echo "📦 Creating messages collection..."
curl -X POST "$POCKETBASE_URL/api/collections" \
    -H "Authorization: $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
  \"name\": \"messages\",
  \"type\": \"base\",
  \"schema\": [
    {\"name\": \"chatRoomId\", \"type\": \"text\", \"required\": true, \"options\": {\"min\": 1, \"max\": 100}},
    {\"name\": \"senderId\", \"type\": \"relation\", \"required\": true, \"options\": {\"collectionId\": \"$USERS_ID\", \"cascadeDelete\": false, \"maxSelect\": 1}},
    {\"name\": \"senderEmail\", \"type\": \"text\", \"required\": true, \"options\": {\"max\": 200}},
    {\"name\": \"receiverId\", \"type\": \"relation\", \"required\": true, \"options\": {\"collectionId\": \"$USERS_ID\", \"cascadeDelete\": false, \"maxSelect\": 1}},
    {\"name\": \"message\", \"type\": \"text\", \"required\": true, \"options\": {\"max\": 5000}},
    {\"name\": \"type\", \"type\": \"select\", \"required\": true, \"options\": {\"maxSelect\": 1, \"values\": [\"text\", \"image\", \"audio\"]}},
    {\"name\": \"isRead\", \"type\": \"bool\", \"required\": false}
  ],
  \"listRule\": \"senderId = @request.auth.id || receiverId = @request.auth.id\",
  \"viewRule\": \"senderId = @request.auth.id || receiverId = @request.auth.id\",
  \"createRule\": \"senderId = @request.auth.id\",
  \"updateRule\": \"receiverId = @request.auth.id\",
  \"deleteRule\": \"senderId = @request.auth.id\"
}"

echo ""
echo "✅ Done! Check Admin UI"
