require! {
  \randomstring
  \./utils : { send, send-all, send-sufficient }
}

to-buffer = (value, cb)->
   return cb null, Buffer.from(JSON.stringify(value) + "\n", \utf8 ) if typeof! value is \Object
   return cb null, Buffer.from(value + "\n", \utf8 ) if typeof! value is \String 
   cb "to-buffer: not supported type of #{value}"

verify-input = (state, key, cb)->
  return cb "verify-input: required state" if typeof! state isnt \Object
  return cb "verify-input: required key" if typeof! key isnt \String
  return cb "verify-input: required api" if typeof! state.tss?api isnt \Object
  cb null

write = (state, key, value, cb)->
  err <- verify-input state, key
  return cb "write: #{err}" if err?
  err, buffer <- to-buffer value
  return cb err if err?
  try 
    state.tss.api[key].write buffer, \binary
  catch err 
    return cb err
  cb null

submit-subscription = (state, key, value, cb)->
  err <- verify-input state, key 
  return cb "submit-subscription: #{err}" if err?
  submit-subscription[key] = submit-subscription[key] ? -1
  submit-subscription[key] += 1
  return cb "room #{key} is not available" if not state.tss.api[key]?
  err <- write state, key, "id: #{submit-subscription[key]}"
  return cb "submit-subscription: #{err}" if err?
  err <- write state, key, \event:new-message
  return cb "submit-subscription: #{err}" if err?
  err <- write state, key, ("data:" + JSON.stringify(value))
  return cb "submit-subscription: #{err}" if err?
  err <- write state, key, "\n"
  return cb "submit-subscription: #{err}" if err?
  cb null

submit-nothing =  (state, key, value, cb)->
  err <- verify-input state, key 
  return cb "submit-nothing: #{err}" if err?
  #state.tss.api[key].writeHead 200, []
  cb null


get-type = (url, cb)->
  return cb "get-type: cannot get type of #{url}" if typeof! url isnt \String
  [ empty, space, path, command ] = url.split \/
  return cb "get-type: expected path" if typeof! path isnt \String
  [ room, type, mode ] = path.split('-')
  rr = { space, room, type, mode, command, path }
  cb null, { space, room, type, mode, command, path }


export init-tss-room = (state, sender, url, stream, cb)->
  return cb "init-tss-room: access denied" if state.p2p.public-key isnt sender
  state.tss.api[url] = stream
  err, type <- get-type url
  return cb "init-tss-room: #{err}" if err?
  value =
    | type.command is \issue_unique_idx => {"unique_idx": state.config.index }
    | _ => ""
  err <- write state, url, value
  return cb "init-tss-room: #{err}" if err?
  cb null

export broadcast_keygen = (state, sender, req, cb)->
  err, request-type <- get-type req.url
  return cb "broadcast_keygen: #{err}" if err?
  err <- submit-subscription state, "/rooms/#{request-type.room}-keygen/subscribe" , req.data
  return cb "broadcast_keygen: #{err}" if err?
  err <- send-all state, \keygen , req
  return cb "broadcast_keygen: #{err}" if err?
  cb null

export broadcast_signing_offline = (state, sender, req, cb)->
  err, request-type <- get-type req.url
  return cb "broadcast_signing_offline: #{err}" if err?
  err <- submit-subscription state, "/rooms/#{request-type.room}-signing-offline/subscribe" , req.data
  return cb "broadcast_signing_offline: #{err}" if err?
  err <- send-sufficient state, \signing_offline , req
  return cb "broadcast_signing_offline: #{err}" if err?
  cb null

export broadcast_signing_online = (state, sender, req, cb)->
  err, request-type <- get-type req.url
  return cb "broadcast_signing_online: #{err}" if err?
  err <- submit-subscription state, "/rooms/#{request-type.room}-signing-online/subscribe" , req.data
  return cb "broadcast_signing_online: #{err}" if err?
  err <- send-sufficient state, \signing_online , req
  return cb "broadcast_signing_online: #{err}" if err?
  cb null

export keygen = (state, sender, req, cb)->
  err, request-type <- get-type req.url
  return cb "keygen: #{err}" if err?
  submit-subscription state, "/rooms/#{request-type.room}-keygen/subscribe" , req.data, cb

export signing_offline = (state, sender, req, cb)->
  err, request-type <- get-type req.url
  return cb "signing_offline: #{err}" if err?
  submit-subscription state, "/rooms/#{request-type.room}-signing-offline/subscribe" , req.data, cb
  
export signing_online = (state, sender, req, cb)->
  err, request-type <- get-type req.url
  return cb "signing_online: #{err}" if err?
  submit-subscription state, "/rooms/#{request-type.room}-signing-online/subscribe" , req.data, cb
  
# used by tss
export handle-tss-request = (state, sender, req, cb)->
  return cb "handle-tss-request: access denied, expected public key #{sender}, got #{state.p2p.public-key}" if state.p2p.public-key isnt sender
  err, request-type <- get-type req.url
  console.log req.url
  return cb "handle-tss-request: #{err}" if err?
  return cb "handle-tss-request: not supported command" if request-type.command isnt \broadcast
  
  method =
    | request-type.type is \keygen => broadcast_keygen
    | request-type.type is \signing and request-type.mode is \offline => broadcast_signing_offline
    | request-type.type is \signing and request-type.mode is \online => broadcast_signing_online
    | _ => null
  
  return cb "handle-tss-request: not supported #{req.url}" if typeof! method isnt \Function
  method state, sender, req, cb
  
  
export challenge = (state, sender, value, cb)->
  send state, sender, \answer , { value.challenge }, cb

export answer = (state, sender, value, cb)->
  state.verified = state.verified ? {}
  state.verified[sender] = yes if state.challenges[sender] is value.challenge
  return cb null, "sender #{sender} is verified" if state.challenges[sender] is value.challenge
  cb "sender #{sender} is not verified"

is-allowed = (state, public-key)->
    state.allowed-peers.find(-> it.public-key is public-key)

export verify = (state, sender, public-key, cb)->
  console.log 'connect peer', public-key
  allowed = is-allowed state, public-key
  return cb "verify: not allowed sender" if not allowed?
  state.p2p.keep(public-key)
  challenge = randomstring.generate 100
  state.challenges = state.challenges ? {}
  state.challenges[public-key] = challenge
  err <- send state, public-key, \challenge, { challenge }
  return cb "verify: #{err}" if err?
  cb null
