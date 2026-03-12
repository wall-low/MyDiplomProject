/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("bmz6f14nz6mjtxi")

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "3evwetbs",
    "name": "payoutCardLast4",
    "type": "text",
    "required": false,
    "presentable": false,
    "unique": false,
    "options": {
      "min": null,
      "max": 4,
      "pattern": ""
    }
  }))

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("bmz6f14nz6mjtxi")

  // remove
  collection.schema.removeField("3evwetbs")

  return dao.saveCollection(collection)
})
