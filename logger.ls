export log-error = (err)->
  console.log "err", err

export log-event = (...args)->
  console.log "event", args