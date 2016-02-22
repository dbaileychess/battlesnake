local m = {}

local rand = math.random

local pellet = {}
local board = {}

function board.New(width, height, perserveDead)
	width = width or 40
	height = height or 40
	
	local o = {}
	setmetatable(o, {__index = board})
	o.width = width
	o.height = height
	o.liveSnakes = {}
	o.deadSnakes = {}
	o.perserveDead = perserveDead
	o.ticks = 0
	o.pelletsEaten = 0
	o.allSnakes = {}
	
	-- init board	
	for i = 1, width do
		o[i] = {}
	end
	
	return o
end

function board:IsValid(x, y)
	return x and y and x > 0 and x <= self.width and y > 0 and y <= self.height
end

function board:IsEmpty(x, y)
	return self:IsValid(x, y) and self[x][y] == nil
end

function board:IsPellet(x, y)
	return self:IsValid(x, y) and self[x][y] == pellet
end

function board:SetPellet(x, y)
	assert(self:IsEmpty(x, y), "Shouldn't place a pellet where something else is")	
	self:SetSpot(x,y, pellet)
	self.pelletLocation = {x = x, y = y}
end

--- Add a new pellet to the board
function board:AddNewPellet(x,y)	
	while not self:IsEmpty(x,y) do	
		x,y = rand(width),rand(height)
	end
	self:SetPellet(x, y)
end

function board:ClearSpot(x, y)
	self[x][y] = nil
end

function board:SetSpot(x, y, item)
	self[x][y] = item	
end

local function generateSnakeBody(x, y, length)
	local head = { x = x, y = y }
	
	local tail = head
	for i = 1, length do
		local oldTail = tail
		tail = { x = x, y = y + i, fwd = oldTail}
		oldTail.bck = tail
	end

	return head, tail
end

function board:AddSnake(snake)
	-- get a start position for the snake
	local x,y = self:GetStartLocation(snake.initialLength)
	
	snake.head,snake.tail = generateSnakeBody(x, y, snake.initialLength)	
	
	for pos in snake:Iter() do
		self:SetSpot(pos.x, pos.y, snake)
	end
	
	-- save the snake
	self.liveSnakes[snake] = snake	
	self.allSnakes[snake.id] = snake
end

