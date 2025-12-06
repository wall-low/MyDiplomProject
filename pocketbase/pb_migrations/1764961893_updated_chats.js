/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("e6lov9oemn309m7")

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "9e2kdgug",
    "name": "lastMessageType",
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

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "fhm65pun",
    "name": "lastSenderId",
    "type": "relation",
    "required": true,
    "presentable": false,
    "unique": false,
    "options": {
      "collectionId": "n8bgzub520m7akw",
      "cascadeDelete": false,
      "minSelect": null,
      "maxSelect": 1,
      "displayFields": null
    }
  }))

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "xgnhofif",
    "name": "lastTimestamp",
    "type": "date",
    "required": true,
    "presentable": false,
    "unique": false,
    "options": {
      "min": "",
      "max": ""
    }
  }))

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "idvbi3ld",
    "name": "unreadCountUser1",
    "type": "number",
    "required": false,
    "presentable": false,
    "unique": false,
    "options": {
      "min": 0,
      "max": null,
      "noDecimal": false
    }
  }))

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "5jiittqz",
    "name": "unreadCountUser2",
    "type": "number",
    "required": false,
    "presentable": false,
    "unique": false,
    "options": {
      "min": 0,
      "max": null,
      "noDecimal": false
    }
  }))

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("e6lov9oemn309m7")

  // remove
  collection.schema.removeField("9e2kdgug")

  // remove
  collection.schema.removeField("fhm65pun")

  // remove
  collection.schema.removeField("xgnhofif")

  // remove
  collection.schema.removeField("idvbi3ld")

  // remove
  collection.schema.removeField("5jiittqz")

  return dao.saveCollection(collection)
})
