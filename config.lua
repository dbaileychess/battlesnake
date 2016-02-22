return {
	
	-- match settings	
	bestOf = 			30,						-- number of games to decide winner (RNG is initiated once at the beginning)
	snakes = {									-- list of snakes to play with. Entries must exist in the 'bots' section below 
		--"human",								
		"simpleBot",	
		"simpleBot",
		"simpleBot",
	},
			
	-- board settings
	width = 			60,						-- board width in pixels
	height = 			60,						-- board height in pixels
	
	-- snake settings
	initialLen =		5,						-- how many pixels the snakes start with
	growth =			3,						-- how many pixels a snake grows each time it eats a pellet
	
	-- game settings
	seed =				nil,					-- RNG seed as integer, if nil it will default to the current time
	randStartPellet = 	true,					-- randomize the starting pellet; if false, will place in center of board
	tickTimeout =		5000,					-- end the game if no pellets are eaten within this number of ticks
	updateFreq =		15,						-- (Hz) how often each snake will move.
	port =				0,						-- Port number to open, 0 = ephemeral
	host = 				"localhost",			-- hostname, usually just localhost
	serverTimeout = 	5,						-- (s) how long the server will wait to communicate to the bots
	clientTimeout = 	3,						-- (s) how long the bot client will wait to communicate with the server
	perserveResults = 	true,					-- write the results of a match to a file
	perserveMode	=	"w",					-- "w" write over | "a" append
	resultsFile	=		"bs_results.txt",		-- path of the results file
	
	-- score settings
	matchWinner	=		2500,					-- points given to snake that wins the most games of the match
	lastManStanding = 	1000,					-- points given to the last snake alive in multiplayer games
	pelletPoints = 		50,						-- points given for each pellet eaten
	tickPoints = 		1,						-- points given for each tick the snake is alive
		
	-- experimental settings
	perserveDead =		false,					-- if a snake dies, perserve its body on the board (turns it red)
				
	-- visual settings	
	pixelSize = 		10,						-- size of displayed pixel
	pelletColor =		BLUE,					-- color of the pellet
	bgColor = 			BLACK,					-- background color
	showInfo =			true,					-- display info stats on gameboard during execution
	infoColor = 		YELLOW,					-- color of the info text (snakes will be colored their color)
	
	-- bot settings
	bots = {									-- the configured bots					
				
		human = {								-- support human players
			isHuman = true,
			color = {200, 200, 200},
			keyMapping = {						-- map input keys to directions (i.e. arrow vs wasd)
				up = "u",
				down = "d",
				right = "r",
				left = "l"
			}
		},
				
		-- example bot
		simpleBot = {			
			cmd = "lua52 bots/simple.lua",		-- the program to run to control the snake (will spawn separate process)
			color = {161, 255, 65},				-- the color of the snake			
		},
	
		-- add your bots here following the above format		
	}
	
	-- notes	
	-- color is defined as a Lua table { r, g, b}
}