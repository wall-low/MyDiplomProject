/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("t4vpsvfwgt5wlfo")

  // update
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "acb33ow5",
    "name": "type",
    "type": "select",
    "required": true,
    "presentable": false,
    "unique": false,
    "options": {
      "maxSelect": 1,
      "values": [
        "text",
        "image",
        "audio",
        "file"
      ]
    }
  }))

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("t4vpsvfwgt5wlfo")

  // update
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "acb33ow5",
    "name": "type",
    "type": "select",
    "required": true,
    "presentable": false,
    "unique": false,
    "options": {
      "maxSelect": 1,
      "values": [
        "text",
        "image",
        "audio"
      ]
    }
  }))

  return dao.saveCollection(collection)
})
