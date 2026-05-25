/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("14dj96c1lpfs37u")

  // update
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "kpwm3afc",
    "name": "status",
    "type": "select",
    "required": false,
    "presentable": false,
    "unique": false,
    "options": {
      "maxSelect": 1,
      "values": [
        "pending",
        "completed",
        "failed",
        "completed_external"
      ]
    }
  }))

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("14dj96c1lpfs37u")

  // update
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "kpwm3afc",
    "name": "status",
    "type": "select",
    "required": false,
    "presentable": false,
    "unique": false,
    "options": {
      "maxSelect": 1,
      "values": [
        "pending",
        "completed",
        "failed"
      ]
    }
  }))

  return dao.saveCollection(collection)
})
