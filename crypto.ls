# run 'npm install eth-crypto --save'
require! {
    \./external-libs.ls : { EthCrypto }
}

as-callback = (p, cb)->
    p.then (data)-> cb null, data
    p.catch cb

export get-identity = (config, cb)->
    return cb "get-identity: required config" if typeof! config isnt \Object
    return cb "get-identity: required config.mnemonic" if typeof! config.mnemonic isnt \String
    return cb "get-identity: required config.index" if typeof! config.index isnt \Number
    identity = EthCrypto.createIdentity Buffer.from(config.mnemonic + config.index, \utf8)
    cb null, identity

export encrypt = (publicKey, message, cb)->
    err, encrypted <- as-callback EthCrypto.encryptWithPublicKey(publicKey, message)
    return cb "encrypt: #{err}" if err?
    cb null, encrypted

export decrypt = (config, encrypted, cb)->
    err, identity <- get-identity config
    return cb "decrypt: #{err}" if err?
    err, decrypted <- as-callback EthCrypto.decryptWithPrivateKey(identity.private-key, encrypted)
    return cb "decrypt: #{err}" if err?
    cb null, decrypted