// Скрипт для настройки коллекций PocketBase
// Запускать через Admin UI: Settings → Import collections

// ВАЖНО: Это JSON для импорта коллекций через Admin UI
// Скопируй весь массив ниже и вставь в: Settings → Import collections

[
  {
    "id": "users",
    "name": "users",
    "type": "auth",
    "system": false,
    "schema": [
      {
        "id": "username",
        "name": "username",
        "type": "text",
        "required": true,
        "unique": true,
        "options": {
          "min": 3,
          "max": 50,
          "pattern": "^[a-zA-Z0-9_]+$"
        }
      },
      {
        "id": "name",
        "name": "name",
        "type": "text",
        "required": true,
        "options": {
          "min": 1,
          "max": 100
        }
      },
      {
        "id": "birthDate",
        "name": "birthDate",
        "type": "date",
        "required": false
      },
      {
        "id": "city",
        "name": "city",
        "type": "text",
        "required": false,
        "options": {
          "max": 100
        }
      },
      {
        "id": "role",
        "name": "role",
        "type": "select",
        "required": false,
        "options": {
          "maxSelect": 1,
          "values": ["Ученик", "Репетитор"]
        }
      },
      {
        "id": "bio",
        "name": "bio",
        "type": "text",
        "required": false,
        "options": {
          "max": 500
        }
      },
      {
        "id": "avatar",
        "name": "avatar",
        "type": "file",
        "required": false,
        "options": {
          "maxSelect": 1,
          "maxSize": 5242880,
          "mimeTypes": ["image/jpeg", "image/png", "image/gif", "image/webp"],
          "thumbs": ["100x100"]
        }
      }
    ],
    "listRule": "",
    "viewRule": "",
    "createRule": "",
    "updateRule": "id = @request.auth.id",
    "deleteRule": "id = @request.auth.id",
    "options": {
      "allowEmailAuth": true,
      "allowOAuth2Auth": false,
      "allowUsernameAuth": false,
      "exceptEmailDomains": [],
      "manageRule": null,
      "minPasswordLength": 8,
      "onlyEmailDomains": [],
      "requireEmail": true
    }
  },
  {
    "id": "messages",
    "name": "messages",
    "type": "base",
    "system": false,
    "schema": [
      {
        "id": "chatRoomId",
        "name": "chatRoomId",
        "type": "text",
        "required": true,
        "options": {}
      },
      {
        "id": "senderId",
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
        "id": "senderEmail",
        "name": "senderEmail",
        "type": "text",
        "required": false,
        "options": {}
      },
      {
        "id": "receiverId",
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
        "id": "message",
        "name": "message",
        "type": "text",
        "required": false,
        "options": {}
      },
      {
        "id": "type",
        "name": "type",
        "type": "select",
        "required": true,
        "options": {
          "maxSelect": 1,
          "values": ["text", "image", "audio"]
        }
      },
      {
        "id": "isRead",
        "name": "isRead",
        "type": "bool",
        "required": false,
        "options": {}
      },
      {
        "id": "imageFile",
        "name": "imageFile",
        "type": "file",
        "required": false,
        "options": {
          "maxSelect": 1,
          "maxSize": 10485760,
          "mimeTypes": ["image/jpeg", "image/png", "image/gif", "image/webp"]
        }
      },
      {
        "id": "audioFile",
        "name": "audioFile",
        "type": "file",
        "required": false,
        "options": {
          "maxSelect": 1,
          "maxSize": 10485760,
          "mimeTypes": ["audio/mpeg", "audio/mp4", "audio/wav", "audio/aac"]
        }
      }
    ],
    "listRule": "senderId = @request.auth.id || receiverId = @request.auth.id",
    "viewRule": "senderId = @request.auth.id || receiverId = @request.auth.id",
    "createRule": "senderId = @request.auth.id",
    "updateRule": "senderId = @request.auth.id",
    "deleteRule": "senderId = @request.auth.id",
    "options": {}
  },
  {
    "id": "chats",
    "name": "chats",
    "type": "base",
    "system": false,
    "schema": [
      {
        "id": "chatRoomId",
        "name": "chatRoomId",
        "type": "text",
        "required": true,
        "options": {
          "min": 1,
          "max": 200
        }
      },
      {
        "id": "user1Id",
        "name": "user1Id",
        "type": "relation",
        "required": true,
        "options": {
          "collectionId": "users",
          "cascadeDelete": true,
          "maxSelect": 1
        }
      },
      {
        "id": "user2Id",
        "name": "user2Id",
        "type": "relation",
        "required": true,
        "options": {
          "collectionId": "users",
          "cascadeDelete": true,
          "maxSelect": 1
        }
      },
      {
        "id": "lastMessage",
        "name": "lastMessage",
        "type": "text",
        "required": false,
        "options": {
          "max": 500
        }
      },
      {
        "id": "lastMessageType",
        "name": "lastMessageType",
        "type": "select",
        "required": true,
        "options": {
          "maxSelect": 1,
          "values": ["text", "image", "audio"]
        }
      },
      {
        "id": "lastSenderId",
        "name": "lastSenderId",
        "type": "relation",
        "required": true,
        "options": {
          "collectionId": "users",
          "cascadeDelete": false,
          "maxSelect": 1
        }
      },
      {
        "id": "lastTimestamp",
        "name": "lastTimestamp",
        "type": "date",
        "required": true,
        "options": {}
      },
      {
        "id": "unreadCountUser1",
        "name": "unreadCountUser1",
        "type": "number",
        "required": false,
        "options": {
          "min": 0
        }
      },
      {
        "id": "unreadCountUser2",
        "name": "unreadCountUser2",
        "type": "number",
        "required": false,
        "options": {
          "min": 0
        }
      }
    ],
    "listRule": "user1Id = @request.auth.id || user2Id = @request.auth.id",
    "viewRule": "user1Id = @request.auth.id || user2Id = @request.auth.id",
    "createRule": "user1Id = @request.auth.id || user2Id = @request.auth.id",
    "updateRule": "user1Id = @request.auth.id || user2Id = @request.auth.id",
    "deleteRule": "user1Id = @request.auth.id || user2Id = @request.auth.id",
    "options": {}
  },
  {
    "id": "slots",
    "name": "slots",
    "type": "base",
    "system": false,
    "schema": [
      {
        "id": "tutorId",
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
        "id": "date",
        "name": "date",
        "type": "date",
        "required": true,
        "options": {}
      },
      {
        "id": "startTime",
        "name": "startTime",
        "type": "text",
        "required": true,
        "options": {
          "pattern": "^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$"
        }
      },
      {
        "id": "endTime",
        "name": "endTime",
        "type": "text",
        "required": true,
        "options": {
          "pattern": "^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$"
        }
      },
      {
        "id": "isBooked",
        "name": "isBooked",
        "type": "bool",
        "required": false,
        "options": {}
      },
      {
        "id": "isPaid",
        "name": "isPaid",
        "type": "bool",
        "required": false,
        "options": {}
      },
      {
        "id": "studentId",
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
    "listRule": "tutorId = @request.auth.id || studentId = @request.auth.id || isBooked = false",
    "viewRule": "tutorId = @request.auth.id || studentId = @request.auth.id || isBooked = false",
    "createRule": "tutorId = @request.auth.id",
    "updateRule": "tutorId = @request.auth.id",
    "deleteRule": "tutorId = @request.auth.id",
    "options": {}
  },
  {
    "id": "blocked_users",
    "name": "blocked_users",
    "type": "base",
    "system": false,
    "schema": [
      {
        "id": "userId",
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
        "id": "blockedUserId",
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
    "deleteRule": "userId = @request.auth.id",
    "options": {}
  },
  {
    "id": "reports",
    "name": "reports",
    "type": "base",
    "system": false,
    "schema": [
      {
        "id": "reportedBy",
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
        "id": "messageId",
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
        "id": "messageOwnerId",
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
    "deleteRule": null,
    "options": {}
  }
]
