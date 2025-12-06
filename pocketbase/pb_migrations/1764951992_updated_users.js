/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("n8bgzub520m7akw")

  // update
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "ybcomum2",
    "name": "role",
    "type": "select",
    "required": true,
    "presentable": false,
    "unique": false,
    "options": {
      "maxSelect": 1,
      "values": [
        "Ученик",
        "Репетитор"
      ]
    }
  }))

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("n8bgzub520m7akw")

  // update
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "ybcomum2",
    "name": "role",
    "type": "select",
    "required": true,
    "presentable": false,
    "unique": false,
    "options": {
      "maxSelect": 1,
      "values": [
        "student",
        "tutor"
      ]
    }
  }))

  return dao.saveCollection(collection)
})