function board:SnakesLeft()
	local tbl = {}
	for snake,_ in pairs(self.liveSnakes) do
		tbl[#tbl+1] = snake
	end
	return tbl
end

-- main game mechanics for a turn
function board:UpdateTick()	
	self.ticks = self.ticks + 1
	self.removedThisTick = {}
	local collidingSnakes = {}
	local updates = {}
	
	-- get the next move for each snake
	for _,snake in pairs(self.liveSnakes) do				
		local direction = assert(snake:GetMovement(), "Didn't get valid movement from snake!")
		local x,y = snake:Move(direction)
		
		-- check for collisions of each snake moving into the same position at the same time
		for otherSnake,location in pairs(updates) do
			if location.x == x and location.y == y then
				collidingSnakes[snake] = {x=x, y=y}
				collidingSnakes[otherSnake] = {x=x, y=y}
			end
		end
		
		updates[snake] = {x = x, y = y}		
	end		
	
	local pelletEaten = false
	
	-- now we apply each movement per snake that didn't collide
	for snake,location in pairs(updates) do
		
		-- skip colliding snakes
		-- we will handle below
		if collidingSnakes[snake] then
			goto continue
		end
		
		local x,y = location.x, location.y
		
		if self:IsPellet(x,y) then
			self.pelletsEaten = self.pelletsEaten + 1 
			snake:Eat() -- reward the snake!						
			pelletEaten = true
		elseif not self:IsEmpty(x,y) then				
			self:RemoveSnake(snake) -- kill the snake!
			goto continue
		end
		
		-- update the board with the new information
		-- this effectively removes the pellet as well
		self:SetSpot(x,y,snake)
		
		-- tell the snake to grow
		local tx,ty = snake:Grow(x,y)
		
		-- update the board with removing the tail
		if tx and ty then
			self:ClearSpot(tx, ty)
		end
		
		::continue::
	end
	
	-- handle any colliding snakes (same spot same turn)
	for snake, location in pairs(collidingSnakes) do
		local x,y = location.x, location.y
		if self:IsPellet(x,y) then													
			self:ClearSpot(x,y)
			pelletEaten = true -- still get rid of the pellet
		end
		self:RemoveSnake(snake)
	end
			
	-- generate a new pellet location
	-- and inform the snakes
	if pelletEaten then
		self:AddNewPellet()		
		return true
	end
	
	-- no pellet eaten
	return false
end

function board:GetStartLocation(initialLen)
	local x,y
	repeat
		x,y = rand(width),rand(height)
	until self:IsEmpty(x,y)	
	return x,y
end

function board:GetPelletLocation()
	return self.pelletLocation.x, self.pelletLocation.y
end

function board:RemoveSnake(snake)
	self.removedThisTick[#self.removedThisTick+1] = snake
	
	snake.isDead = true
	snake.ticks = self.ticks
	
	-- remove the snake from the list of active snakes
	self.liveSnakes[snake] = nil
	
	-- add to the list of dead snakes (for scoring)
	self.deadSnakes[#self.deadSnakes + 1] = snake
	
	-- [experimental] don't remove the dead snakes
	if self.perserveDead then
		return
	end
	
	for pos in snake:Iter() do
		self:ClearSpot(pos.x, pos.y)
	end
end

local snake = {}

function snake.New(name, id, growth, initialLength, color)
	local o = {}
	setmetatable(o, {__index = snake})
	o.name = name
	o.id = id
	o.length = length
	o.growth = growth
	o.growingCount = 0
	o.pelletsEaten = 0
	o.currentMovement = "r"
	o.color = color
	o.initialLength = initialLength or 3
	return o
end

function snake:Move(key)
	local x, y = self.head.x, self.head.y
	if key == "u" then
		y = y - 1
	elseif key == "d" then
		y = y + 1
	elseif key == "r" then
		x = x + 1 
	elseif key == "l" then
		x = x - 1	
	end
	return x, y
end

function snake:Eat()
	self.growingCount = self.growingCount + self.growth
	self.pelletsEaten = self.pelletsEaten + 1
end

function snake:Grow(x, y)		
	-- add the new head
	local oldHead = self.head
	local newHead = {x = x, y = y, bck = oldHead} 	
	oldHead.fwd = newHead		
	self.head = newHead

	-- Is this snake actively growing in size?
	if self.growingCount > 0 then
		-- growing, so don't remove the tail
		self.growingCount = self.growingCount - 1
		self.removedLoc = nil -- indicate that we didn't remove the tail this step
		return nil
	else
		-- not growing, so remove the tail
		self.removedLoc = self.tail
		
		local newTail = assert(self.tail.fwd, "We should always have a new tail")
		newTail.bck = nil
		local x,y = self.tail.x, self.tail.y
		self.tail = newTail		
		return x,y
	end	
end

-- iterate from head to tail
function snake:Iter()
	local pos = self.head
	return function()		
		if not pos then return nil end
		local cpos = pos
		pos = pos.bck
		return cpos			
	end
end

function snake:GetDeltaLocation()
	return self.head, self.removedLoc or {x = -1,y = -1}
end

function snake:GetPelletsEaten()
	return self.pelletsEaten
end

function snake:GetLength()
	local len = 0
	for pos in self:Iter() do
		len = len + 1
	end
	return len
end

function snake:GetHead()
	return self.head
end

function snake:GetTail()
	return self.tail
end

function snake:GetMovement()
	return self.currentMovement
end

function snake:UpdateMovement(dir)
	self.currentMovement = dir
end

local match = {}

function match.New(bestOf, seed, snakes, matchpoints, lmspoints, ppoints, tpoints) 
	local o = {}
	setmetatable(o, {__index = match})
	o.bestOf = bestOf or 1	
	o.seed = seed
	o.toWin = math.ceil(o.bestOf / 2)
	o.games = {}
	o.snakeWins = {}
	o.snakes = snakes
	o.matchPoints = matchpoints
	o.lastManStandingPoints = lmspoints
	o.pelletPoints = ppoints
	o.tickPoints = tpoints
	return o;
end

function match:StartGame(gameNumber)
	-- create the game table
	self.games[gameNumber] = {}
end

function match:EndGame(gameNumber, board, aliveSnakes)		
	-- check for timeout (aliveSnakes should be set to nil)
	if not aliveSnakes then		
		return false
	end	
		
	local lastSnakeLiving
	local singlePlayer
		
	-- multiple snakes died this turn, check for tie condition
	if #board.removedThisTick > 1 then
		
		-- check for most pellets
		local tiedForMost = true
		local mostPellets = -1		
		for i, snake in ipairs(board.removedThisTick) do
			local p = snake:GetPelletsEaten()
			if p > mostPellets then
				lastSnakeLiving = snake
				mostPellets = p
				tiedForMost = false
			elseif p == mostPellets then
				tiedForMost = true
			end
		end
	
		-- multiple snakes that died this turn shared the same number of pellets eaten.
		-- so it is a tie, signal to restart the round
		if tiedForMost then
			return false
		end	
	elseif #aliveSnakes == 1 then
		lastSnakeLiving = aliveSnakes[1] -- get the sole survivor
	else
		singlePlayer = true
		lastSnakeLiving = board.deadSnakes[1] -- get the sole dead person, for single player
	end
	
	-- sanity check
--	if not lastSnakeLiving then
--		return false		
--	end
	
	local gameTbl = self.games[gameNumber]	
	
	-- calculate the scores per snake
	local maxScore = -1
	local winningSnake = lastSnakeLiving
	gameTbl.scores = {}	
	for id,snakeName in ipairs(self.snakes) do
		local snake = board.allSnakes[id]
		
		local score = 0
		
		-- last man standing is for multiple player only
		if not singlePlayer and lastSnakeLiving.id == id then
			score = score + self.lastManStandingPoints
		end
		
		score = score + snake:GetPelletsEaten() * self.pelletPoints
		score = score + (snake.ticks or board.ticks) * self.tickPoints		
		
		-- save score
		gameTbl.scores[id] = score
		
		-- find max score
		if score > maxScore then
			maxScore = score
			winningSnake = snake
		end
	end
	
	gameTbl.winnerID = winningSnake.id
	gameTbl.winnerPellets = winningSnake:GetPelletsEaten()
	gameTbl.ticks = board.ticks
	gameTbl.totalPellets = board.pelletsEaten
		
	-- record the win
	self.snakeWins[winningSnake.id] = (self.snakeWins[winningSnake.id] or 0 )+ 1	
	
	-- some snake won, so return true
	return true
end

function match:IsThereAWinner()
	-- todo figure this out for multiplayer
	for snake,i in pairs(self.snakeWins) do
		if i >= self.toWin then
			return true, snake, i
		end
	end
	return false
end

function match:WriteResults(filePath, mode)
	local f = assert(io.open(filePath, mode))
	
	-- Sum scores
	local totalScores = {}		
	for id,snake in ipairs(self.snakes) do
		local score = 0
		for _,game in ipairs(self.games) do
			score = score + (game.scores and game.scores[id] or 0)
		end
		totalScores[id] = score
--		f:write(string.format(" Snake %s ID: %d Score: %d\n",
--			self.snakes[id],
--			id,
--			score))
	end
	
	-- find the match winner and give them the match points
	local _,winningSnakeID,wins = self:IsThereAWinner()	
	totalScores[winningSnakeID] = totalScores[winningSnakeID] + self.matchPoints
	
	-- now find the overall winner
	table.sort(totalScores, function(a,b) return a > b end)
		
	f:write("==Match Settings==\n")
	f:write(" Best Of "..self.bestOf.."\n")
	f:write(" Seed "..self.seed.."\n")
	
	f:write("==Snake Scores==\n")
	local rank = 1
	for id,score in pairs(totalScores) do
		f:write(string.format("#%d: %s [%d] Score: %d\n",
			rank,
			self.snakes[id],
			id,
			score))
		rank = rank + 1
	end
	
	
--	f:write(string.format(" Snake %s ID: %d Won with %d wins!\n",
--			self.snakes[winningSnakeID],
--			winningSnakeID,
--			wins))
		
	f:write("==By Round==\n")
	for i,gameRes in ipairs(self.games) do
		
		if not gameRes.winnerID then
			f:write(string.format(" Round: %d Tie!\n", i))
		else		
			f:write(string.format(" Round: %d Winner: %s ID: %d Pellets: %d Total Ticks: %d\n", 
				i, 				
				self.snakes[gameRes.winnerID], 
				gameRes.winnerID,
				gameRes.winnerPellets,
				gameRes.ticks))
		end
	end  
    f:close()	
end

function match:GetWins(snake)
	return self.snakeWins[snake.id] or 0 
end

-- public methods
m.NewSnake = snake.New
m.NewBoard = board.New
m.NewMatch = match.New
return m
