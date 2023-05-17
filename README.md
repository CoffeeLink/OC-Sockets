# OC-Sockets

OC-Sockets is a wrapper for opencomputers modem API

## Installation

Use the installer scripts wich can be dowloaded with 
```bash
wget https://raw.githubusercontent.com/aron0614/OC-Sockets/main/installer.lua
```
when downaloaded just run the script

## Usage
<details><summary>Examples</summary>
<br>

### A basic TCP server - client script example
server:
```lua
local sockets = require("sockets")

--creating a socket object
local sock = socktets.Socket:new(sockets.TCP, "Socket Server Example")

--opening a specific port
sock:bind(5555) --int: port

-- start listening for connections, also becomes a server object
sock:listen(5) --int: connection queue size

local conn, addr = sock:accept() --conn: a socket obj, addr: address of the socket

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
local sockets = require("sockets")

--creating a socket object
local sock = socktets.Socket:new(sockets.TCP, "Socket Client Example")

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


## Contributing

Pull requests are welcome. For major changes, please open an issue first
to discuss what you would like to change.

## License

[MIT](https://choosealicense.com/licenses/mit/)