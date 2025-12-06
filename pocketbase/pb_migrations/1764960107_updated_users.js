/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("n8bgzub520m7akw")

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "fjlq91qb",
    "name": "name",
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
  const collection = dao.findCollectionByNameOrId("n8bgzub520m7akw")

  // remove
  collection.schema.removeField("fjlq91qb")

  return dao.saveCollection(collection)
})
