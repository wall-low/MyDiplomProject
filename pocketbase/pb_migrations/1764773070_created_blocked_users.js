/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const collection = new Collection({
    "id": "s5jjvt1d3ei184y",
    "created": "2025-12-03 14:44:30.480Z",
    "updated": "2025-12-03 14:44:30.480Z",
    "name": "blocked_users",
    "type": "base",
    "system": false,
    "schema": [
      {
        "system": false,
        "id": "jov38akt",
        "name": "userId",
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
        "id": "ruyjm4v6",
        "name": "blockedUserId",
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
      }
    ],
    "indexes": [],
    "listRule": "userId = @request.auth.id",
    "viewRule": "userId = @request.auth.id",
    "createRule": "userId = @request.auth.id",
    "updateRule": null,
    "deleteRule": "userId = @request.auth.id",
    "options": {}
  });

  return Dao(db).saveCollection(collection);
}, (db) => {
  const dao = new Dao(db);
  const collection = dao.findCollectionByNameOrId("s5jjvt1d3ei184y");

  return dao.deleteCollection(collection);
})
