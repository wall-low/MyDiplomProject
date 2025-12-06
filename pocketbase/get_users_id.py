#!/usr/bin/env python3
import requests
import sys

POCKETBASE_URL = "http://localhost:8090"

email = input("Admin email: ") if len(sys.argv) < 2 else sys.argv[1]
password = input("Admin password: ") if len(sys.argv) < 3 else sys.argv[2]

# Auth
auth = requests.post(f"{POCKETBASE_URL}/api/admins/auth-with-password",
    json={"identity": email, "password": password})
token = auth.json()["token"]

# Get collections
collections = requests.get(f"{POCKETBASE_URL}/api/collections",
    headers={"Authorization": token}).json()

for col in collections.get("items", []):
    if col["name"] == "users":
        print(f"Users collection ID: {col['id']}")
        # Save to file
        with open("users_id.txt", "w") as f:
            f.write(col['id'])
        print("Saved to users_id.txt")
        break
