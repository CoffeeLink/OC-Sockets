-- This module is made for the OpenComputers mod for Minecraft.
-- And is a wrapper for the OpenComputers' modem API.

-- Github: https://github.com/aron0614/OC-Sockets

-- importing libraries

local component = require("component")
local event = require("event")
local serialization = require("serialization") -- for serialization
local computer = require("computer") -- for computer.uptime()
local thread = require("thread") -- for multithreading
local m = component.modem -- modem component

-- payload structure
local Payload = {
    payloadID = nil,
    payloadType = nil,
    payloadData = nil,

    senderAddress = nil,
    senderPort = nil,

    receiverAddress = nil,
    receiverPort = nil,
}
Payload.__index = Payload

function Payload.new(payloadID, payloadType, payloadData, senderAddress, senderPort, receiverAddress, receiverPort)
    local self = setmetatable({}, Payload)

    self.payloadID = payloadID
    self.payloadType = payloadType
    self.payloadData = payloadData

    self.senderAddress = senderAddress
    self.senderPort = senderPort

    self.receiverAddress = receiverAddress
    self.receiverPort = receiverPort

    return self
end

function Payload.fromMessage(msg)
    local self = setmetatable({}, Payload)
    local payload = serialization.unserialize(msg)

    self.payloadID = payload.payloadID
    self.payloadType = payload.payloadType
    self.payloadData = payload.payloadData

    self.senderAddress = payload.senderAddress
    self.senderPort = payload.senderPort

    self.receiverAddress = payload.receiverAddress
    self.receiverPort = payload.receiverPort

    return self
end

function Payload:toMessage()
    return serialization.serialize(self)
end
-- socket structure

