/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("t4vpsvfwgt5wlfo")

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "eqkapbej",
    "name": "file",
    "type": "file",
    "required": false,
    "presentable": false,
    "unique": false,
    "options": {
      "mimeTypes": [
        "image/png",
        "image/jpeg",
        "image/webp",
        "image/gif",
        "video/mpeg",
        "audio/mp4",
        "audio/aac",
        "audio/x-m4a"
      ],
      "thumbs": [],
      "maxSelect": 1,
      "maxSize": 5242880,
      "protected": false
    }
  }))

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("t4vpsvfwgt5wlfo")

  // remove
  collection.schema.removeField("eqkapbej")

  return dao.saveCollection(collection)
})
