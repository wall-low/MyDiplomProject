#!/bin/bash

# Import PocketBase Collections Schema v2
# Usage: ./import_schema_v2.sh <admin_email> <admin_password>

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
POCKETBASE_URL="http://localhost:8090"

# Get admin credentials
if [ -z "$1" ] || [ -z "$2" ]; then
    echo -e "${YELLOW}Usage: ./import_schema_v2.sh <admin_email> <admin_password>${NC}"
    echo ""
    read -p "Enter admin email: " ADMIN_EMAIL
    read -sp "Enter admin password: " ADMIN_PASSWORD
    echo ""
else
    ADMIN_EMAIL=$1
    ADMIN_PASSWORD=$2
fi

echo -e "${YELLOW}🔐 Authenticating as admin...${NC}"

# Authenticate as admin
AUTH_RESPONSE=$(curl -s -X POST "$POCKETBASE_URL/api/admins/auth-with-password" \
    -H "Content-Type: application/json" \
    -d "{\"identity\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}")

# Extract token
TOKEN=$(echo $AUTH_RESPONSE | grep -o '"token":"[^"]*' | sed 's/"token":"//')

if [ -z "$TOKEN" ]; then
    echo -e "${RED}❌ Authentication failed. Check your credentials.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Authenticated successfully${NC}"
echo ""

# Function to create collection
create_collection() {
    local name=$1
    local data=$2

    echo -e "${YELLOW}Creating collection: $name${NC}"

    RESPONSE=$(curl -s -X POST "$POCKETBASE_URL/api/collections" \
        -H "Content-Type: application/json" \
        -H "Authorization: $TOKEN" \
        -d "$data")

    if echo $RESPONSE | grep -q '"id"'; then
        echo -e "${GREEN}✅ Collection '$name' created successfully${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed to create collection '$name'${NC}"
        echo "Response: $RESPONSE"
        return 1
    fi
}

echo -e "${YELLOW}📦 Creating collections...${NC}"
echo ""

# 1. Users Collection (Auth)
# Note: "name", "email", "username" are built-in fields for auth collections
create_collection "users" '{
  "name": "users",
  "type": "auth",
  "schema": [
    {
      "name": "birthDate",
      "type": "date",
      "required": false
    },
    {
      "name": "city",
      "type": "text",
      "required": false,
      "options": {"max": 100}
    },
    {
      "name": "role",
      "type": "select",
      "required": true,
      "options": {"maxSelect": 1, "values": ["student", "tutor"]}
    },
    {
      "name": "bio",
      "type": "text",
      "required": false,
      "options": {"max": 500}
    },
    {
      "name": "avatar",
      "type": "file",
      "required": false,
      "options": {
        "maxSelect": 1,
        "maxSize": 5242880,
        "mimeTypes": ["image/jpeg", "image/png", "image/gif", "image/webp"],
        "thumbs": ["100x100", "300x300"]
      }
    }
  ],
  "listRule": "@request.auth.id != \"\"",
  "viewRule": "@request.auth.id != \"\"",
  "createRule": "",
  "updateRule": "@request.auth.id = id",
  "deleteRule": "@request.auth.id = id",
  "options": {
    "allowEmailAuth": true,
    "allowOAuth2Auth": false,
    "allowUsernameAuth": true,
    "minPasswordLength": 8,
    "requireEmail": true
  }
}'

echo ""

# Wait for users collection to be created
sleep 1

