#!/bin/bash

# Import PocketBase Collections Schema
# Usage: ./import_schema.sh <admin_email> <admin_password>

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
POCKETBASE_URL="http://localhost:8090"
SCHEMA_FILE="pb_schema.json"

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is not installed. Install it with: brew install jq${NC}"
    exit 1
fi

# Check if schema file exists
if [ ! -f "$SCHEMA_FILE" ]; then
    echo -e "${RED}Error: Schema file $SCHEMA_FILE not found${NC}"
    exit 1
fi

# Get admin credentials
if [ -z "$1" ] || [ -z "$2" ]; then
    echo -e "${YELLOW}Usage: ./import_schema.sh <admin_email> <admin_password>${NC}"
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
TOKEN=$(echo $AUTH_RESPONSE | jq -r '.token')

if [ "$TOKEN" == "null" ] || [ -z "$TOKEN" ]; then
    echo -e "${RED}❌ Authentication failed. Check your credentials.${NC}"
    echo "Response: $AUTH_RESPONSE"
    exit 1
fi

echo -e "${GREEN}✅ Authenticated successfully${NC}"
echo ""

# Read collections from schema file
echo -e "${YELLOW}📦 Importing collections...${NC}"
echo ""

# Parse JSON array and import each collection
jq -c '.[]' $SCHEMA_FILE | while read collection; do
    COLLECTION_NAME=$(echo $collection | jq -r '.name')

    echo -e "${YELLOW}Creating collection: $COLLECTION_NAME${NC}"

    # Create collection
    RESPONSE=$(curl -s -X POST "$POCKETBASE_URL/api/collections" \
        -H "Content-Type: application/json" \
        -H "Authorization: $TOKEN" \
        -d "$collection")

    # Check if creation was successful
    if echo $RESPONSE | jq -e '.id' > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Collection '$COLLECTION_NAME' created successfully${NC}"
    else
        ERROR_MSG=$(echo $RESPONSE | jq -r '.message // .error // "Unknown error"')
        echo -e "${RED}❌ Failed to create collection '$COLLECTION_NAME': $ERROR_MSG${NC}"
    fi
    echo ""
done

echo -e "${GREEN}🎉 Schema import completed!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Open Admin UI: $POCKETBASE_URL/_/"
echo "2. Check that all collections are created"
echo "3. Create test users to verify everything works"
