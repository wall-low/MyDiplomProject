/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("t4vpsvfwgt5wlfo")

  // update
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "rbmdrowb",
    "name": "file",
    "type": "file",
    "required": false,
    "presentable": false,
    "unique": false,
    "options": {
      "mimeTypes": [
        "image/png",
        "image/jpeg",
        "image/gif",
        "image/webp",
        "video/mpeg",
        "audio/mp4",
        "audio/aac",
        "audio/x-m4a",
        "audio/wav",
        "audio/ogg"
      ],
      "thumbs": [],
      "maxSelect": 1,
      "maxSize": 10485760,
      "protected": false
    }
  }))

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("t4vpsvfwgt5wlfo")

  // update
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "rbmdrowb",
    "name": "file",
    "type": "file",
    "required": false,
    "presentable": false,
    "unique": false,
    "options": {
      "mimeTypes": [
        "image/png",
        "image/jpeg",
        "image/gif",
        "image/webp",
        "video/mpeg",
        "audio/mp4",
        "audio/aac",
        "audio/x-m4a"
      ],
      "thumbs": [],
      "maxSelect": 1,
      "maxSize": 10485760,
      "protected": false
    }
  }))

  return dao.saveCollection(collection)
})
