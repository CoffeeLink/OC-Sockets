-- This module is made for the OpenComputers mod for Minecraft.
-- And is a wrapper for the OpenComputers' modem API.

-- Github: https://github.com/aron0614/OC-Sockets

-- importing libraries
local component = require("component")
local event = require("event")
local computer = require("computer")
local serializer = require("serialization")
local ModemComp = component.modem

-- devTasks
-- to-do: finnis all methods with -- finnis tag

-- socket types
local SERVER = 0  -- set the socket as a server
local CLIENT = 1 -- set the socket as a client
local SERVER_CONNECTION = 3 -- [Read Dev Docs before use] set the socket as a server connection

-- socket states
local CLOSED = 0 -- the socket is closed
local OPEN = 1 -- the socket is open
local CONNECTING = 2 -- the socket is connecting
local CONNECTED = 3 -- the socket is connected
local LISTENING = 4 -- the socket is listening

-- socket data types

local ACK = 0 -- the socket data is an ack packet
local PACKET = 1 -- the socket data is a packet

local SOCK_CONNECT_REQUEST = 2 -- the socket data is a socket connect request packet
local SOCK_CONNECT_RESPONSE = 3 -- the socket data is a socket connect response packet

local SOCK_CLOSE = 4 -- the socket data is a socket close packet

local SEGMENT_DATA = 5 -- the socket data is a segment
local SEGMENT_INIT = 6 -- the socket data is a segment init packet
local SEGMENT_ACK = 7 -- the socket data is a segment ack packet

local SDP_REQUEST = 8 -- the socket data is a sdp request packet
local SDP_RESPONSE = 9 -- the socket data is a sdp response packet

-- ack types
local CONNECT_REQUEST_ACK = 0 -- the ack is a connect request ack
local CONNECT_ACCEPT = 1 -- the ack is a connect accept ack
local CONNECT_DENY = 2 -- the ack is a connect deny ack
local CONNECT_TIMEOUT = 3 -- the ack is a connect timeout ack

-- classes
-- Segment class
local Segment = {
    -- segment variables
    segmentID = nil, -- the segment id of the segment
    segmentCount = nil, -- number of segments in the packet
    ack = false, -- tells the reciver to send an ack packet
    data = nil, -- the data of the segment
}
Segment.__index = Segment

-- Segment constructors -------------------------------------------
function Segment.new(segmentID, segmentCount, ack, data)
    local inst = setmetatable({}, Segment)
    inst.segmentID = segmentID
    inst.segmentCount = segmentCount
    inst.ack = ack
    inst.data = data

    return inst
end
    
-- Segment methods -------------------------------------------
function Segment:toTable()
    return {segmentID = self.segmentID, segmentCount = self.segmentCount, ack = self.ack, data = self.data}
end

-- Packet class
local Packet = {
    -- packet variables
    payloadID = nil, -- the payload id of the packet
    senderAddress = nil, -- the sender address of the packet
    senderPort = nil, -- the sender port of the packet
    targetAddress = nil, -- the target address of the packet
    targetPort = nil, -- the target port of the packet
    dataType = nil, -- the data type of the packet
    data = nil, -- the data of the packet
}
Packet.__index = Packet

-- Packet constructors -------------------------------------------

function Packet.new(payloadID, senderAddr, senderPort, targetAddr, targetPort, dataType, data)
    local inst = setmetatable({}, Packet)
    inst.payloadID = payloadID
    inst.senderAddress = senderAddr
    inst.senderPort = senderPort
    inst.targetAddress = targetAddr
    inst.targetPort = targetPort
    inst.dataType = dataType
    inst.data = data

    return inst
end

function Packet.fromMessage(message)
    local packet = serializer.unserialize(message)
    return Packet.new(packet.payloadID, packet.senderAddress, packet.senderPort, packet.targetAddress, packet.targetPort, packet.dataType, packet.data)
end

-- Packet methods -------------------------------------------
function Packet:toMessage()
    local t = {
        payloadID = self.payloadID,
        senderAddress = self.senderAddress,
        senderPort = self.senderPort,
        targetAddress = self.targetAddress,
        targetPort = self.targetPort,
        dataType = self.dataType,
        data = self.data
    }
    return serializer.serialize(t)
end