local Socket = {
    -- socket properties
    name = "Generic Socket",

    socketType = nil,

    modem = m,

    isOpen = false,
    isServer = false,
    isListening = false,
    isClient = false,
    isConnection = false,

    localPort = nil,
    localAddress = nil,

    remotePort = nil,
    remoteAddress = nil,

    recv_thread = nil,
    cleanup_thread = nil,

    -- for server
    connectionQueue = {}, -- {connID, senderAddress, senderPort, receiverAddress, receiverPort, ...}
    connectionQueueLimit = 0,

    lastConnectionID = 0,

    connections = {},
    clientLimit = 0,

    connectionData = {}, -- {connID: {state}}

    -- for client
    connected = false,
    connectionAcked = false,
    connectionID = 0,

    -- for both
    payloadID = 0,
    recived = {}, -- {payload, ...}

    -- Statics for socket types
    CLIENT = "client", -- client socket
    SERVER = "server", -- server socket

    SERVER_CONN = "server_conn", -- [Know what you're doing] server connection socket

    -- SDP (Socket Discovery Protocol) variables
    SDP_PORT = 4378, -- SDP port (default: 4378)
    SDP_TIMEOUT = 1, -- SDP timeout (in seconds)
    SDP_TIMER = nil, -- SDP timer
    SDP_KNOWN = {}, -- SDP known sockets struct {{address, port, name, type},  ...} 
    SDP_ENABLED = true, -- SDP enabled (default: true)
}
Socket.__index = Socket

-- Creates a new *socket* object
-- @param socketType (Required) The type of socket to create
-- @param socketName (optional) The name of the socket
-- @param modem (optional) The modem to use
-- @return Socket
function Socket.new(socketType, socketName, modem)
    local self = setmetatable({}, Socket)

    self.socketType = socketType
    self.name = socketName or "Generic Socket"
    self.modem = modem or m
    self.localAddress = self.modem.address

    if self.socketType == self.SERVER then
        self.isServer = true
    elseif self.socketType == self.CLIENT then
        self.isClient = true
        self:open()
    elseif self.socketType == self.SERVER_CONN then
        self.isConnection = true
        self.isOpen = true
        
    else
        error("Invalid socket type")
    end

    return self
end

function Socket._on_recive(self)
    while true do
        local _, myaddr, senderAddress, senderPort, _, message = event.pull("modem_message") -- wait for a message

        -- check if message is a valid payload
        if pcall(serialization.unserialize, message) == false then
            goto continue
        end

        local payload = Payload.fromMessage(message) -- decode payload

        -- check if payload is a SDP payload
        if payload.payloadType == "SDP_REQUEST" or payload.payloadType == "SDP_RESPONSE" then
            self:handleSDP(payload)
            goto continue
        end

        -- check if payload is a conection payload (CONN_REQUEST, CONN_REQ_ACK, CONN_ACCEPT, CONN_CLOSE)
        if payload.payloadType == "CONN_REQUEST" then
            self:handleConnectionRequest(payload)

        elseif payload.payloadType == "CONN_REQ_ACK" then
            self:handleConnectionRequestAck(payload)

        elseif payload.payloadType == "CONN_ACCEPT" then
            self:handleConnectionAccept(payload)

        elseif payload.payloadType == "CONN_CLOSE" then
            thread.create(function() self:handleConnectionClose(payload) end)
        end

        -- check if payload is for this socket
        if self.connected then
            if self.remotePort ~= payload.senderPort or self.remoteAddress ~= payload.senderAddress then
                goto continue
            end
        end

        if payload.payloadType == "DATA" then
            if self.isServer then
                for _, client in pairs(self.connections) do
                    if client.remotePort == payload.senderPort and client.remoteAddress == payload.senderAddress then
                        table.insert(client.recived, payload)
                        goto continue
                    end
                end
            end

            table.insert(self.recived, payload)
        end
        
        ::continue::
    end
end

function Socket._cleanup_thread(self)
    local _, _ = event.pull("interrupted")
    self:close()
end

function Socket:_sendRaw(targetAddr, targetPort, payloadType, payloadData)
    local payload = Payload.new(self.payloadID, payloadType, payloadData, self.localAddress, self.localPort, targetAddr, targetPort)
    local msg = payload:toMessage()
    if msg == nil then
        error("Failed to encode payload")
    end

    self.modem.send(targetAddr, targetPort, msg)
end

function Socket:findFreePort() -- find a free port returns a port that if free
    local port = math.random(1, 65535)
    while self.modem.isOpen(port) do
        port = math.random(1, 65535)
    end
    return port
end

-- Opens the socket on a port
-- @param port (optional) The port to open the socket on
-- @return error | true
function Socket:open(port)
    if self.isOpen then
        error("Socket already open")
    end

    port = port or self:findFreePort()
    self.modem.open(port)
    self.localPort = port
    self.isOpen = true

    -- SDP port open
    self.modem.open(self.SDP_PORT)

    self.recv_thread = thread.create(self._on_recive, self)
    self.cleanup_thread = thread.create(self._cleanup_thread, self)

    return true
end


-- Closes the socket
function Socket:close()
    self.modem.close(self.localPort)
    self.isOpen = false
    self.recv_thread:kill()
    if self.cleanup_thread:status() == "running" then
        self.cleanup_thread:kill()
    end

    -- SDP port close
    self.modem.close(self.SDP_PORT)

    self.localPort = nil
end

-- starts listening for connections
-- [SERVER ONLY]
-- @param connectionQueueLimit (optional) The maximum number of connections to queue
function Socket:listen(connectionQueueLimit)
    if not self.isServer then
        error("Socket is not a server")
    end
    self.connectionQueueLimit = connectionQueueLimit or 6
    self.isListening = true
end

-- stops listening for connections
-- [SERVER ONLY]
function Socket:stopListening()
    if not self.isServer then
        error("Socket is not a server")
    end
    self.isListening = false
end

-- Attempts to connect to a server
-- [CLIENT ONLY]
-- @param addr the address to connect to
-- @param port the port to connect to
-- @return boolean
function Socket:connect(addr, port)
    self:_sendRaw(addr, port, "CONN_REQUEST", nil)

    local e = event.pull(5, "socket_connection_accepted"..self.localPort)
    if e == nil then
        return false -- connection timed out
    end
    
    self.remoteAddress = addr
    self.remotePort = port
    self.connected = true
    return true -- connection is now established
end

-- Disconnects from a server
-- [CLIENT ONLY]
function Socket:disconnect()
    if not self.connected then
        error("Socket is not connected")
    end
    self:_sendRaw(self.remoteAddress, self.remotePort, "CONN_CLOSE", nil)
end

-- Accepts a connection from a client
-- [Blocking] [SERVER ONLY]
-- @return Socket
function Socket:accept()
    if not self.isServer then
        error("Socket is not a server")
    end

    if not self.isListening then
        error("Socket is not listening")
    end

    while true do
        if #self.connectionQueue > 0 then
            local connectionInfo = self.connectionQueue[1]

            table.remove(self.connectionQueue, 1)

            self:_sendRaw(connectionInfo.remoteAddress, connectionInfo.remotePort, "CONN_ACCEPT", connectionInfo.connID)
            local socket = self.new(self.SERVER_CONN, "Connection of server", self.modem)
            socket.connectionID = connectionInfo.connID
            socket.SDP_ENABLED = false
            socket.connected = true
            socket.remoteAddress = connectionInfo.remoteAddress
            socket.remotePort = connectionInfo.remotePort
            socket.localAddress = self.localAddress
            socket.localPort = self.localPort

            table.insert(self.connections, socket)
            return socket
        end
        computer.pullSignal(0.1)
    end
end

-- connection handlers
function Socket:handleConnectionRequest(payload)
    local connID = payload.senderAddress .. ":" .. payload.senderPort
    local resp = {
        connID = connID,
    }
    self:_sendRaw(payload.senderAddress, payload.senderPort, "CONNECTION_REQ_ACK", resp)

    local conn = {
        connID = connID,
        remoteAddress = payload.senderAddress,    
        remotePort = payload.senderPort,
        localAddress = self.localAddress,
        localPort = self.localPort,
    }
    table.insert(self.connectionQueue, conn)
end

function Socket:handleConnectionRequestAck(payload)
    -- client side, if this payload arrives add it to connectionPayloads
    self.connectionID = payload.payloadData.connID
    event.push("socket_connection_request_acked", payload.payloadData.connID)
end

function Socket:handleConnectionAccept(payload)
    self.connected = true
    self.remoteAddress = payload.senderAddress
    self.remotePort = payload.senderPort
    event.push("socket_connection_accepted"..self.localPort, payload.payloadData.connID)
end

function Socket:handleConnectionClose(payload)
    if self.isServer then
        if not payload.payloadData.connected then
            -- if its not connected then its still in request stage
            local index, conn = self:getConnectionInQueueById(payload.payloadData.connID)

            if conn then
                table.remove(self.connectionQueue, index)
            end

            return true
        end
        -- if its connected then its in the connection stage
        for i, conn in ipairs(self.connections) do
            if conn.connectionID == payload.payloadData.connID then
                conn.connected = false
                table.remove(self.connections, i)
                return true
            end
        end
        return false
    else -- client
        self.connected = false
        self.remoteAddress = nil
        self.remotePort = nil
    end
end

-- connInfo, index
function Socket:getConnectionInQueueById(connID)
    for i, conn in ipairs(self.connectionQueue) do
        if conn.connID == connID then
            return conn, i
        end
    end
    return nil
end

--traffic commands

-- Sends data to a connected socket
-- @param data the data to send
function Socket:send(data)
    if not self.connected then
        error("Client not connected")
    end
    self:_sendRaw(self.remoteAddress, self.remotePort, "DATA", data)
end

-- Sends data to a target address and port
-- @param data the data to send
-- @param targetAddress the address to send to
-- @param targetPort the port to send to
function Socket:sendTo(data, targetAddress, targetPort)
    self:_sendRaw(targetAddress, targetPort, "DATA", data)
end

-- Recives data from a connected socket
-- [Blocking] Waits for data to be recived
-- @return the data recived
function Socket:recv()
    while true do
        if #self.recived > 0 then
            local payload = self.recived[1]
            table.remove(self.recived, 1)
            return payload.payloadData
        end
        computer.pullSignal(0.05)
    end
end

-- Recives data from a socket
-- [Blocking] Waits for data to be recived
-- @return data, senderAddress, senderPort
function Socket:recvFrom()
    while true do
        if #self.recived > 0 then
            local payload = self.recived[1]
            table.remove(self.recived, 1)
            return payload.payloadData, payload.senderAddress, payload.senderPort
        end
        computer.pullSignal(0.05)
    end
end

-- Gets all active sockets on the network using SDP
-- [Blocking] Waits for responses for timeout seconds
-- @param timeout how long to wait for responses (default 2 seconds)
-- @return table of sockets struct: {{name, type, address, port}, ...}
function Socket:getAllSocketsOnNetwork(timeout)
    timeout = timeout or 2
    self.SDP_KNOWN = {}

    self.modem.broadcast(self.SDP_PORT, Payload.new(0, "SDP_REQUEST", nil, self.localAddress, self.SDP_PORT, nil, self.SDP_PORT):toMessage())
    
    self.SDP_TIMER = computer.uptime() + timeout

    while computer.uptime() < self.SDP_TIMER do
        computer.pullSignal(0.05)
    end

    return self.SDP_KNOWN
end

-- handlers
function Socket:handleSDP(payload)
    if payload.payloadType == "SDP_REQUEST" and self.SDP_ENABLED then
        self:_sendRaw(payload.senderAddress, self.SDP_PORT, "SDP_RESPONSE", {self.name, self.socketType, self.localPort})
    elseif payload.payloadType == "SDP_RESPONSE" then
        local SDP_INFO = {
            name = payload.payloadData[1],
            socketType = payload.payloadData[2],
            port = payload.payloadData[3],
            address = payload.senderAddress
        }
        table.insert(self.SDP_KNOWN, SDP_INFO)
    else
        return false
    end
end

-- checks
function Socket:_check_server_listening()
    if self.isListening and self.isServer then
        return true
    else
        return false
    end
end

return Socket -- return the socket class