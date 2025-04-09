# OC-Sockets

OC-Sockets is a wrapper for opencomputers modem API

## Installation

Use the installer scripts wich can be dowloaded with 
```bash
wget https://raw.githubusercontent.com/CoffeeLink/OC-Sockets/master/src/installer.lua
```
when downaloaded just run the script

## Usage
<details><summary>Examples</summary>
<br>

### A basic TCP server - client script example
server:
```lua
local socket = require("socket")

--creating a socket object
local sock = socket.Socket:new(socket.SERVER, "Socket Server Example")

--opening a specific port
sock:open(5555) --int: port

-- start listening for connections, also becomes a server object
sock:listen(5) --int: connection queue size

local conn = sock:accept() --conn: a socket obj

--sending a mesage to a connected client
conn:send("Hello world!")

local data = conn:recv() -- waits until a packet is recived or connection closed

--closing connections

conn:close() -- closes client object
sock:close() -- closes the server

print(data) -- recived data

```

client:
```lua
local socket = require("socket")

--creating a socket object
local sock = socket.Socket:new(sockets.TCP, "Socket Client Example")

--connecting
sock:connect(addr, 5555) --addr[str]: address of server, --port[int]: the port
--this returns false if failed, or if it fails sock:connected == false

--reciving
local data = sock:recv()
--sending it back
sock:send(data)

print(data) -- outputing the recived data

--closing/disconecting
-- sock:disconnect() --disconects from the server

sock:close() -- disconects and closes itself

```
</details>

## Documentation
### Creating a socket
```lua
local socket = require("socket") -- importing the module

--creating a socket
local sock = socket.new(socket.CLIENT, [Optional "Name of Socket"], [Optional Modem])
```

### Opening and closing a socket

```lua
sock:open() -- open on a random port

sock:open(1110) -- open socket on port 1110

sock:close() -- closes currently open port
```

### Sending and reciveing messages directly

```lua
sock:sendTo(targetAddr, targetPort, data)
-- params: 
-- targetAddr: (str) Address of target
-- targetPort: (number) Port of target
-- data: (str | number | table) the data to send

local senderAddr, senderPort, data = sock:recvFrom() -- returns the addr info of the sender
```

### listening, connecting and accepting connections
```lua
-- to listen for connections the socketType must be socket.SERVER
sock:listen(queueSize) -- queueSize[number] the number of connections that can wait for acception

--accept a connection
local conn = sock:accept() -- returns a socket obj that can send/recv messages

-- connecting to a server
sock:connect(addr, port) -- addr: addr, port: port -of server
```
### Sending / reciveing data from connected clients/servers
```lua
sock:send(data) -- sends data to connected remote, must be connected
local data = sock:recv() -- recives data from connected remote
```

### SDP(Socket Discorvery Protocol) commands
```lua
-- disableing/enableing
sock.SDP_ENABLE = true -- if false: when other sockets create a SDP request it wont advertise itself (privacy basically)

-- geting all sockets on network
local sockets = sock:getAllSocketsOnNetwork(timeout) -- timeout: number (default: 2 seconds)
-- returns a table of {name, type, addr, port}
```

## Contributing

Pull requests are welcome. For major changes, please open an issue first
to discuss what you would like to change.

## License

[MIT](https://choosealicense.com/licenses/mit/)
