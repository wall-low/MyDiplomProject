/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const collection = new Collection({
    "id": "bmz6f14nz6mjtxi",
    "created": "2026-02-25 14:59:38.134Z",
    "updated": "2026-02-25 14:59:38.134Z",
    "name": "tutor_profiles",
    "type": "base",
    "system": false,
    "schema": [
      {
        "system": false,
        "id": "34gf7yel",
        "name": "userId",
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
      }
    ],
    "indexes": [],
    "listRule": null,
    "viewRule": null,
    "createRule": null,
    "updateRule": null,
    "deleteRule": null,
    "options": {}
  });

  return Dao(db).saveCollection(collection);
}, (db) => {
  const dao = new Dao(db);
  const collection = dao.findCollectionByNameOrId("bmz6f14nz6mjtxi");

  return dao.deleteCollection(collection);
})
