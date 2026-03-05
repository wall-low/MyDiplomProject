/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("kor9286vudbaiym")

  collection.updateRule = "@request.auth.id = tutorId || @request.auth.id = studentId"

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("kor9286vudbaiym")

  collection.updateRule = "@request.auth.id = tutorId\n  ||\n  (@request.auth.id != \"\" && @request.data.isBooked = true && isBooked = false && @request.data.studentId = @request.auth.id)\n  ||\n  (@request.auth.id != \"\" && @request.data.isBooked = false && isBooked = true && studentId = @request.auth.id)"

  return dao.saveCollection(collection)
})
