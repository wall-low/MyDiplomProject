/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const collection = new Collection({
    "id": "kor9286vudbaiym",
    "created": "2025-12-03 14:44:19.606Z",
    "updated": "2025-12-03 14:44:19.606Z",
    "name": "slots",
    "type": "base",
    "system": false,
    "schema": [
      {
        "system": false,
        "id": "ngu57nqm",
        "name": "tutorId",
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
      },
      {
        "system": false,
        "id": "mtvzlr66",
        "name": "date",
        "type": "date",
        "required": true,
        "presentable": false,
        "unique": false,
        "options": {
          "min": "",
          "max": ""
        }
      },
      {
        "system": false,
        "id": "ccjiurvz",
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
        "id": "9e4bfaoh",
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
        "id": "5nr3ookj",
        "name": "isBooked",
        "type": "bool",
        "required": false,
        "presentable": false,
        "unique": false,
        "options": {}
      },
      {
        "system": false,
        "id": "wyeajoiy",
        "name": "isPaid",
        "type": "bool",
        "required": false,
        "presentable": false,
        "unique": false,
        "options": {}
      },
      {
        "system": false,
        "id": "vobpfhlz",
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
      }
    ],
    "indexes": [],
    "listRule": "@request.auth.id != \"\"",
    "viewRule": "@request.auth.id != \"\"",
    "createRule": "tutorId = @request.auth.id",
    "updateRule": "tutorId = @request.auth.id || studentId = @request.auth.id",
    "deleteRule": "tutorId = @request.auth.id",
    "options": {}
  });

  return Dao(db).saveCollection(collection);
}, (db) => {
  const dao = new Dao(db);
  const collection = dao.findCollectionByNameOrId("kor9286vudbaiym");

  return dao.deleteCollection(collection);
})
