local component = require("component")
local event = require("event")
local computer = require("computer")
local m = component.modem -- modem component

local socket = require("socket")

local c = socket.new(socket.CLIENT, "Test Client")
print("Searching for servers...")
local addrs = c:getAllSocketsOnNetwork(2)
for i = 1, #addrs do
    print(addrs[i].name, addrs[i].address)
end


local connected = c:connect(addrs[2].address, 5454)

if not connected then
    print("Failed to connect to server!")
    return
end

print("Connected to server!")
while true do
    print(c:recv())
    c:send("ping")
end
c:disconnect()