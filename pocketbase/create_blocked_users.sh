#!/bin/bash
# Create blocked_users collection

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

read -p "Press Enter to create blocked_users collection..."

echo "📦 Creating blocked_users collection..."
curl -X POST "$POCKETBASE_URL/api/collections" \
    -H "Authorization: $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
  \"name\": \"blocked_users\",
  \"type\": \"base\",
  \"schema\": [
    {\"name\": \"userId\", \"type\": \"relation\", \"required\": true, \"options\": {\"collectionId\": \"$USERS_ID\", \"cascadeDelete\": true, \"maxSelect\": 1}},
    {\"name\": \"blockedUserId\", \"type\": \"relation\", \"required\": true, \"options\": {\"collectionId\": \"$USERS_ID\", \"cascadeDelete\": true, \"maxSelect\": 1}}
  ],
  \"listRule\": \"userId = @request.auth.id\",
  \"viewRule\": \"userId = @request.auth.id\",
  \"createRule\": \"userId = @request.auth.id\",
  \"updateRule\": null,
  \"deleteRule\": \"userId = @request.auth.id\"
}"

echo ""
echo "✅ Done! Check Admin UI"
