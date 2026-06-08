/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("ydhmmxl3vp20bxj")

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "3fiejzww",
    "name": "reason",
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

  // update
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "uic2s5lz",
    "name": "messageId",
    "type": "relation",
    "required": false,
    "presentable": false,
    "unique": false,
    "options": {
      "collectionId": "t4vpsvfwgt5wlfo",
      "cascadeDelete": true,
      "minSelect": null,
      "maxSelect": 1,
      "displayFields": null
    }
  }))

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("ydhmmxl3vp20bxj")

  // remove
  collection.schema.removeField("3fiejzww")

  // update
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "uic2s5lz",
    "name": "messageId",
    "type": "relation",
    "required": true,
    "presentable": false,
    "unique": false,
    "options": {
      "collectionId": "t4vpsvfwgt5wlfo",
      "cascadeDelete": true,
      "minSelect": null,
      "maxSelect": 1,
      "displayFields": null
    }
  }))

  return dao.saveCollection(collection)
})
