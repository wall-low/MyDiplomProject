/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const collection = new Collection({
    "id": "14dj96c1lpfs37u",
    "created": "2026-03-05 18:40:24.247Z",
    "updated": "2026-03-05 18:40:24.247Z",
    "name": "payments",
    "type": "base",
    "system": false,
    "schema": [
      {
        "system": false,
        "id": "sccry8xn",
        "name": "studentId",
        "type": "relation",
        "required": false,
        "presentable": false,
        "unique": false,
        "options": {
          "collectionId": "n8bgzub520m7akw",
          "cascadeDelete": false,
          "minSelect": null,
          "maxSelect": 1,
          "displayFields": null
        }
      },
      {
        "system": false,
        "id": "ye8qonzy",
        "name": "tutorId",
        "type": "relation",
        "required": false,
        "presentable": false,
        "unique": false,
        "options": {
          "collectionId": "n8bgzub520m7akw",
          "cascadeDelete": false,
          "minSelect": null,
          "maxSelect": 1,
          "displayFields": null
        }
      },
      {
        "system": false,
        "id": "yasp5s9w",
        "name": "slotId",
        "type": "relation",
        "required": false,
        "presentable": false,
        "unique": false,
        "options": {
          "collectionId": "kor9286vudbaiym",
          "cascadeDelete": false,
          "minSelect": null,
          "maxSelect": 1,
          "displayFields": null
        }
      },
      {
        "system": false,
        "id": "7udxckxv",
        "name": "amount",
        "type": "number",
        "required": false,
        "presentable": false,
        "unique": false,
        "options": {
          "min": 0,
          "max": null,
          "noDecimal": false
        }
      },
      {
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
      }
    ],
    "indexes": [],
    "listRule": "studentId = @request.auth.id || tutorId = @request.auth.id",
    "viewRule": "studentId = @request.auth.id || tutorId = @request.auth.id",
    "createRule": "studentId = @request.auth.id",
    "updateRule": "@request.auth.id != \"\"",
    "deleteRule": "@request.auth.id != \"\"",
    "options": {}
  });

  return Dao(db).saveCollection(collection);
}, (db) => {
  const dao = new Dao(db);
  const collection = dao.findCollectionByNameOrId("14dj96c1lpfs37u");

  return dao.deleteCollection(collection);
})
