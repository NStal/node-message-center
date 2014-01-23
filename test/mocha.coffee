MessageCenter = require("../lib/messageCenter.coffee")
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
    it "test invoke time out",(done)->
        req = Mb.invoke "delay",1000,(err,result)->
            console.assert err.message is "timeout"
            done()
        req.timeout 500
    it "test event",(done)->
        Ma.on "event/hello",(data)->
            console.assert data is "hello"
            done()
        Mb.fireEvent "hello","hello"