#!/bin/bash
# Create reports collection

POCKETBASE_URL="http://localhost:8090"
ADMIN_EMAIL="valov@example.com"
ADMIN_PASSWORD="GhbdtnRfrLtkf?1"

echo "🔐 Authenticating..."
TOKEN=$(curl -s -X POST "$POCKETBASE_URL/api/admins/auth-with-password" \
    -H "Content-Type: application/json" \
    -d "{\"identity\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}" | grep -o '"token":"[^"]*' | sed 's/"token":"//')

echo "📋 Getting collection IDs..."
COLLECTIONS=$(curl -s -X GET "$POCKETBASE_URL/api/collections" -H "Authorization: $TOKEN")

USERS_ID=$(echo "$COLLECTIONS" | grep -o '"id":"[^"]*"[^}]*"name":"users"' | head -1 | sed 's/"id":"\([^"]*\)".*/\1/')
MESSAGES_ID=$(echo "$COLLECTIONS" | grep -o '"id":"[^"]*"[^}]*"name":"messages"' | head -1 | sed 's/"id":"\([^"]*\)".*/\1/')

echo "Users ID: $USERS_ID"
echo "Messages ID: $MESSAGES_ID"
echo ""

read -p "Press Enter to create reports collection..."

echo "📦 Creating reports collection..."
curl -X POST "$POCKETBASE_URL/api/collections" \
    -H "Authorization: $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
  \"name\": \"reports\",
  \"type\": \"base\",
  \"schema\": [
    {\"name\": \"reportedBy\", \"type\": \"relation\", \"required\": true, \"options\": {\"collectionId\": \"$USERS_ID\", \"cascadeDelete\": false, \"maxSelect\": 1}},
    {\"name\": \"messageId\", \"type\": \"relation\", \"required\": true, \"options\": {\"collectionId\": \"$MESSAGES_ID\", \"cascadeDelete\": true, \"maxSelect\": 1}},
    {\"name\": \"messageOwnerId\", \"type\": \"relation\", \"required\": true, \"options\": {\"collectionId\": \"$USERS_ID\", \"cascadeDelete\": false, \"maxSelect\": 1}}
  ],
  \"listRule\": null,
  \"viewRule\": null,
  \"createRule\": \"reportedBy = @request.auth.id\",
  \"updateRule\": null,
  \"deleteRule\": null
}"

echo ""
echo "✅ Done! Check Admin UI"
