package.cpath = [[C:\Users\Derek\Downloads\ZeroBraneStudio\bin\clibs52\?.dll]]..package.cpath
local socket = require("socket")

ip,port,myid = ...

print("Started")

local server = assert(socket.connect(ip, port))
print("connected to localhost:",port)

-- The server should send data fairly often, but in case something goes wrong
server:settimeout(3)

local count = 0
local ready = false

local x,y =10,10
local px,py = 0, 0

local function updatePellet(msg)
	px,py = msg:match("p (%d+),(%d+)")
	px,py  = tonumber(px),tonumber(py)	
end

local function updateSnake(msg)
	local id,px,py,nx,ny = msg:match("s (%d+) (%d+),(%d+),(-?%d+),(-?%d+)")
	if id == myid then
		x,y = tonumber(px), tonumber(py)	
	end
end

local function updateStartingInfo(msg)
	-- ignoring for this bot
end

local function sendResponse()
	local cmd = ""
	if x < px then		cmd = "r"
	elseif x > px then	cmd = "l" 
	elseif y < py then	cmd = "d"
	elseif y > py then	cmd = "u"
	end	
	server:send(cmd)
end

while true do
	-- wait for an update from server
	local msg = server:receive()

	if not msg or msg == "quit" then
		break
	elseif msg:find("p ") ~= nil then 
		updatePellet(msg)
	elseif msg:find("s ") ~= nil then 
		updateSnake(msg)
	elseif msg:find("si ") ~= nil then
		updateStartingInfo(msg)
	elseif msg == "ready" then
		ready = true
	elseif msg == "mov" then		
		sendResponse()		
	end	
	
end

server:close()