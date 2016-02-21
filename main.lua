-- main program for battle snakes

local Snake = require("Snake") -- include the helper classes for the board and snake
local socket = require("socket") -- needed to communicate to the bots bidirectionally

-- wrapper to prevent failing if requires fails
local function prequire(m) 
  local ok, err = pcall(require, m) 
  if not ok then return nil, err end
  return err
end

local winapi = prequire("winapi")

-- A bunch of helper functions

-- Common Colors
RED = {255,0,0}
GREEN = {0,255,0}
BLUE = {0,0,255}
YELLOW = {255,255,0}
WHITE = {255,255,255}
BLACK = {0,0,0}

local dtotal = 0
local function colorCvrt(tbl)
	return tbl[1], tbl[2], tbl[3]
end

local function drawRect(x, y)
	-- convert for 1-based grid
	love.graphics.rectangle("fill", (x - 1) * size, (y - 1) * size, size, size)
end

local function drawCircle(x, y)
	love.graphics.circle("fill", (x - 0.5) * size, (y - 0.5) * size, size/2, 100)
end

local function printText(msg, x, y)
	love.graphics.print(msg, x, y)
end

local function setColor(colorTbl)
	love.graphics.setColor(colorCvrt(colorTbl))
end

local function drawPellet()	
	setColor(config.pelletColor)
	drawCircle(board:GetPelletLocation())	
end

local function drawSnake(snake)			
	if snake.isDead then
		setColor(RED)
	else
		setColor(snake.color)	
	end
	
	for pos in snake:Iter() do
		drawRect(pos.x, pos.y)	
	end
end

local function drawSnakes()		
	local snakes = config.perserveDead and allSnakes or activeSnakes
	
	for _,snake in pairs(snakes) do
		drawSnake(snake)
	end	
end

local function clearBoard()
	love.graphics.clear(colorCvrt(config.bgColor))
end

local function printInfo()	
	setColor(config.infoColor)	
	printText(string.format("Ticks: %d", board.ticks))
	
	local offset = 20
	
	for i,snake in ipairs(allSnakes) do
		
		local str = string.format("[%s] ID: %d P: %d L: %d W: %d", 
			snake.name, 
			snake.id,
			snake:GetPelletsEaten(),
			snake:GetLength(),
			match:GetWins(snake)
		)
		
		if snake.isDead then
			setColor(RED)
			str = str .. " [DEAD]"
		else
			setColor(snake.color)		
		end
			
		printText(str, 0, offset)		
		offset = offset + 15		
	end
end

-- send a command to a specific snake
local function sendCmd(snake, cmd)
	snake.client:send(cmd.."\n")
end

local function recieveCmd(snake)	
	local cmd = snake.client:receive(1)
	--print("received: "..cmd)
	-- might log here
	return cmd
end

-- send a command to all snakes
local function broadCast(cmd)
	for snake in pairs(activeSnakes) do
		if not snake.isHuman then
			sendCmd(snake, cmd)
		end
	end
end

local function updateSnakes()
	for snake in pairs(activeSnakes) do
		if not snake.isHuman then
			sendCmd(snake, "mov") -- tell the prgm to send a response
			local resp = recieveCmd(snake) -- receive that response, or timeout		
			if resp then
				snake:UpdateMovement(resp)
			end
		end
	end		
end

local function broadCastPellet()
	broadCast(string.format("p %d,%d",board.pelletLocation.x,board.pelletLocation.y))
end

local function broadCastStarting()
	broadCastPellet()
	
	for snake in pairs(activeSnakes) do
		for pos in snake:Iter() do
			local str = string.format("si %d %d,%d",snake.id,pos.x,pos.y)
			broadCast(str)
		end
	end
	
	-- let all the snakes know the game is ready to start
	broadCast("ready")
end

local function informSnakes()
	for snake in pairs(activeSnakes) do
		local head, oldtail = snake:GetDeltaLocation()
		local x,y,nx,ny = head.x,head.y,oldtail.x,oldtail.y
		local str = string.format("s %d %d,%d,%d,%d",snake.id,x,y,nx,ny)
		broadCast(str)
	end
end

local function endConnections()
	-- close all the clients
	for _,client in ipairs(clients) do
		client:close()		
	end
end

local function drawEnd()
	-- highlight the collision box
	setColor({255, 0, 0})
	--drawRect(endConditions.x,endConditions.y)
	
	printText("Game Over!", 0,0)
end

local function endMatch()			
	-- write the match results out to a file
	if config.perserveResults then
		match:WriteResults(config.resultsFile, config.perserveMode)
	end
	
	-- let love know we should end now
	love.event.quit()
end

-- update the human snakes with the approriate key mapping
local function updateHumanInput(key)
	for snake in pairs(activeSnakes) do
		if snake.isHuman then
			local cmd = snake.keyMapping[key]
			if cmd then
				snake:UpdateMovement(cmd)
			end
		end
	end
end

