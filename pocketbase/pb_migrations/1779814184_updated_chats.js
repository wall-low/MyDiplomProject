/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("e6lov9oemn309m7")

  // update
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "9e2kdgug",
    "name": "lastMessageType",
    "type": "select",
    "required": true,
    "presentable": false,
    "unique": false,
    "options": {
      "maxSelect": 1,
      "values": [
        "text",
        "image",
        "audio",
        "file"
      ]
    }
  }))

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("e6lov9oemn309m7")

  // update
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "9e2kdgug",
    "name": "lastMessageType",
    "type": "select",
    "required": true,
    "presentable": false,
    "unique": false,
    "options": {
      "maxSelect": 1,
      "values": [
        "text",
        "image",
        "audio"
      ]
    }
  }))

  return dao.saveCollection(collection)
})
