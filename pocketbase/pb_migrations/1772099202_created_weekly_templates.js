/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const collection = new Collection({
    "id": "onro5c58kw6409o",
    "created": "2026-02-26 09:46:42.944Z",
    "updated": "2026-02-26 09:46:42.944Z",
    "name": "weekly_templates",
    "type": "base",
    "system": false,
    "schema": [
      {
        "system": false,
        "id": "nurimgra",
        "name": "tutorId",
        "type": "relation",
        "required": true,
        "presentable": false,
        "unique": false,
        "options": {
          "collectionId": "n8bgzub520m7akw",
          "cascadeDelete": true,
          "minSelect": null,
          "maxSelect": 1,
          "displayFields": null
        }
      },
      {
        "system": false,
        "id": "hlthczug",
        "name": "dayOfWeek",
        "type": "number",
        "required": false,
        "presentable": false,
        "unique": false,
        "options": {
          "min": null,
          "max": null,
          "noDecimal": false
        }
      },
      {
        "system": false,
        "id": "v4ffkhme",
        "name": "startTime",
        "type": "text",
        "required": true,
        "presentable": false,
        "unique": false,
        "options": {
          "min": 5,
          "max": 5,
          "pattern": ""
        }
      },
      {
        "system": false,
        "id": "fjzqelra",
        "name": "endTime",
        "type": "text",
        "required": true,
        "presentable": false,
        "unique": false,
        "options": {
          "min": 5,
          "max": 5,
          "pattern": ""
        }
      },
      {
        "system": false,
        "id": "mg7kpuit",
        "name": "isActive",
        "type": "bool",
        "required": false,
        "presentable": false,
        "unique": false,
        "options": {}
      }
    ],
    "indexes": [],
    "listRule": "tutorId = @request.auth.id",
    "viewRule": "tutorId = @request.auth.id",
    "createRule": "tutorId = @request.auth.id",
    "updateRule": "tutorId = @request.auth.id",
    "deleteRule": "tutorId = @request.auth.id",
    "options": {}
  });

  return Dao(db).saveCollection(collection);
}, (db) => {
  const dao = new Dao(db);
  const collection = dao.findCollectionByNameOrId("onro5c58kw6409o");

  return dao.deleteCollection(collection);
})
