/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("kor9286vudbaiym")

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "h5f1ybcm",
    "name": "subject",
    "type": "text",
    "required": false,
    "presentable": false,
    "unique": false,
    "options": {
      "min": null,
      "max": null,
      "pattern": ""
    }
  }))

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("kor9286vudbaiym")

  // remove
  collection.schema.removeField("h5f1ybcm")

  return dao.saveCollection(collection)
})
