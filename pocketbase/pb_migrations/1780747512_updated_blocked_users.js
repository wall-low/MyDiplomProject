/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("s5jjvt1d3ei184y")

  collection.listRule = "userId = @request.auth.id || blockedUserId = @request.auth.id"
  collection.viewRule = "userId = @request.auth.id || blockedUserId = @request.auth.id"

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("s5jjvt1d3ei184y")

  collection.listRule = "userId = @request.auth.id"
  collection.viewRule = "userId = @request.auth.id"

  return dao.saveCollection(collection)
})
