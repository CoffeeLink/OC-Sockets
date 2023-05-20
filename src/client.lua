local component = require("component")
local event = require("event")
local computer = require("computer")
local m = component.modem -- modem component

local socket = require("socket")

local c = socket.new(socket.CLIENT, "Test Client")
c.SDP_ENABLED = false
print("Searching for servers...")
local addrs = c:getAllSocketsOnNetwork(2)
for i = 1, #addrs do
    print(addrs[i].name, addrs[i].address)
end


local connected = c:connect(addrs[1].address, 5454)

if not connected then
    print("Failed to connect to server!")
    return
end

print("Connected to server!")
c:disconnect()