# 2. Messages Collection
create_collection "messages" '{
  "name": "messages",
  "type": "base",
  "schema": [
    {
      "name": "chatRoomId",
      "type": "text",
      "required": true,
      "options": {"min": 1, "max": 100}
    },
    {
      "name": "senderId",
      "type": "relation",
      "required": true,
      "options": {
        "collectionId": "users",
        "cascadeDelete": false,
        "maxSelect": 1
      }
    },
    {
      "name": "senderEmail",
      "type": "text",
      "required": true,
      "options": {"max": 200}
    },
    {
      "name": "receiverId",
      "type": "relation",
      "required": true,
      "options": {
        "collectionId": "users",
        "cascadeDelete": false,
        "maxSelect": 1
      }
    },
    {
      "name": "message",
      "type": "text",
      "required": true,
      "options": {"max": 5000}
    },
    {
      "name": "type",
      "type": "select",
      "required": true,
      "options": {"maxSelect": 1, "values": ["text", "image", "audio"]}
    },
    {
      "name": "isRead",
      "type": "bool",
      "required": false
    }
  ],
  "listRule": "senderId = @request.auth.id || receiverId = @request.auth.id",
  "viewRule": "senderId = @request.auth.id || receiverId = @request.auth.id",
  "createRule": "senderId = @request.auth.id",
  "updateRule": "receiverId = @request.auth.id",
  "deleteRule": "senderId = @request.auth.id"
}'

echo ""

# 3. Slots Collection
create_collection "slots" '{
  "name": "slots",
  "type": "base",
  "schema": [
    {
      "name": "tutorId",
      "type": "relation",
      "required": true,
      "options": {
        "collectionId": "users",
        "cascadeDelete": false,
        "maxSelect": 1
      }
    },
    {
      "name": "date",
      "type": "date",
      "required": true
    },
    {
      "name": "startTime",
      "type": "text",
      "required": true,
      "options": {"min": 5, "max": 5}
    },
    {
      "name": "endTime",
      "type": "text",
      "required": true,
      "options": {"min": 5, "max": 5}
    },
    {
      "name": "isBooked",
      "type": "bool",
      "required": false
    },
    {
      "name": "isPaid",
      "type": "bool",
      "required": false
    },
    {
      "name": "studentId",
      "type": "relation",
      "required": false,
      "options": {
        "collectionId": "users",
        "cascadeDelete": false,
        "maxSelect": 1
      }
    }
  ],
  "listRule": "@request.auth.id != \"\"",
  "viewRule": "@request.auth.id != \"\"",
  "createRule": "tutorId = @request.auth.id",
  "updateRule": "tutorId = @request.auth.id || studentId = @request.auth.id",
  "deleteRule": "tutorId = @request.auth.id"
}'

echo ""

# 4. Blocked Users Collection
create_collection "blocked_users" '{
  "name": "blocked_users",
  "type": "base",
  "schema": [
    {
      "name": "userId",
      "type": "relation",
      "required": true,
      "options": {
        "collectionId": "users",
        "cascadeDelete": true,
        "maxSelect": 1
      }
    },
    {
      "name": "blockedUserId",
      "type": "relation",
      "required": true,
      "options": {
        "collectionId": "users",
        "cascadeDelete": true,
        "maxSelect": 1
      }
    }
  ],
  "listRule": "userId = @request.auth.id",
  "viewRule": "userId = @request.auth.id",
  "createRule": "userId = @request.auth.id",
  "updateRule": null,
  "deleteRule": "userId = @request.auth.id"
}'

echo ""

# 5. Reports Collection
create_collection "reports" '{
  "name": "reports",
  "type": "base",
  "schema": [
    {
      "name": "reportedBy",
      "type": "relation",
      "required": true,
      "options": {
        "collectionId": "users",
        "cascadeDelete": false,
        "maxSelect": 1
      }
    },
    {
      "name": "messageId",
      "type": "relation",
      "required": true,
      "options": {
        "collectionId": "messages",
        "cascadeDelete": true,
        "maxSelect": 1
      }
    },
    {
      "name": "messageOwnerId",
      "type": "relation",
      "required": true,
      "options": {
        "collectionId": "users",
        "cascadeDelete": false,
        "maxSelect": 1
      }
    }
  ],
  "listRule": null,
  "viewRule": null,
  "createRule": "reportedBy = @request.auth.id",
  "updateRule": null,
  "deleteRule": null
}'

echo ""
echo -e "${GREEN}🎉 Schema import completed!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Open Admin UI: $POCKETBASE_URL/_/"
echo "2. Check that all 5 collections are created"
echo "3. Create test user to verify"
