local component = require("component")
local event = require("event")
local computer = require("computer")
local modem = component.modem

local Socket = {
    selfPort = 0, -- port of the socket
    connectedPort = 0, -- port of the connected socket

    localAddress = "", -- address of the socket
    remoteAddress = "", -- connected to address

    state = "closed", -- closed, open, connecting, connected, listening
    protocol = "Generic Socket" -- protocol/purpose of the socket

}

function findFreePort() -- finds a free port to use
    local port = tonumber(math.random(1, 65535))
    local port = math.floor(port)
    if modem.isOpen(port) then
        return findFreePort()
    else
        return port
    end
end

function Socket:new() -- create a new socket
    local o = {}
    setmetatable(o, self)
    self.__index = self
    self.address = modem.address
    self.port = findFreePort()
    return o
end

function Socket:connect(address, port) -- connect to a socket
    self.state = "connecting"
    modem.send(address, port, "socket_connect_request")
    local _, _, from, port, _, message = event.pull("modem_message")
    if message == "socket_connect_accept" then
        self.address = from
        self.port = port
        return true
    else
        return false
    end
end

function Socket:openFreePort()
    self.port = findFreePort()
    modem.open(self.port)
end

function Socket:bind(port) -- binds the socket to a port (opens the socket)
    if modem.isOpen(port) then -- if the port is already open, return false and do nothing
        return false
    end

    self.port = port
    self.address = modem.address
    self.state = "open"
    modem.open(port)
    return true

end

function Socket:close() -- closes the socket
    modem.close(self.port)
    self.state = "closed"
end

function Socket:_send(address, port, message) -- sends a message to a socket
    self.openFreePort()
    self.state = "open"
    modem.send(address, port, message)
end

function Socket:_recv(address, port)
    local recived = false
    while not recived do
        local _, _, from, port, _, message = event.pull("modem_message")
        if from == address and port == port then
            recived = true
            return message
        end
    end
end

function Socket:send(message) -- sends a message to the connected socket
    self:_send(self.remoteAddress, self.connectedPort, message)
end