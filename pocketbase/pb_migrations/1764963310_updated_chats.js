/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("e6lov9oemn309m7")

  collection.listRule = "user1Id = @request.auth.id || user2Id = @request.auth.id"
  collection.viewRule = "user1Id = @request.auth.id || user2Id = @request.auth.id"
  collection.createRule = "user1Id = @request.auth.id || user2Id = @request.auth.id"
  collection.updateRule = "user1Id = @request.auth.id || user2Id = @request.auth.id"
  collection.deleteRule = "user1Id = @request.auth.id || user2Id = @request.auth.id"

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("e6lov9oemn309m7")

  collection.listRule = null
  collection.viewRule = null
  collection.createRule = null
  collection.updateRule = null
  collection.deleteRule = null

  return dao.saveCollection(collection)
})
