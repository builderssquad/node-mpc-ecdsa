json-parse = (text, cb)->
  item-type = typeof! text
  return cb null, text if item-type is \Object
  return cb "unsupported type #{item-type}" if item-type isnt \String
  try 
    cb null, JSON.parse(text)
  catch e
    cb e.message, null

module.exports = json-parse