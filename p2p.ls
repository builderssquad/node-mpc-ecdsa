require! {
  \./external-libs.ls : { Server }
  \./crypto.ls : { get-identity }
  \./events/events.ls
  \./crypto.ls : { decrypt }
  \./utils/json-parse.ls
  \./logger.ls : { log-error, log-event }
}


create-peers = (config, [index, ...rest], cb)->
  return cb "required config" if typeof! config isnt \Object
  return cb null, [] if not index?
  err, other <- create-peers config, rest 
  return cb "create-peers: #{err}" if err?
  err, identity <- get-identity { ...config, index }
  return cb "create-peers: #{err}" if err?
  host = \127.0.0.1
  peer = { identity.public-key , index, address: "tcp://#{host}:#{config.peerPort + index}" }
  all = [peer, ...other]
  cb null, all

get-peers = (config, cb)->
  return cb "get-peers: config is required" if typeof! config isnt \Object
  other-indexes =
      [1 to config.numberOfParties].filter(-> it isnt config.index)
  err, peers <- create-peers config, other-indexes
  return cb "get-peers: #{err}" if err?
  cb null, peers

connect-peers = (server, [peer, ...peers], cb)->
  return cb null if not peer?
  log-event 'connect peer', peer.address
  server.connect peer.address
  err <- connect-peers server, peers
  return cb err if err?
  cb null

is-allowed = (state, public-key)->
    return no if typeof! state.allowed-peers isnt \Array
    state.allowed-peers.find(-> it.public-key is public-key)

on-connect = (state)-> (public-key)->
  err <- events.verify state, \me, public-key
  log-error "on-connect: #{err}" if err?

process-message = (state, sender, packet, cb)->
  return cb "process-message: not allowed sender #{sender}" if not is-allowed state, sender
  func = events[packet.key]
  return cb "process-message: required key" if typeof! packet.key isnt \String
  return cb "process-message: required value object, got #{typeof! packet.value}" if typeof! packet.value isnt \Object
  return cb "process-message: not allowed function #{packet.key}" if typeof! func isnt \Function
  err, decrypted <- decrypt state.config, packet.value
  return cb "process-message: #{err}" if err?
  err, json <- json-parse decrypted
  return cb "process-message: #{err}" if err?
  err <- func state, sender, json
  return cb err if err?
  cb null

on-message = (state)-> (sender, packet)->
  err <- process-message state, sender, packet
  log-error "on-message: #{err}" if err?

export start-peer-server = (state, cb)->
  err, identity <- get-identity state.config
  return cb "start-peer-server: #{err}" if err?
  return cb "start-peer-server: state.p2p should be a string" if typeof! state.p2p isnt \String
  state.p2p = new Server(identity.public-key, { port: state.config.peerPort + state.config.index })
  state.p2p.public-key = identity.public-key
  err, peers <- get-peers state.config
  return cb "start-peer-server: #{err}" if err?
  return cb "start-peer-server: state.allowed-peers should be zero array" if typeof! state.allowed-peers isnt \Array or state.allowed-peers.length > 0 
  peers.for-each (-> state.allowed-peers.push it ) 
  err <- connect-peers state.p2p, peers
  state.p2p.on \connect, on-connect(state)
  state.p2p.on \message, on-message(state)
  cb null