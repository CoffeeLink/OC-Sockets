local component = require("component")
local event = require("event")
local computer = require("computer")
local thread = require("thread")
local m = component.modem -- modem component

local socket = require("socket")

local s = socket.new(socket.SERVER, "Test Server")
s:open(5454)
s:listen()
print("Listening on port 5454...")
local clients = {}

function handleClient(client)
    while true do
        client:send("Hello, client!")
        client:recv()
        os.sleep(0.5)
    end
end

while true do
    local client = s:accept()
    print("Accepted client!", "Port", client.remotePort)
    table.insert(clients, client)
    thread.create(handleClient, client)
end