require! {
  \http
  \fs
  \child_process : { exec }
  \./events/events.ls
  \./utils/json-parse.ls
  \./logger.ls : { log-error, log-event }
}

get-filename = (config, name)->
  "./data/#{name}-#{config.index}.json"

handler = (process-manager)-> (err, stdout, stderr)->
  cb = process-manager.on-exit
  #console.log "stdout: #{stdout}"
  #console.log "stderr: #{stderr}"
  #console.log "kill"
  process-manager.process.kill!
  return cb "#{stderr}" if "#{stderr}".length > 0
  cb null, stdout if typeof! cb is \Function

  
create-process-manager = (state)->
  process-manager =
    process: null 
    on-exit: null
    state: state
  process-manager

run-process = (state, path, cb)->
  process-manager = create-process-manager state
  process-manager.process = exec path, handler(process-manager)
  process-manager.on-exit = cb

export run-keygen = (state, name, cb)->
  filename = get-filename state.config, name
  err <- fs.unlink filename
  return cb err if err?
  path = "./bin/keygen -r #{name}-keygen -t #{state.config.threshold} -n #{state.config.numberOfParties} -i #{state.config.index} --output #{filename} --address http://127.0.0.1:#{state.config.port + state.config.index}"
  run-process state, path, cb
  



parse-signed-message = (data, cb)->
  return cb "parse-signed-message: expected data as string, got #{typeof! data}" if typeof! data isnt \String
  items = data.split "\n"
  json-parse items[items.length - 2], cb

export run-sign = (state, data-to-sign, cb)->
  { config } = state
  filename = get-filename config, config.name
  name = data-to-sign
  #console.log "./bin/signing --parties 1,2 --data-to-sign \"#{data-to-sign}\" --local-share #{filename} --address http://127.0.0.1:#{config.port + config.index}" 
  path = "./bin/signing --parties 1,2 -r #{name}-signing --data-to-sign \"#{data-to-sign}\" --local-share #{filename} --address http://127.0.0.1:#{config.port + config.index}"
  err, data <- run-process state, path
  return cb "run-sign: #{err}" if err?
  parse-signed-message data, cb
  

process-request = (state, stream, log-type, url, data, cb)->
  return cb "process-request: only request" if log-type isnt \request
  err <- events.handle-tss-request state, state.p2p.public-key, { url, data }
  return cb "process-request: #{err}" if err?
  cb null 

process-stream = (state, stream, log-type, url, chunk)->
  data = chunk.to-string!  

  err, json <- json-parse data

  log-item =
    type: log-type
    url: url
    data: if err then chunk else json
  
  log-item-previous = state.tss.events[state.tss.events.length - 1]
  
  type =
    | not log-item-previous? => \someData
    | log-item-previous.url isnt log-item.url => \someData
    | log-item-previous.type isnt log-item.type => \someData
    | typeof! log-item.data is \String and log-item.data.index-of( \id ) is 0 => \newMessage
    | typeof! log-item.data is \String and log-item.data.index-of( \event:new-message ) is 0 => \confirmMessage
    | typeof! log-item-previous.data is \String and log-item-previous.message-id? => \appendMessage
    | typeof! log-item.data is \String and log-item.data.trim! is "" => \skipMessage
    | typeof! log-item.data is \String and log-item.data.trim! is ":" => \skipMessage
    | _ => \newMessage
  
  write = (data, cb)->
    if state.config.proxy == false
      item = data ? chunk.to-string!
      err, json <- json-parse item
      return cb "write: #{err}" if err?
      err <- process-request state, stream, log-type, url, json
      cb "write: #{err}" if err?
    else 
      res = if data? then Buffer.from( data, \utf8 ) else chunk
      #console.log 'write', log-type, JSON.stringify({ str: res.to-string! })
      stream.write res, \binary if typeof! stream.write is \Function
      cb null

  someData = (cb)->
    state.tss.events.push log-item
    write null, cb

  newMessage = (cb)->
    state.tss.events.push log-item
    write null, cb 
    
  confirmMessage = (cb)->
    log-item-previous.message-id = log-item-previous.data
    log-item-previous.data = ''
    write null, cb
  
  appendMessage = (cb)->
    log-item-previous.data += log-item.data
    err, json <- json-parse log-item-previous.data.replace( \data: , '' )
    return cb null if err?
    log-item-previous.data = json
    return cb null if log-type is \response and json.sender is state.config.index
    data2  = "data:" + JSON.stringify(json) + "\n"
    write data2, cb
       
  skipMessage = (cb)->
    state.tss.events.push log-item
    write null, cb
  
  types = { someData, newMessage, confirmMessage, appendMessage, skipMessage }
  types[type] (err)->
    log-error err if err?
  fs.writeFileSync state.config.filename, JSON.stringify(state.tss.events, null, 2)


handler-p2p = (state)-> (request, response)->
  request.addListener \data , (chunk)->
    process-stream state, response,  \request , request.url, chunk
  request.addListener(\end , response~end) if request.url.index-of(\subscribe) is -1
  err <- events.init-tss-room state, state.p2p.public-key, request.url, response
  log-error "handler-p2p: #{err}" if err?

handler-proxy = (state)-> (request, response)->
  proxy_request = http.request { request.method, path: request.url, request.headers, port: 8000, host: \127.0.0.1 }
  log-event 'init', request.url
  proxy_request.addListener \response , (proxy_response)->
    proxy_response.addListener \data , (chunk)->
      process-stream state, response, \response , request.url, chunk
    proxy_response.addListener \end, response~end
    response.writeHead proxy_response.statusCode, proxy_response.headers
  request.addListener \data , (chunk)->
    process-stream state, proxy_request,  \request , request.url, chunk
  request.addListener \end , proxy_request~end
  

export start-tss-server = (state, cb)->
  return cb "start-tss-server: required state.config" if typeof! state.config isnt \Object
  return cb "start-tss-server: state.tss should be string" if typeof! state.tss isnt \String
  state.tss =
    events: []
    api: {}
  handle = if state.config.proxy is false then handler-p2p else handler-proxy
  http.createServer(handle state).listen(state.config.port + state.config.index)
  cb null