local function startGame(gameNumber)	
	currentGameNumber = gameNumber
	
	-- Update the title
	love.window.setTitle(string.format("Battle Snakes: Round %d", currentGameNumber))	
	
	-- start recording the match
	match:StartGame(gameNumber)
	
	-- create a new board
	board = Snake.NewBoard(height, width, config.perserveDead)
	
	-- Add a starting pellet
	if config.randStartPellet then
		board:AddNewPellet()
	else
		board:AddNewPellet(width/2,height/2)
	end
	
	-- all the snakes
	allSnakes = {}
		
	-- init each snake
	for i,name in ipairs(config.snakes) do
		-- make sure it is configured
		local bot = assert(config.bots[name], "Couldn't find configured bot "..name..". Check config.lua file")
			
		-- create the snake
		local snake = Snake.NewSnake(name, i, config.growth, config.initialLen, bot.color)
		
		if bot.isHuman then
			-- if the snake is a human player, load the key mappings
			snake.isHuman = true
			snake.keyMapping = bot.keyMapping
			isHuman = true
		else		
			-- the commanding program
			snake.cmd = bot.cmd
		end
		
		-- add the snake to the game board
		board:AddSnake(snake)				
		
		-- keep track of each snake added
		allSnakes[i] = snake
	end
	
	-- for brevity, active snakes
	activeSnakes = board.snakes
	
	-- keep track of clients 
	clients = {}
					
	-- start the non-human snakes
	for i,snake in ipairs(allSnakes) do		
		if not snake.isHuman then		
			
			local startCmd = string.format("%s %s %s %d", snake.cmd, ip, port, i)
			
			-- start the bot, passing in the ip and port so it can connect			
			if winapi then			
				-- if winapi is available, use the spawn_process to prevent background
				-- tasks from popping up
				snake.process = winapi.spawn_process(startCmd)
			else
				-- otherwise, just do a popen
				snake.process = io.popen(startCmd, "w")
			end
			
			-- wait for the spawn process to connect to the server
			local client = assert(server:accept(), "Bot connection timeout! "..snake.name.." didn't connect in time")
			client:settimeout(config.clientTimeout)
				
			-- associate the accepted client with the snake
			snake.client = client
			
			clients[#clients + 1] = client
		end
	end
		
	-- inform all the snakes of the starting conditions
	broadCastStarting()
	
	-- give the human player time to set up
	if isHuman then
		love.timer.sleep(1)
	end
	
	-- reset timer
	dtotal = 0
	
	ticksSinceLastPelletEaten = 0
	
	-- this informs the updater to start working
	gameOver = false
end

local function endGame(snakesAlive)
	-- inform the updater that the game is over
	gameOver = true
			
	-- kill connections to bots
	endConnections()
		
	-- update the match with the game results
	local gameEnded = match:EndGame(currentGameNumber, board, snakesAlive)
	
	-- Did this game result decide the match?
	if match:IsThereAWinner() then		
		return endMatch()
	end
	
	-- Start the next game of the match
	startGame(currentGameNumber + 1)
end

local function updateBoard() 
	-- update the board
	local pelletEaten = board:UpdateTick()

	-- check endgame conditions
	local snakesAlive = board:SnakesLeft()
	
	if #snakesAlive == 0 then		
		return endGame(snakesAlive) -- no one is alive!
	elseif #snakesAlive == 1 and not isSinglePlayer then
		return endGame(snakesAlive) -- last man surviving [multiplayer mode]
	end
	
	if pelletEaten then
		-- let the snakes know the new location
		broadCastPellet()			
	else
		ticksSinceLastPelletEaten = ticksSinceLastPelletEaten + 1
	end

	-- prevent infinte loops
	if ticksSinceLastPelletEaten >= config.tickTimeout then
		return endGame()
	end
end

--------------------
-- LOVE CALLBACKS --
--------------------

--- Draw the game
function love.draw()
	clearBoard()
	drawPellet()
	drawSnakes()
	if config.showInfo then
		printInfo()
	end
	
	if gameOver then
		drawEnd()		
	end
end

-- Update the game
function love.update(dt)
	if gameOver then return end
	
	-- only update the game at the correct frequency
	dtotal = dtotal + dt
	if dtotal < updateTime then return end
	
	updateSnakes()
	updateBoard()
	informSnakes()
	
	dtotal = 0 -- reset timer
end

function love.quit()
	-- close the server connection
	if server then
		server:close()
	end
	
	-- make sure any connections that are alive are killed
	endConnections()
end

function love.keypressed(key)
	updateHumanInput(key)
end

-- main entry point for Love2d
function love.load()
	-- for debugging in ZeroBrane Studio
	if arg[#arg] == "-debug" then require("mobdebug").start() end

	-- load the config settings
	config = require("config")
	
	-- convert update frequency to a time (s)
	updateTime = 1 / config.updateFreq   
	
	-- just for brevity, save as simplier name
	size = config.pixelSize
	height = config.height
	width = config.width
	
	-- init some defaults
	config.initialLen = config.initialLen or 5
	config.growth = config.growth or 3
		
	-- init the RNG
	seed = config.seed or os.time()
	math.randomseed(seed)
	
	-- create a server to host the game
	server = assert(socket.bind(config.host, config.port))
	server:settimeout(config.serverTimeout)
	
	-- get the actual ip and port to which the server is bound to
	ip,port = server:getsockname()
	
	-- love config	
	love.window.setMode(size*width,size*height)
	love.graphics.setBackgroundColor(colorCvrt(config.bgColor))
	
	-- single-player vs multi-player
	numOfSnakes = #config.snakes	
	isSinglePlayer = numOfSnakes == 1
	
	-- create the match
	match = Snake.NewMatch(config.bestOf, seed, config.snakes)
	
	-- Start the first game of the match
	startGame(1)
end