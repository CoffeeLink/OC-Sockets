local component = require("component")
local event = require("event")
local computer = require("computer")
local modem = component.modem

TCP = "TCP"
UDP = "UDP"

Socket = {
    -- Socket
    modem = modem,

    localAddress = nil,
    localPort = nil,

    remoteAddress = nil,
    remotePort = nil,

    -- Socket options
    protocol = nil, -- TCP or UDP
    name = "Generic Network Device", -- Socket name

    timeout = 3, -- Timeout in seconds
    keepAlive = 12, -- Keep alive in seconds
    enableArpAdvert = false, -- Enable ARP advertisement

    -- Socket state
    state = "CLOSED", -- states: CLOSED, OPEN, LISTENING, CONNECTING, CONNECTED, CLOSING
    isOpen = false,

    -- Socket data
    acceptQueue = {}, -- Queue of sockets waiting to be accepted
    receiveData = {}, -- Queue of packets waiting to be fully received used by the internal sendall, recvAll functions
}

function Socket:new(protocol, modem, descriptor)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    self.modem = modem
    self.name = descriptor
    self.protocol = protocol

    self.localAddress = modem.address
    self.localPort = self:getFreePort()

    return o
end

function Socket:getFreePort()
    local port = math.random(1, 65535)
    while self.modem.isOpen(port) do
        port = math.random(1, 65535)
    end
    return port    
end

function Socket:bind(port)
    if self.modem.isOpen(port) then
        return false
    end
    self.localPort = port
    self.modem.open(port)
    self.state = "OPEN"
    self.isOpen = true
end

function Socket:open()
    if self.isOpen then
        return true
    end

    self:bind(self:getFreePort())
end

function Socket:close()
    --TODO add a function that tells TCP clients or servers that im closing
    self.state = "CLOSING"
    --onclose balh blah blah
    self.modem.close(self.localPort)
    self.localPort = nil
    self.isOpen = false
    self.state = "CLOSED"
end

function Socket:_createPacket(data)
    local packet = {
        protocol = self.protocol,
        returnPort = self.localPort,
        data = data,
    }
    return packet
end

function Socket:SendRaw(packet)
    
end

function Socket:getAllDevices()
    -- sends ARP request, waits until ARP timeout, takes all devices
    -- the event that its looking for extends the timeout timer each time it gets a response, sets to ARP timeout
    -- returns a table of devices
end