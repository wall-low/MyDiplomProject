#!/usr/bin/env python3
"""
PocketBase Collections Importer
Simple and reliable collection import using Python
"""

import requests
import json
import sys
import os
from pathlib import Path

# Configuration
POCKETBASE_URL = "http://localhost:8090"
COLLECTIONS_TO_CREATE = ["users", "messages", "slots", "blocked_users", "reports"]

# Colors for terminal output
class Colors:
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    END = '\033[0m'

def print_success(msg):
    print(f"{Colors.GREEN}✅ {msg}{Colors.END}")

def print_warning(msg):
    print(f"{Colors.YELLOW}⚠️  {msg}{Colors.END}")

def print_error(msg):
    print(f"{Colors.RED}❌ {msg}{Colors.END}")

def print_info(msg):
    print(f"{Colors.YELLOW}{msg}{Colors.END}")

def authenticate(email, password):
    """Authenticate as admin and return token"""
    print_info("🔐 Authenticating as admin...")

    response = requests.post(
        f"{POCKETBASE_URL}/api/admins/auth-with-password",
        json={"identity": email, "password": password}
    )

    if response.status_code != 200:
        print_error("Authentication failed")
        print(response.text)
        sys.exit(1)

    token = response.json().get("token")
    print_success("Authenticated successfully")
    return token

def get_collections(token):
    """Get list of all collections"""
    response = requests.get(
        f"{POCKETBASE_URL}/api/collections",
        headers={"Authorization": token}
    )

    if response.status_code == 200:
        return response.json().get("items", [])
    return []

def delete_collection(token, collection_id, name):
    """Delete a collection by ID"""
    print_info(f"Deleting collection: {name}")

    response = requests.delete(
        f"{POCKETBASE_URL}/api/collections/{collection_id}",
        headers={"Authorization": token}
    )

    if response.status_code in [200, 204]:
        print_success(f"Deleted: {name}")
        return True
    else:
        print_warning(f"Could not delete {name}: {response.text}")
        return False

def create_collection(token, data, name):
    """Create a collection"""
    print_info(f"Creating collection: {name}")

    response = requests.post(
        f"{POCKETBASE_URL}/api/collections",
        headers={
            "Authorization": token,
            "Content-Type": "application/json"
        },
        json=data
    )

    if response.status_code in [200, 201]:
        collection = response.json()
        collection_id = collection.get("id")
        print_success(f"Created: {name} (ID: {collection_id})")
        return collection_id
    else:
        print_error(f"Failed to create {name}")
        print(response.text)
        return None

def update_relations(schema, users_id, messages_id=None):
    """Update relation fields with actual collection IDs"""
    for field in schema:
        if field.get("type") == "relation":
            collection_ref = field["options"].get("collectionId")

            # Replace placeholder with actual ID
            if collection_ref == "users":
                field["options"]["collectionId"] = users_id
            elif collection_ref == "messages" and messages_id:
                field["options"]["collectionId"] = messages_id

    return schema