-- Socket class
local Socket = {
    -- static variables
    CLIENT = CLIENT,
    SERVER = SERVER,
    SERVER_CONNECTION = SERVER_CONNECTION,

    -- socket variables
    SocketType = nil, -- the type of the socket
    modem = nil, -- the modem component of the socket
    name = nil, -- the description of the socket
    state = nil, -- the state of the socket (open, closed, connecting, connected, listening, etc.)

    localAddress = nil, -- the local address of the socket
    localPort = nil, -- the local port of the socket

    remoteAddress = nil, -- the remote address of the socket
    remotePort = nil, -- the remote port of the socket

    -- payload variables
    lastPayloadID = 0, -- the last payload id of the socket
    recivedSegments = {}, -- the recived segments of the socket struct: {payloadID = {packet}, payloadID = {packet}, ...}
    recivedData = {}, -- the recived data of the socket struct: {packet, packet, packet, ...} (a list of yet to be recived packets)

    -- server variables
    connections = {}, -- the connections of the server socket structure: {Socket, Socket, Socket, ...}
    connectionQueue = {}, -- the connection queue of the server socket structure: {Socket, Socket, Socket, ...}
    connectionQueueSize = 0, -- the connection queue size of the server socket

    parent = nil, -- the parent of the client connection (the server socket)

    -- client variables
    connected = false, -- the connection status of the client socket
    

    -- built in protocol variables
    sdpAdvertEnabled = false, -- the sdp advert status of the socket
    sdpData = {} -- the sdp data of the socket struct: {{address, port, name, type}, {address, port, name, type}, ...}
}
Socket.__index = Socket



-- Socket constructors -------------------------------------------
function Socket.new(socketType, name, modem)
    local inst = setmetatable({}, Socket)
    inst.SocketType = socketType
    inst.name = name or "Generic Socket Object"
    inst.modem = modem or ModemComp
    inst.localAddress = inst.modem.address

    inst.state = CLOSED

    return inst
end

function Socket.asConnection(parent, remoteAddr, remotePort)
    local inst = setmetatable({}, Socket)
    inst.SocketType = SERVER_CONNECTION
    inst.parent = parent
    inst.modem = parent.modem
    inst.localAddress = parent.localAddress
    inst.localPort = parent.localPort
    inst.remoteAddress = remoteAddr
    inst.remotePort = remotePort
    inst.state = CONNECTING

    return inst
end

-- Socket methods -------------------------------------------

function Socket:findFreePort() -- find a free port returns a port that if free
    local port = math.random(1, 65535)
    while self.modem.isOpen(port) do
        port = math.random(1, 65535)
    end
    return port
end

function Socket:open(port) -- open the socket on a port
    if self.state == CLOSED then
        self.localPort = port or self:findFreePort()
        self.modem.open(self.localPort)
        self.state = OPEN
    elseif self.state == OPEN then
        self.modem.close(self.localPort)
        self.localPort = port or self:findFreePort()
        self.modem.open(self.localPort)
    else
        error("Socket is connected or has connections")
    end
    if self.SocketType == CLIENT then
        event.listen("modem_message", self.on_recive)
    end
end

function Socket:close() -- close the socket
    if self.localPort == nil then
        error("Socket is not open")
    end
    self.modem.close(self.localPort) -- close the port

    self.state = CLOSED -- update the state

    -- reset the variables
    self.localPort = nil
    self.remoteAddress = nil 
    self.remotePort = nil
    self.connected = false

    if self.SocketType == CLIENT then
        event.ignore("modem_message", self.on_recive)
    end

    if self.SocketType == SERVER then
        for _, connection in pairs(self.connections) do
            connection:close()
        end

        if self.state == LISTENING then
            self.state = CLOSED
            event.ignore("modem_message", self.on_recive)
        end
    end
end

function Socket:_SendRaw(targetAddress, targetPort, packetID, dataType, data) -- send raw data to a target address
    local packet = Packet.new(packetID, self.localAddress, self.localPort, targetAddress, targetPort, dataType, data)
    self.modem.send(targetAddress, targetPort, packet:toMessage())
end

function Socket:getAck(timeout, ackType)
    timeout = timeout or 5
    local timer = computer.uptime() + timeout
    while computer.uptime() < timer do
        for i, packet in pairs(self.recivedData) do
            if packet.dataType == ACK and packet.data == ackType then
                table.remove(self.recivedData, i)
                return packet
            end
        end
    end
    return nil
end

-- Socket Built In Protocol Methods -------------------------------------------

function Socket:setSDPAdvertStatus(state) -- set the sdp advert status of the socket
    self.sdpAdvertEnabled = state
end

function Socket:getSocketsOnNetwork() -- get the sockets on the network
    -- finnis
end

