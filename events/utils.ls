require! {
  \../external-libs.ls : { randomstring }
  \../crypto.ls : { encrypt, decrypt }
}

get-string-value = (value, cb)->
  return cb null, JSON.stringify(value) if typeof! value is \Object
  return cb null, value if typeof! value is \String
  return cb null, value.to-string! if typeof! value is \Number
  cb "wrong type of value (#{typeof! value})"

export send = (state, public-key, key, value, cb)->
  return cb "send: required public key" if typeof! public-key isnt \String
  return cb "send: required key" if typeof! key isnt \String
  return cb "send: required value" if not value?
  allowed = state.allowed-peers.find(-> it.public-key is public-key)
  return cb "send: not allowed peer #{public-key}" if not allowed?
  err, value <- get-string-value value 
  return cb err if err?
  err, value <- encrypt public-key, value
  state.p2p.send( public-key, { key , value })
  cb null, "send to #{public-key}"

send-one-by-one = (state, [peer, ...peers], key, value, cb)->
    return cb "send-one-by-one: required state" if typeof! state isnt \Object
    return cb null if not peer?
    err <- send state, peer.public-key, key, value
    console.log err if err?
    <- set-immediate
    send-one-by-one state, peers, key, value, cb

export send-all = (state, key, value, cb)->
    return cb "state.p2p.public-key is required" if typeof! state.p2p?public-key isnt \String
    peers =
        state.allowed-peers.filter(-> it.public-key isnt state.p2p.public-key)
    send-one-by-one state, peers, key,value, cb

export send-sufficient = (state, key, value, cb)->
    return cb "state.p2p.public-key is required" if typeof! state.p2p?public-key isnt \String
    count = state.config.number-of-parties - state.config.threshold - 1
    peers =
        state.allowed-peers.filter(-> it.public-key isnt state.p2p.public-key).slice(0, count)
    send-one-by-one state, peers, key,value, cb
    