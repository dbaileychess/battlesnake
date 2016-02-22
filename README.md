Introduction
============

The classic snake game where bots control the snakes. Can you create a bot that out lives the rest?

Snakes will enter the arena and hope to survive. Eat pellets and grow in length. Can you force your competition to crash and die while your survive? 

See [video](https://www.youtube.com/watch?v=ZQKWIM83Yd8) for visuals.

Features
========
* Real-time graphics provided by [Love2D](https://love2d.org/)
* Multiple snakes per game
* Humans can play too!
* Highly configurable settings
* Supports any programming language that can use sockets.

Requirements
============
* [Love2D](https://love2d.org/): 2D game engine written for Lua
* Socket-compatible programming language
* [Controller](https://github.com/dbaileychess/battlesnake): The main controller for this challenege

Optional
--------

* [Lua winapi](https://github.com/stevedonovan/winapi): Handy way to spawn processes in the background

Controller Contents
========
1. `main.lua`: Main loop for Love.
2. `snake.lua`: Support library for game mechanics
3. `config.lua`: Configuration settings.
4. `bots\`: location of externally-defined bots
	1. `simple.lua`: Example bot written in Lua
		
Executing
=======
Run the love2d executable on the controller directory

`love.exe <location_of>\battlesnake`

or

[Recommended] Use [ZeroBrane Studio](https://studio.zerobrane.com/) with the 'Love' interpreter. You'll still have to install Love separately.

Configuration
=============

All configurable options are located in the `config.lua` file in the controller. The options are detailed in that file itself.

Mechanics
=========

The game is ran as a server-client model, where the main loop is the server and each snake is a client. The game communicates to each snake over TCP through an assigned port. 

When the game starts, it will start each snake (aka bot) by starting its associated program and sending the IP ADDRESS and PORT and PLAYER ID to it as input arguments: 

`bots\someBot.exe 127.0.0.1 52311 1`

The main server then waits for a socket connection from that bot at the given IP and PORT. If the connection times out, it will error and the game will not start. If the server receives a connection from the bot, it will proceed on to the next bot.

Once all bots are started and connected to the server, the game will be generated. Bots are expected to block until receiving data from the server. Typically this is just an infinite loop with a blocking ```socket.receive()``` call at the top of the loop.

Board
-----

The game board can be of any width and height. The coordinate system starts at `x = 1`, `y = 1` at the top-left. Increasing `x` values go left-to-right and increasing `y` values go top-to-bottom. The board has hard walls, hitting them will kill your snake.

Order of Events
---------------

1. First the game settings are broadcast to all bots

	1. Board Information
		
		`bi width,height`
		
		Where `width` and `height` are integer values 
	
	2. Pellet Location
	
		`p x,y`
	
		Where `x` and `y` are integer values `>= 1` and `<=` to their respective `width` and `height`.
	
	3. For each bot
	
		* For each body part, starting at the head and going to the tail
		
			`si snake_id x,y`
			
			Where `snake_id` is an integer value, and `x` and `y` are as described before.
		
	4. Ready signal
	
		`ready`
		
		All bots are initialized by now, so the next command will be from the main game loop.
		
2. Main Loop

	1. For each tick (tick is when all snake movements will be applied)
	
		1. Server will broadcast to each bot
		
			`mov`
			
			The bot needs to respond to this request with a direction to head in
			
			* `r` Head Right
			* `l` Head Left
			* `u` Head Up
			* `d` Head Down
			
			If the bot doesn't respond within a specified time, it will continue to move in its previous direction. (Previous direction is `r` on the first turn)
			
			The bot should send a single char back, nothing more will be parsed.
			
		2. Updated Pellet Info [optional]
		
			If a pellet was eaten this tick, a new pellet packet will be broadcast to all active bots
			
			`p x,y`
			
		3. End Game Condition [optional]
		
			If the game ended this tick. Each bot will be sent either a `quit` or nil msg from the server. Each bot is expected to clean itself.
		
		4.	Server broadcasts snake deltas that were applied this turn
		
			`s snake_id new_x,new_y,removed_x,removed_y`
			
			Where all parameters are integers. `new_x` and `new_y` are the new head location of a given snake.
			
			If `removed_x` and `removed_y` are `>= 1`, this is where the tail **used** to be, so each bot knows the updated board.
			
			If `remove_x` and `removed_y` are `== -1`, then that bot is actively growing in size, so its tail didn't move.
			
			If a snake died this tick, its deltas will not be broadcast. It is up to the bots to remove the body from their game state.
			
			
Matches
=======

Games are grouped together in best-of matches. For the purposes of the bots, they do not need to understand the concept of a match. The bot that wins the required number of games in a match is declared the match winner.

Scoring
=======

1. Scoring

	* Match winner: +2500 points
	* Last Man Standing: +1000 points
	* Pellets Eaten: +50 points per pellet
	* Game Ticks Alive: +1 point per tick
	
	
	If two or more bots enter the same square on the same square. They all die. If this square happened to be the pellet, none of those bots will be rewarded the points. However, the pellet will be "consumed" and a new location will be generated.
	
	If there is a tie at the end of the game among the bots, the game is a wash. A new game will be started.
	
2. King-of-the-hill Scoring		

	This challenege will combine two parts: A solo effort and a classic king-of-the-hill part.
	
	Each bot will be given the same random seed at the start of the competition. There will also be imposed a maximum time between eating pellets to prevent bots from going around in circles to farm points.
	
	1. Solo
	
		Each bot will enter into a 10-game match to see how long it lasts and how well it eats by itself. The scores of each game in the match will be summed to compose its final Solo-score.
		
	2. King-of-the-hill
	
		All the bots will enter into a best-of-39 match. If the game ends and there is still a final living bot, the game still end at that point. That bot will be given the last man standing bonus.
		
		The scores of each game will be summed and composed into the snakes final KOTH-score.
	
	3. Final Scoring
	
		All the bots will be ranked in each part separately. Ties in ranks are permitted at this stage. Then their positional rank in each part will be summed together to give their final score. The bot with the lowest combined rank wins!
	
		In case of a tie at this level, the bot with the better KOTH rank will win. If still a tie, the bot with the better Solo rank will win.
