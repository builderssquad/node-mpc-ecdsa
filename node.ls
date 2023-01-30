require! {
  \./p2p.ls : { start-peer-server }
  \./tss.ls : { start-tss-server, run-sign, run-keygen }
  \./config.ls
  \./external-libs.ls : { commander }
}

commander.program
  .option('-i, --index <index>')

commander.program.parse!

options = commander.program.opts!

return commander.program.help! if not options.index?

config.index = +options.index

state =
  config: config  #initial config
  p2p : "<should be initialized by p2p component>" # { public-key }
  tss : "<should be initialized by tss component>" # { events }
  allowed-peers: []


cb = console.log

err <- start-peer-server state
return cb err if err?

err <- start-tss-server state
return cb err if err?


run-in-parallel = (state, [message, ...messages], cb)->
    return cb null, \all if not message?
    run-sign state, message, console~log
    run-in-parallel state, messages, cb

<- set-timeout _, 1000

items = [1 to 2].map(-> "test" + it)

run-in-parallel state, items, cb

    