def main():
    # Get admin credentials
    if len(sys.argv) >= 3:
        admin_email = sys.argv[1]
        admin_password = sys.argv[2]
    else:
        admin_email = input("Enter admin email: ")
        admin_password = input("Enter admin password: ")

    print()

    # Authenticate
    token = authenticate(admin_email, admin_password)
    print()

    # Clean existing collections
    print_info("🗑️  Cleaning existing collections...")
    existing = get_collections(token)

    for collection in existing:
        if collection["name"] in COLLECTIONS_TO_CREATE:
            delete_collection(token, collection["id"], collection["name"])

    print_success("Cleanup complete")
    print()

    # Create collections
    print_info("📦 Creating collections...")
    print()

    collection_ids = {}

    # 1. Create users collection
    users_schema = {
        "name": "users",
        "type": "auth",
        "schema": [
            {"name": "birthDate", "type": "date", "required": False},
            {"name": "city", "type": "text", "required": False, "options": {"max": 100}},
            {"name": "role", "type": "select", "required": True, "options": {"maxSelect": 1, "values": ["student", "tutor"]}},
            {"name": "bio", "type": "text", "required": False, "options": {"max": 500}},
            {
                "name": "avatar",
                "type": "file",
                "required": False,
                "options": {
                    "maxSelect": 1,
                    "maxSize": 5242880,
                    "mimeTypes": ["image/jpeg", "image/png", "image/gif", "image/webp"],
                    "thumbs": ["100x100", "300x300"]
                }
            }
        ],
        "listRule": '@request.auth.id != ""',
        "viewRule": '@request.auth.id != ""',
        "createRule": "",
        "updateRule": "@request.auth.id = id",
        "deleteRule": "@request.auth.id = id",
        "options": {
            "allowEmailAuth": True,
            "allowOAuth2Auth": False,
            "allowUsernameAuth": True,
            "minPasswordLength": 8,
            "requireEmail": True
        }
    }

    users_id = create_collection(token, users_schema, "users")
    if not users_id:
        sys.exit(1)
    collection_ids["users"] = users_id
    print()

    # 2. Create messages collection
    messages_schema = {
        "name": "messages",
        "type": "base",
        "schema": [
            {"name": "chatRoomId", "type": "text", "required": True, "options": {"min": 1, "max": 100}},
            {"name": "senderId", "type": "relation", "required": True, "options": {"collectionId": users_id, "cascadeDelete": False, "maxSelect": 1}},
            {"name": "senderEmail", "type": "text", "required": True, "options": {"max": 200}},
            {"name": "receiverId", "type": "relation", "required": True, "options": {"collectionId": users_id, "cascadeDelete": False, "maxSelect": 1}},
            {"name": "message", "type": "text", "required": True, "options": {"max": 5000}},
            {"name": "type", "type": "select", "required": True, "options": {"maxSelect": 1, "values": ["text", "image", "audio"]}},
            {"name": "isRead", "type": "bool", "required": False}
        ],
        "listRule": "senderId = @request.auth.id || receiverId = @request.auth.id",
        "viewRule": "senderId = @request.auth.id || receiverId = @request.auth.id",
        "createRule": "senderId = @request.auth.id",
        "updateRule": "receiverId = @request.auth.id",
        "deleteRule": "senderId = @request.auth.id"
    }

    messages_id = create_collection(token, messages_schema, "messages")
    if not messages_id:
        sys.exit(1)
    collection_ids["messages"] = messages_id
    print()

    # 3. Create slots collection
    slots_schema = {
        "name": "slots",
        "type": "base",
        "schema": [
            {"name": "tutorId", "type": "relation", "required": True, "options": {"collectionId": users_id, "cascadeDelete": False, "maxSelect": 1}},
            {"name": "date", "type": "date", "required": True},
            {"name": "startTime", "type": "text", "required": True, "options": {"min": 5, "max": 5}},
            {"name": "endTime", "type": "text", "required": True, "options": {"min": 5, "max": 5}},
            {"name": "isBooked", "type": "bool", "required": False},
            {"name": "isPaid", "type": "bool", "required": False},
            {"name": "studentId", "type": "relation", "required": False, "options": {"collectionId": users_id, "cascadeDelete": False, "maxSelect": 1}}
        ],
        "listRule": '@request.auth.id != ""',
        "viewRule": '@request.auth.id != ""',
        "createRule": "tutorId = @request.auth.id",
        "updateRule": "tutorId = @request.auth.id || studentId = @request.auth.id",
        "deleteRule": "tutorId = @request.auth.id"
    }

    create_collection(token, slots_schema, "slots")
    print()

    # 4. Create blocked_users collection
    blocked_schema = {
        "name": "blocked_users",
        "type": "base",
        "schema": [
            {"name": "userId", "type": "relation", "required": True, "options": {"collectionId": users_id, "cascadeDelete": True, "maxSelect": 1}},
            {"name": "blockedUserId", "type": "relation", "required": True, "options": {"collectionId": users_id, "cascadeDelete": True, "maxSelect": 1}}
        ],
        "listRule": "userId = @request.auth.id",
        "viewRule": "userId = @request.auth.id",
        "createRule": "userId = @request.auth.id",
        "updateRule": None,
        "deleteRule": "userId = @request.auth.id"
    }

    create_collection(token, blocked_schema, "blocked_users")
    print()

    # 5. Create reports collection
    reports_schema = {
        "name": "reports",
        "type": "base",
        "schema": [
            {"name": "reportedBy", "type": "relation", "required": True, "options": {"collectionId": users_id, "cascadeDelete": False, "maxSelect": 1}},
            {"name": "messageId", "type": "relation", "required": True, "options": {"collectionId": messages_id, "cascadeDelete": True, "maxSelect": 1}},
            {"name": "messageOwnerId", "type": "relation", "required": True, "options": {"collectionId": users_id, "cascadeDelete": False, "maxSelect": 1}}
        ],
        "listRule": None,
        "viewRule": None,
        "createRule": "reportedBy = @request.auth.id",
        "updateRule": None,
        "deleteRule": None
    }

    create_collection(token, reports_schema, "reports")
    print()

    # Summary
    print_success("🎉 All collections created successfully!")
    print()
    print_info("Summary:")
    print("  ✅ users (Auth collection)")
    print("  ✅ messages")
    print("  ✅ slots")
    print("  ✅ blocked_users")
    print("  ✅ reports")
    print()
    print_info("Next steps:")
    print(f"  1. Open Admin UI: {POCKETBASE_URL}/_/")
    print("  2. Create test user to verify")
    print("  3. Add Flutter pocketbase package")

if __name__ == "__main__":
    main()
