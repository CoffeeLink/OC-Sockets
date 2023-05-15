local component = require("component")
local event = require("event")
local computer = require("computer")
local modem = component.modem


-- Static Variables
TCP = "TCP"
UDP = "UDP"

-- Socket Protocols Enums (for configuration) do not change unless you know what you are doing
SocketProtocols = {
    ARP_Port = 7731, -- the port that ARP packets are sent on
    ARP_REQUEST = "ARP_REQUEST",
}

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

    timeout = 3, -- Timeout in seconds, the default timeout value for components that require a timeout
    keepAlive = 12, -- Keep alive in seconds
    enableArpAdvert = true, -- Enable ARP advertisement

    -- Socket state
    state = "CLOSED", -- states: CLOSED, OPEN, LISTENING, CONNECTING, CONNECTED, CLOSING
    isOpen = false,

    -- Socket data
    acceptQueue = {}, -- Queue of sockets waiting to be accepted struct: {{address, port}, {address, port} ...}
    receiveData = {}, -- Queue of packets waiting to be proccessed struct: {{id, address, message}, {id, address, message} ...}
    latestId = 0, -- The latest id of a packet that has been received

    -- Socket ARP
    arpTable = {}, -- The ARP table of the socket struct: {{address, port, protocol, name}, {address, port, protocol, name} ...}
    arpTimeout = 0.5, -- The timeout for ARP requests in seconds remaining
    arpTimeoutTotal = 0.5, -- The total timeout for ARP requests in seconds
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

    self.receiveData = {}

    event.listen("modem_message", self.recive_thread_function) -- starts listening for messages
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
    event.ignore("modem_message", self.recive_thread_function) -- stops listening for messages
    self.modem.close(self.localPort)
    self.localPort = nil
    self.isOpen = false
    self.state = "CLOSED"
    self.receiveData = {} -- clears the receive data queue
end

function Socket:_createPacket(data)
    local packet = {
        protocol = self.protocol,
        returnPort = self.localPort,
        data = data,
    }
    return packet
end

function Socket:SendRaw(packet, address, port)
    self.modem.send(address, port, serialization.serialize(packet))
end

function Socket:recive_thread_function(_, targetAddress, senderAddress, port, distance, message) -- the function for the on event stuff

    if targetAddress ~= self.localAddress then
        return
    end

    if port == SocketProtocols.ARP_Port then
        self:On_arp(senderAddress, port, message)
        return
    end

    if port ~= self.localPort then
        return
    end

    if self.protocol == TCP then
        self:On_tcpReceive(senderAddress, port, message)
    
    elseif self.protocol == UDP then
        self:On_udpReceive(senderAddress, port, message)
    end

end

function Socket:On_tcpReceive(sender, remotePort, packet) -- when a TCP packet is received
    --TODO
end
    
function Socket:On_udpReceive(sender, remotePort, packet) -- when a UDP packet is received
    --TODO
end

function Socket:On_arp(sender, remotePort, packet) -- when an ARP request is received
    if packet == SocketProtocols.ARP_REQUEST and self.enableArpAdvert then -- if the packet is an ARP request
        local response = self:_createPacket(self.name)
        self:SendRaw(response, sender, remotePort)
        return
    end
    if pcall(serialization.unserialize, packet) then -- if the packet is a response
        self:on_arpResponse(sender, packet)
        return
    end

end

function Socket:on_arpResponse(sender, data) -- when an ARP response is received
    local data = serialization.unserialize(data)
    local device = {
        address = sender,
        port = data.returnPort,
        protocol = data.protocol,
        name = data.data,
    }

    self.arpTimeout = computer.uptime() + self.arpTimeoutTotal

    for i, v in ipairs(self.arpTable) do
        if v.address == device.address and v.port == device.port then
            self.arpTable[i] = device
        else
            table.insert(self.arpTable, device)
        end
    end
end

function Socket:getAllDevices(timeoutStart)
    -- sends ARP request, waits until ARP timeout, takes all devices
    -- the event that its looking for extends the timeout timer each time it gets a response, sets to ARP timeout
    -- returns a table of devices

    self.arpTable = {} -- clears the ARP table
    self.modem.broadcast(SocketProtocols.ARP_Port, SocketProtocols.ARP_REQUEST) -- sends an ARP request

    self.arpTimeout = computer.uptime() + timeoutStart
    while computer.uptime() < self.arpTimeout do
        os.sleep(0.1)
    end

    return self.arpTable
end