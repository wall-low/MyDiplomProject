/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("kor9286vudbaiym")

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "lfwqhsgb",
    "name": "generatedFromTemplate",
    "type": "bool",
    "required": false,
    "presentable": false,
    "unique": false,
    "options": {}
  }))

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "vpqwoc73",
    "name": "templateId",
    "type": "relation",
    "required": false,
    "presentable": false,
    "unique": false,
    "options": {
      "collectionId": "onro5c58kw6409o",
      "cascadeDelete": false,
      "minSelect": null,
      "maxSelect": 1,
      "displayFields": null
    }
  }))

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("kor9286vudbaiym")

  // remove
  collection.schema.removeField("lfwqhsgb")

  // remove
  collection.schema.removeField("vpqwoc73")

  return dao.saveCollection(collection)
})
