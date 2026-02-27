/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("kor9286vudbaiym")

  // update
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "rfo1u8ut",
    "name": "bookingStatus",
    "type": "select",
    "required": true,
    "presentable": false,
    "unique": false,
    "options": {
      "maxSelect": 1,
      "values": [
        "free",
        "pending",
        "confirmed"
      ]
    }
  }))

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("kor9286vudbaiym")

  // update
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "rfo1u8ut",
    "name": "bookingStatus",
    "type": "select",
    "required": false,
    "presentable": false,
    "unique": false,
    "options": {
      "maxSelect": 1,
      "values": [
        "free",
        "pending",
        "confirmed"
      ]
    }
  }))

  return dao.saveCollection(collection)
})
