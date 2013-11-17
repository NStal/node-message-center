# MessageCenter Accept a JSON format message
# MessageCenter is designed for 1 to 1 messaging
# 
# FORMATS
# Invoke: {id:'id',type:'invoke',name:'actionName',data:data}
# Event:   {type:'event',name:'eventName',data:data}
# for Invoke we should response something with (err,data) callback
# for Event we only dispatch them to who ever cares but dont return anything
# for Invoke response
# InvokeResponse: {id:'original id',type:'response',data:data,error:err}

class MessageCenter extends (require "events").EventEmitter
    stringify:(obj)->
        return JSON.stringify(@normalize(obj))
    normalize:(obj)->
        if typeof obj isnt "object"
            return obj
        if obj instanceof Array
            return (@normalize item for item in obj)
        if obj is null
            return null
        else if obj instanceof Buffer
            return {__mc_type:"buffer",value:obj.toString("base64")}
        else if obj instanceof Date
            return {__mc_type:"date",value:obj.getTime()}
        else
            _ = {}
            for prop of obj
                _[prop] = @normalize(obj[prop])
            return _
    denormalize:(obj)->
        if typeof obj isnt "object"
            return obj
        if obj is null
            return null
        if obj instanceof Array
            return (@denormalize item for item in obj)
        else if obj.__mc_type is "buffer"
            return new Buffer(obj.value,"base64")
        else if obj.__mc_type is "date"
            return new Date(obj.value)
        else
            _ = {}
            for prop of obj
                _[prop] = @denormalize(obj[prop])
            return _
    parse:(str)->
        json = JSON.parse(str)
        _ = @denormalize json
        return _
    constructor:()->
        @idPool = 1000
        @invokeWaiters = []
        @apis = []
        super()
    getInvokeId:()->
        return @idPool++;
    registerApi:(name,handler,overwrite)->
        name = name.trim()
        if not handler
            throw "need handler to work"
        for api,index in @apis
            if api.name is name
                if not overwrite
                    throw new Eror "duplicated api name #{name}"
                else
                    # overwrite
                    @apis[index] = null
        @apis = @apis.filter (api)->api
        @apis.push {name:name,handler:handler}
    setConnection:(connection)->
        @connection = connection
        @connection.on "message",(message)=>
            if @connection isnt connection
                # connection changed.. i can't handle you
                return
            @handleMessage(message)
    unsetConnection:()->
        @connection = null
    response:(id,err,data)->
        if not @connection
            return
        @connection.send @stringify({id:id,type:"response",data:data,error:err})
    invoke:(name,data,callback)->
        callback = callback or ()->true
        if not @connection
            callback new Error "connect fail"
            return
        req = {
        type:"invoke"
        ,id:@getInvokeId()
        ,name:name
        ,data:data
        }
        @connection.send @stringify(req)
        # date is used for check timeout or clear old broken waiters
        @invokeWaiters.push {request:req,id:req.id,callback:callback,date:new Date}
    fireEvent:(name,data)->
        if not @connection
            # remote is down there are nothing we can do here
            return false
        @connection.send @stringify({type:"event",name:name,data:data})
    handleMessage:(message)->
        try
            info = @parse(message)
        catch e
            console.error e
            throw  "invalid message #{message}"
        if not info.type or info.type not in ["invoke","event","response"]
            throw  "invalid message #{message} invalid info type"
            return
        if info.type is "response"
            @handleResponse(info)
        else if info.type is "invoke"
            @handleInvoke(info)
        else
            @handleEvent(info)
    handleEvent:(info)->
        if not info.name
            throw "invalid message #{JSON.stringify(message)}"
        @emit "event/"+info.name,info.data
        
    handleResponse:(info)->
        if not info.id
            throw "invalid message #{JSON.stringify(info)}"
        target = null
        for waiter in @invokeWaiters
            if waiter.id is info.id
                target = waiter
                break
        if not target
            throw "unmatched response #{JSON.stringify(message)}"
        target.callback(info.error,info.data)
    handleInvoke:(info)->
        if not info.id or not info.name
            throw "invalid message #{JSON.stringify(message)}"
        target = null
        for api in @apis
            if api.name is info.name
                target = api
                break
        if not target
            @response(info.id,"#{info.name} api not found")
            return
        target.handler info.data,(err,data)=>
            @response info.id,err,data
exports.MessageCenter = MessageCenter