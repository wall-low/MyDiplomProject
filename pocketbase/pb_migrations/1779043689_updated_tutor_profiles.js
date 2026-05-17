/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("bmz6f14nz6mjtxi")

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "mqqguzxx",
    "name": "subjectPrices",
    "type": "json",
    "required": false,
    "presentable": false,
    "unique": false,
    "options": {
      "maxSize": 2000000
    }
  }))

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("bmz6f14nz6mjtxi")

  // remove
  collection.schema.removeField("mqqguzxx")

  return dao.saveCollection(collection)
})
