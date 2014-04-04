MessageCenter = require("../")
WebSocket = require("ws")
WebSocketServer = WebSocket.Server
describe "test message center",()->
    Ma = new MessageCenter()
    Mb = new MessageCenter()
    Ma.registerApi "ping",(data,callback)->
        callback null,"pong"
    Ma.registerApi "delay",(time,callback)->
        done = ()->
            callback()
        setTimeout done,parseInt(time)
    it "test invoke",(done)->
        server = new WebSocketServer({host:"localhost",port:12345})
        server.on "connection",(con)->
            Ma.setConnection(con)
        connection = new WebSocket("ws://localhost:12345")
        connection.on "open",()->
            Mb.setConnection(connection)
            Mb.invoke "ping",{},(err,data)->
                console.assert data is "pong"
                done()
    it "test default timeout",(done)->
        Mb.timeout = 300
        Mb.invoke "delay",500,(err,result)->
            console.assert err.message is "timeout"
            done()
    it "test invoke time out",(done)->
        req = Mb.invoke "delay",500,(err,result)->
            console.assert err.message is "timeout"
            done()
        req.timeout 300
    it "test invoke not time out",(done)->
        req = Mb.invoke "delay",500,(err,result)->
            console.assert !err
            done()
        req.timeout 1000
    it "test invoke cleared with custom error",(done)->
        req = Mb.invoke "delay",500,(err,result)-> 
            console.assert err.message is "customError"
            done()
        req.timeout 1000
        clear = ()->
            req.clear(new Error "customError")
        setTimeout clear,100

    it "test event",(done)->
        Ma.on "event/hello",(data)->
            console.assert data is "hello"
            done()
        Mb.fireEvent "hello","hello"
    it "test clear all",(done)->
        first = false
        Mb.invoke "delay",1000,(err,result)->
            console.assert first is false
            first = true
            console.assert err.message is "abort"
        Mb.invoke "delay",1000,(err,result)->
            console.assert first is true
            console.assert err.message is "abort"
            done()
        Mb.clearAll()
    it "test clear all shouldn't fire already excuted invokes",(done)->
        
        Mb.invoke "ping",{},(err,result)->
            console.assert not err
            console.assert result is "pong"
            Mb.clearAll()
            done()
    it "test unset connect",(done)->
        Mb.invoke "delay",1000,(err,result)->
            console.assert err.message is "abort"
            done()
        Ma.unsetConnection()
        Mb.unsetConnection()
    it "non connected messagecenter",(done)->
        Ma.unsetConnection()
        Ma.invoke "test",{},(err,result)->
            console.assert err.message is "connection not set"
            done()