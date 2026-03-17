/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("n8bgzub520m7akw")

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "mo7gi4zz",
    "name": "lastSeen",
    "type": "date",
    "required": false,
    "presentable": false,
    "unique": false,
    "options": {
      "min": "",
      "max": ""
    }
  }))

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("n8bgzub520m7akw")

  // remove
  collection.schema.removeField("mo7gi4zz")

  return dao.saveCollection(collection)
})
