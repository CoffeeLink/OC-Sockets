-- This module is made for the OpenComputers mod for Minecraft.
-- And is a wrapper for the OpenComputers' modem API.

-- Github: https://github.com/aron0614/OC-Sockets

-- importing libraries
local component = require("component")
local event = require("event")
local computer = require("computer")
local serializer = require("serialization")
local ModemComp = component.modem


-- Static Variables
TCP = "TCP"
UDP = "UDP"

-- the payload
local Payload = {
    protocol = nil, -- TCP or UDP

    sourceAddress = nil, -- the address of the sender
    destinationAddress = nil, -- the address of the receiver

    sourcePort = nil, -- the port of the sender
    destinationPort = nil, -- the port of the receiver

    dataType = nil, -- the type of data
    data = nil,
}

function Payload:new(protocol, sourceAddress, destinationAddress, sourcePort, destinationPort, dataType, data)
    -- basic constructor stuff
    local o = {}
    setmetatable(o, self)
    self.__index = self
    -- setting Variables
    self.protocol = protocol
    self.sourceAddress = sourceAddress
    self.destinationAddress = destinationAddress
    self.sourcePort = sourcePort
    self.destinationPort = destinationPort
    self.dataType = dataType
    self.data = data
    -- returning the object
    return o
end

function Payload:serialize()
    local data = {
        protocol = self.protocol,
        sourceAddress = self.sourceAddress,
        destinationAddress = self.destinationAddress,
        sourcePort = self.sourcePort,
        destinationPort = self.destinationPort,
        dataType = self.dataType,
        data = self.data
    }
    return serializer.serialize(data)
end

function Payload:deserialize(data)
    local data = serializer.unserialize(data)
    return Payload:new(data.protocol, data.sourceAddress, data.destinationAddress, data.sourcePort, data.destinationPort, data.dataType, data.data)
end

local SegmentData = {
    packetID = nil,
    segmentID = nil,
    segmentCount = nil,
    data = nil,
    ack = false
}

function SegmentData:new(packetID, segmentID, segmentCount, ack, data)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    self.packetID = packetID
    self.segmentID = segmentID
    self.segmentCount = segmentCount
    self.ack = ack
    self.data = data
end

function SegmentData:toTable()
    local t = {
        packetID = self.packetID,
        segmentID = self.segmentID,
        segmentCount = self.segmentCount,
        ack = self.ack,
        data = self.data
    }
    return t
end

local Socket = {
    -- Socket Variables
    protocol = nil,
    state = nil,

    localAddress = nil,
    localPort = nil,

    remoteAddress = nil,
    remotePort = nil,

    modem = nil, -- the modem component

    -- SDP Variables (Socket Discovery Protocol)
    sdpAdvertEnabled = true,
    sdpKnownSockets = {}, -- the known sockets sturcture: {address = {port = {protocol, description}, ...}, ...}
    description = "Generic Network Socket", -- the description of the socket

    --tcp stuff
    recivedSegmentData = {}, -- struct: {packetID:payload, ..}
    recivedData = {}, -- sturct: {payload, payload, ...}
    lastPacketID = 0,
    
    -- server side
    server = false,
    serverConnections = {}, -- struct {address = {port = {socket}, ...}, ...}
    serverConnectionQueue = {}, -- struct {address = {port = {socket}, ...}, ...}

    -- client side
    connected = false,

    -- timeouts and timers
    -- SDP
    sdpResponseTimeout = 5, -- the timeout for the response of a SDP request
    sdpResponseTimer = nil, -- the timer for the response of a SDP request

    -- TCP
    tcpAckTimeout = 5, -- the timeout for the ack of a packet
    tcpAckTimer = nil, -- the timer for the ack of a packet
    tcpAckResendLimit = 2,  -- the amount of times the socket will resend a packet before closing the connection

    connectionTimeout = 5, -- the timeout for the connection
    connectionTimer = nil, -- the timer for the connection

}

function Socket:new(protocol, description, modem) -- constructor
    local o = {}
    setmetatable(o, self)
    self.__index = self
    -- setting variables
    self.protocol = protocol
    self.description = description or self.description
    self.modem = modem or ModemComp
    -- checking if the modem is present
    if self.modem == nil then -- if there is no modem component
        error("Could not find a modem component")
    end
    -- returning the object
    return o
end

function Socket:open(port)
    if self.modem.isOpen(port) then -- if the port is already open by another socket throw an error
        error("Port is already open")
    end

    if self.state == "open" then -- if the socket is already open, close current port and open new one
        if self.protocol == TCP and self.connected then -- if the socket is connected and TCP
            error("Can't change port while connected")
        end

        if self.protocol == TCP and self.server then -- if the socket is a server
            error("Can't change port while server is running")
        end

        self.modem.close(self.localPort)
        self.localPort = port
        self.modem.open(port)
        return
    end
    
    self.localPort = port
    self.modem.open(port)
    self.state = "open"
end

function Socket:close()
    if self.state == "closed" then -- if the socket is already closed
        error("Socket is already closed")
    end
    self.modem.close(self.localPort)
    self.state = "closed"
    self.localPort = nil

    self.connected = false
    self.remoteAddress = nil
    self.remotePort = nil
end

function Socket:findFreePort()
    local port = math.random(1, 65535)
    while self.modem.isOpen(port) do
        port = math.random(1, 65535)
    end
    return port  
end

function Socket:sendRaw(address, port, protocol, dataType, data)
    local packet = Payload:new(protocol, self.localAddress, address, self.localPort, port, dataType, data)
    self.modem.send(address, port, packet:serialize())
end

function Socket:sendto(address, port, data)
    if self.state == "closed" then
        self:open(self:findFreePort())
    end
    
    if self.protocol == TCP then
        if not self.connected then
            error("Socket is not connected")
        end
        self:sendRaw(address, port, self.protocol, "data", nil, data)
    end
    self:sendRaw(address, port, self.protocol, "data", nil, data)
end


function Socket:on_recive(_, targetAddress, senderAddress, port, distance, message)
    if pcall(serializer.unserialize(message)) == false then
        return
    end
    local packet = Payload:deserialize(message)
    if packet.destinationAddress ~= self.localAddress then
        return
    end
    if packet.destinationPort ~= self.localPort then
        return
    end
    if packet.protocol ~= self.protocol then
        return
    end

    if packet.packetType == "Generic" then
        print(packet)
    end

    if packet.packetType == "segment_init" then
        self:_handleSegmentInit(packet)
    end
    if packet.packetType == "segment_data" then
        --segment data arived YIPPIE
    end
end

function Socket:_handleSegmentInit(packet)
    self.lastPacketID = self.lastPacketID + 1
    self.recivedSegmentData[self.lastPacketID] = packet
    self:sendRaw(packet.sourceAddress, packet.sourcePort, self.protocol, "segment_init_ack", self.lastPacketID)
end

function Socket:_handleSegmentData(packet)
    --nice
end


-- return the module
return {
    Payload = Payload, -- the payload class for sending and receiving data
    Socket = Socket, -- the Socket wrapper for the modem API
    TCP = TCP, -- the TCP protocol ENUM
    UDP = UDP, -- the UDP protocol ENUM
}