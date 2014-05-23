MessageCenter = require("../")
WebSocket = require("ws")
WebSocketServer = WebSocket.Server
describe "test message center",()->
    Ma = new MessageCenter()
    Mb = new MessageCenter()
    maCon = null
    mbCon = null
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
            maCon = con
        connection = new WebSocket("ws://localhost:12345")
        connection.on "open",()->
            Mb.setConnection(connection)
            mbCon = connection
            Mb.invoke "ping",{},(err,data)->
                console.assert data is "pong"
                done()
    it "test stream implementation",(done)->
        Mb.registerApi "getTestStream",(data,callback)->
            stream = Mb.createStream()
            callback null,{stream:stream}
            stream.write 1
            stream.write {prop:"value"}
            stream.write new Buffer("I'm a buffer")
            stream.end()
        Ma.invoke "getTestStream",{},(err,result)->
            console.assert MessageCenter.isReadableStream result.stream 
            datas = []
            result.stream.on "data",(data)->
                datas.push data
            result.stream.on "end",(data)->
                console.assert datas.length is 3
                console.assert datas[0] = 1
                console.assert datas[1].prop = "value"
                console.assert Buffer.isBuffer datas[2]
                console.assert datas[2].toString() is "I'm a buffer"
                done()
    it "test multiple stream implementation",(done)->
        Mb.registerApi "getTestStream2",(data,callback)->
            s1 = Mb.createStream()
            s2 = Mb.createStream()
            callback null,{ses:[s1,s2]}
            s1.write 1
            s2.write 2
            s1.write 1
            s2.write 2
            s1.end()
            s2.end()
        Ma.invoke "getTestStream2",{},(err,result)->
            console.assert MessageCenter.isReadableStream result.ses[0]
            console.assert MessageCenter.isReadableStream result.ses[1]
            datas = []
            index = 0
            s1 = result.ses[0]
            s2 = result.ses[1]
            s1c = 0
            s2c = 0
            s1.on "data",(data)->
                console.assert data is 1,"s1 should recieve 1"
                console.assert index is 0 or index is 2
                index++
                s1c++
            s2.on "data",(data)->
                console.assert data is 2,"s2 should recieve 2"
                console.assert index is 1 or index is 3
                index++
                s2c++
            s1.on "end",()->
                console.assert s1c is 2,"s1 should recieve twice"
            s2.on "end",()->
                console.assert s2c is 2,"s2 should recieve twice"
                done()
    it "unset connection should make an end event",(done)->
        Mb.registerApi "getTestStream3",(_,callback)->
            callback null,{stream:Mb.createStream()}
        Ma.invoke "getTestStream3",{},(err,result)->
            result.stream.on "end",()->
                done()
            Ma.unsetConnection()
            Ma.setConnection(maCon)
    it "unset connection should make writable stream end",(done)->
        Mb.registerApi "getTestStream4",(_,callback)->
            stm = Mb.createStream()
            callback null,{stream:stm}
            Mb.unsetConnection()
            Mb.setConnection mbCon
            console.assert stm.isEnd
            done()
        Ma.invoke "getTestStream4",{},(err,result)->
            true
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

    it "test event with no parameters",(done)->
        Ma.on "event/ping",()->
            done()
        Mb.fireEvent "ping"
    it "test event with multipul parameters",(done)->
        Ma.on "event/welcome",(data0,data1)->
            console.assert data0 is "hello"
            console.assert data1 is "world"
            done()
        Mb.fireEvent "welcome","hello","world"
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
            