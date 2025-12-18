/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("t4vpsvfwgt5wlfo")

  // remove
  collection.schema.removeField("fevc6nym")

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "2cjs57cy",
    "name": "chatId",
    "type": "relation",
    "required": false,
    "presentable": false,
    "unique": false,
    "options": {
      "collectionId": "e6lov9oemn309m7",
      "cascadeDelete": true,
      "minSelect": null,
      "maxSelect": 1,
      "displayFields": null
    }
  }))

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("t4vpsvfwgt5wlfo")

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "fevc6nym",
    "name": "chatRoomId",
    "type": "text",
    "required": true,
    "presentable": false,
    "unique": false,
    "options": {
      "min": 1,
      "max": 100,
      "pattern": ""
    }
  }))

  // remove
  collection.schema.removeField("2cjs57cy")

  return dao.saveCollection(collection)
})
