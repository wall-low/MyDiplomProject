/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("kor9286vudbaiym")

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "kwvprkwx",
    "name": "isRecurring",
    "type": "bool",
    "required": false,
    "presentable": false,
    "unique": false,
    "options": {}
  }))

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "wagdtr46",
    "name": "recurringGroupId",
    "type": "text",
    "required": false,
    "presentable": false,
    "unique": false,
    "options": {
      "min": null,
      "max": 100,
      "pattern": ""
    }
  }))

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("kor9286vudbaiym")

  // remove
  collection.schema.removeField("kwvprkwx")

  // remove
  collection.schema.removeField("wagdtr46")

  return dao.saveCollection(collection)
})
