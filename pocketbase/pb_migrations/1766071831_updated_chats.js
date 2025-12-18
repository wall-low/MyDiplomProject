/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("e6lov9oemn309m7")

  collection.indexes = [
    "CREATE UNIQUE INDEX `idx_users_pair` ON `chats` (\n  `user1Id`,\n  `user2Id`\n)"
  ]

  // remove
  collection.schema.removeField("hucepxqv")

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("e6lov9oemn309m7")

  collection.indexes = []

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "hucepxqv",
    "name": "chatRoomId",
    "type": "text",
    "required": true,
    "presentable": false,
    "unique": false,
    "options": {
      "min": 1,
      "max": 200,
      "pattern": ""
    }
  }))

  return dao.saveCollection(collection)
})
