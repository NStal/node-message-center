MessageCenter is a protocol independant RPC protocol base on json. It's a more human friendly protocol than machine friendly one, To use this protocol the underlying transfer layer should meet these requirements.

1. Can send block of data.
2. Each block of data should either be completely recieved without any mistake or completely droped.

Each block of data is a JSON with some special field, I will describe it latter and let us see some example of using node-message-center with ws module a great websocket implementation in nodejs.

# Install and test
```bash
# install
npm install message-center
# test
# you will need mocha to run the test
# you can get mocha with (sudo) npm install -g mocha
cd node_modules/message-center
npm test
```

```javascript
WebSocket = require("ws");
WebSocketServer = WebSocket.Server;
MessageCenter = require("message-center");

mcClientSide = new MessageCenter();
mcServerSide = new MessageCenter();

server = new WebSocketServer({hostname:"localhost",port:12345})
server.on("connection",function(conn){
    mcServerSide.setConnection(conn);
    mcServerSide.invoke("whoAreYou",{key:"Any data",time:new Date(),buffer:new Buffer("hehe")},function(err,res){
        console.log(res);
    })
})

connection = new WebSocket("ws://localhost:12345/");
connection.on("open",function(){
    mcClientSide.setConnection(connection);
})
connection.on("close",function(){
    mcClientSide.unsetConnection();
})

mcClientSide.registerApi("whoAreYou",function(data,callback){
    console.log("Date is reserved",data.time);
    console.log("Buffer is reserved",data.buffer);
    console.log("It's time to ask who YOU are")
    callback(null,"I'm client and I got your data "+JSON.stringify(data));
    mcClientSide.invoke("areYouServer",null,function(err,data){
        console.log("get response from server:",data);
    })
})
mcServerSide.registerApi("areYouServer",function(data,callback){
    callback(null,"I'm server and I got your data "+JSON.stringify(data));
})

```

MessageCenter has a default time out of 60s, if you don`t like it you can set it manually.
```javascript
var invoke = mcClientSide.invoke("delayReturn",5000,function(err,data){
    console.error(err,data);
    console.assert(err.message === "timeout");
})
invoke.timeout(3000);
//or set for all invokes
mcClientSide.timeout = 3000;
//every request has a 3000 timeout.
```

MessageCenter also support event dispatching without promising.
```javascript
mcServerSide.fireEvent("archive/update",{content:"Lorem Ipsum"})
//Note here we have a "event/" prefix so we don't always conflict with local events by accidents.
mcClientSide.on("event/archive/update",function(data){
    console.log("get data",data,"from event archive/update");
})
```

