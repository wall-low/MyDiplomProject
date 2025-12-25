/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("t4vpsvfwgt5wlfo")

  // add
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

  // update
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "rh3dzyoa",
    "name": "message",
    "type": "text",
    "required": false,
    "presentable": false,
    "unique": false,
    "options": {
      "min": null,
      "max": 5000,
      "pattern": ""
    }
  }))

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("t4vpsvfwgt5wlfo")

  // remove
  collection.schema.removeField("rbmdrowb")

  // update
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "rh3dzyoa",
    "name": "message",
    "type": "text",
    "required": true,
    "presentable": false,
    "unique": false,
    "options": {
      "min": null,
      "max": 5000,
      "pattern": ""
    }
  }))

  return dao.saveCollection(collection)
})