-- server methods -------------------------------------------
function Socket:listen(queueSize) -- listen for connections on the socket
    self:_check_serverOnly()
    if self.state ~= OPEN then
        error("Socket is not open")
    end

    self.state = LISTENING
    self.connectionQueueSize = queueSize or 5
    event.listen("modem_message", self.on_recive)
end

function Socket:stopListening() -- stop listening for connections on the socket
    self:_check_serverOnly()
    if self.state ~= LISTENING then
        error("Socket is not listening")
    end
    self.state = OPEN
    event.ignore("modem_message", self.on_recive)
end

function Socket:accept() -- [BLOCKING] queuePos: int = 1, accept a connection from the queue Retutns: Socket
    self:_check_serverOnly()

    if self.state ~= LISTENING then
        error("Socket is not listening")
    end

    while true do
        if self.connections[1] ~= nil then
            local connection = self.connections[1]
            table.remove(self.connections, 1)
            return connection
        end
    end
end

-- client methods -------------------------------------------
function Socket:connect(address, port) -- connect to a socket returns: boolean (true if connected)
    self:_check_clientOnly()
    -- finni
end

function Socket:send(data) -- send data to the connected socket
    self:_check_clientOnly()
    if self.state ~= CONNECTED then
        error("Socket is not connected")
    end
    self:_SendRaw(self.remoteAddress, self.remotePort, 0, PACKET, data)
end

function Socket:sendTo(addr, port, data) -- send data to a specific address
    self:_SendRaw(addr, port, 0, PACKET, data)
end

function Socket:sendall(data) -- a function to send large data, segments the data and sends it
    self:_check_clientOnly()
    --finnis
end
-- [BLOCKING] recive data from the connected socket
function Socket:recv()
    self:_check_clientOnly()
    while true do
        if self.recivedData[1] ~= nil then
            local packet = self.recivedData[1]
            table.remove(self.recivedData, 1)
            return packet.data
        end
    end
end

-- [BLOCKING] recive data from any socket (returns address, port, data)
function Socket:recvfrom() 
    while true do
        if self.recivedData[1] ~= nil then
            local packet = self.recivedData[1]
            table.remove(self.recivedData, 1)
            return packet.senderAddress, packet.senderPort, packet.data
        end
    end
end

-- recive handler
function Socket:on_recive(_, targetAddress, senderAddress, port, distance, message)
    -- turn into packet
    if pcall(serializer.unserialize, message) == false then
        return
    end

    local packet = Packet.fromMessage(message)

    -- check if the packet is for this socket
    if packet.targetAddress ~= self.localAddress or packet.targetPort ~= self.localPort then
        return
    end

    -- check if the packet is a sdp packet
    if packet.dataType == SDP_REQUEST then
        self:_handle_sdp_request_packet(packet)
    elseif packet.dataType == SDP_RESPONSE then
        self:_handle_sdp_response_packet(packet)
    end

    -- check if the packet is a segment packet
    if packet.dataType == SEGMENT_INIT then
        self:_handle_segment_init_packet(packet)
    elseif packet.dataType == SEGMENT_DATA then
        self:_handle_segment_data_packet(packet)
    end

    -- check if the packet is a generic packet
    if packet.dataType == PACKET then
        self:_handle_generic_packet(packet)
    end

    -- check if the packet is a connection packet
    if packet.dataType == SOCK_CONNECT_REQUEST then
        self:on_connect_request(packet)
    elseif packet.dataType == SOCK_CONNECT_RESPONSE then
        self:on_connect_response(packet)
    elseif packet.dataType == SOCK_CLOSE then
        self:on_disconnect_request(packet)
    end
end

-- handlers -------------------------------------------
function Socket:_handle_generic_packet(packet)
    table.insert(self.recivedData, packet)
end

function Socket:_handle_segment_init_packet(packet)
    --finnis
end

function Socket:_handle_segment_data_packet(packet)
    --finnis
end

function Socket:_handle_sdp_request_packet(packet)
    --finnis
end

function Socket:_handle_sdp_response_packet(packet)
    --finnis
end

function Socket:on_connect_request(packet)
    --finnis
end

function Socket:on_connect_response(packet)
    --finnis
end

function Socket:on_disconnect_request(packet)
    --finnis
end

-- checks -------------------------------------------
function Socket:_check_serverOnly()
    if self.SocketType ~= SERVER then
        error("This method is only for server sockets")
    end
end

function Socket:_check_clientOnly()
    if self.SocketType == SERVER then
        error("This method is only for client sockets")
    end
end

function Socket:_check_connectionClientOnly()
    if self.SocketType ~= SERVER_CONNECTION then
        error("This method is only for server connection sockets")
    end
end

return Socket