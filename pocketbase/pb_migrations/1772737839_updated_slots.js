/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("kor9286vudbaiym")

  collection.viewRule = "@request.auth.id = tutorId || @request.auth.id = studentId"

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("kor9286vudbaiym")

  collection.viewRule = "@request.auth.id != \"\""

  return dao.saveCollection(collection)
})
