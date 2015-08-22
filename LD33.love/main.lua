require "vectors"

local world

local leftWall, you, shore, youJoint
local boats = {}

local elapsedTime = 0

local score = 0
local lastScore = 0
local scoreChangedTime = -1

local targetPosition = nil

local backgroundImage

local playing = false
local gameOver = false

WALL_THICKNESS = 40
SHORE_WIDTH = 220
BOAT_CATEGORY = 3
STARTING_POSITION = v(0, 0) -- calculated below from window dimensions
YOU_SPEED = 400
YOU_MINIMUM_SPEED = 120
YOU_RADIUS = 24

local function contactBegan(fixture1, fixture2, contact)
	if either(shore.fixture, fixture1, fixture2) then
		-- boat got to shore!
	end
	-- note: don’t remove objects in physics callback
end

function love.load()
	love.graphics.setLineStyle("smooth")
	math.randomseed(os.time())

	backgroundImage = love.graphics.newImage("graphics/background.png")

	-- fonts

	scoreBigFont = love.graphics.newFont(30)
	scoreLittleFont = love.graphics.newFont(20)

	-- physics

	local w, h = love.window.getDimensions()

	STARTING_POSITION = v(w / 2, h * 0.8)

	world = love.physics.newWorld()
	world:setCallbacks(contactBegan, nil, nil, nil)

	leftWall = {}
	leftWall.shape = love.physics.newRectangleShape(WALL_THICKNESS, h * 1.5)
	leftWall.body = love.physics.newBody(world, WALL_THICKNESS / 2, h / 2)
	leftWall.fixture = love.physics.newFixture(leftWall.body, leftWall.shape)
	leftWall.fixture:setCategory(BOAT_CATEGORY)
	leftWall.fixture:setRestitution(1)

	local rightWall = {}
	rightWall.shape = love.physics.newRectangleShape(WALL_THICKNESS, h * 1.5)
	rightWall.body = love.physics.newBody(world, w - SHORE_WIDTH + WALL_THICKNESS / 2, h / 2)
	rightWall.fixture = love.physics.newFixture(rightWall.body, rightWall.shape)
	rightWall.fixture:setCategory(BOAT_CATEGORY)
	rightWall.fixture:setRestitution(1)

	local floor = {}
	floor.shape = love.physics.newRectangleShape(w, WALL_THICKNESS)
	floor.body = love.physics.newBody(world, w / 2, h - WALL_THICKNESS / 2)
	floor.fixture = love.physics.newFixture(floor.body, floor.shape)
	floor.fixture:setRestitution(0)

	local ceiling = {}
	ceiling.shape = love.physics.newRectangleShape(w, WALL_THICKNESS)
	ceiling.body = love.physics.newBody(world, w / 2, WALL_THICKNESS / 2)
	ceiling.fixture = love.physics.newFixture(ceiling.body, ceiling.shape)
	ceiling.fixture:setRestitution(1)

	you = {}
	you.shape = love.physics.newCircleShape(30)
	you.body = love.physics.newBody(world, 0, 0, "dynamic") -- 0,0 for now — reset() is responsible for the actual starting position
	you.fixture = love.physics.newFixture(you.body, you.shape)
	you.fixture:setRestitution(0.9)

	youJoint = love.physics.newMouseJoint(you.body, 0, 0)

	shore = {}
	shore.shape = love.physics.newRectangleShape(SHORE_WIDTH - WALL_THICKNESS / 2, h)
	shore.body = love.physics.newBody(world, w - SHORE_WIDTH / 2 + WALL_THICKNESS / 2, h / 2)
	shore.fixture = love.physics.newFixture(shore.body, shore.shape)
	shore.fixture:setSensor(true)

	-- get gameplay stuff ready

	boats[#boats + 1] = makeBoat(200, 100)

	reset()
end

function love.draw()
	love.graphics.setColor(255, 255, 255, 255)
	local w, h = love.window.getDimensions()

	if playing then
		love.graphics.draw(backgroundImage, 0, 0)

		love.graphics.setColor(0, 0, 0, 255)
		-- player
		-- ships
		-- ship labels
		-- score etc.
		love.graphics.circle("fill", you.body:getX(), you.body:getY(), YOU_RADIUS, 40)

		for i = 1, #boats do
			local boat = boats[i]
			love.graphics.push()
			love.graphics.translate(boat.body:getX(), boat.body:getY())
			-- TODO: rotate for tilting, maybe based on the boat’s speed
			love.graphics.rectangle("fill", -24, -15, 48, 30)
			love.graphics.pop()
		end
	else
		-- either title screen or end-game state
		if not gameOver then
			-- title screen
		else
			-- end-game
		end
	end
end

function love.update(dt)
	elapsedTime = elapsedTime + dt

	if playing then
		local currentPositionX, currentPositionY = youJoint:getTarget()
		local currentPosition = v(currentPositionX, currentPositionY)
		local newPosition = currentPosition
		if love.mouse.isDown("l") and targetPosition ~= nil then
			targetPosition = v(love.mouse.getX(), love.mouse.getY())
			local screenWidth, screenHeight = love.window.getDimensions()

			targetPosition.x = math.max(math.min(targetPosition.x, screenWidth - SHORE_WIDTH - YOU_RADIUS), WALL_THICKNESS + YOU_RADIUS)
			targetPosition.y = math.max(math.min(targetPosition.y, screenHeight - WALL_THICKNESS - YOU_RADIUS), WALL_THICKNESS + YOU_RADIUS)

			local towards = vMul(vSub(targetPosition, currentPosition), 2)
			local towardsLength = vLen(towards)
			if towardsLength > YOU_SPEED then
				towards = vMul(towards, YOU_SPEED / towardsLength)
			elseif towardsLength < YOU_MINIMUM_SPEED then
				towards = vMul(towards, YOU_MINIMUM_SPEED / towardsLength)
			end
			newPosition = vAdd(currentPosition, vMul(towards, dt))
		else
			-- TODO: deceleration, using delta between current position and last-frame position as starting velocity
		end
		
		youJoint:setTarget(newPosition.x, newPosition.y)

		world:update(dt)
	end
end

function makeBoat(x, y)
	local boat = {}
	boat.shape = love.physics.newCircleShape(20)
	boat.body = love.physics.newBody(world, x, y, "dynamic")
	boat.fixture = love.physics.newFixture(boat.body, boat.shape)
	boat.fixture:setMask(BOAT_CATEGORY)
	return boat
end

function clearBoats()
	for i = 1, #boats do
		local boat = boats[i]
		boat.fixture:destroy()
		boat.body:destroy()
	end
	boats = {}
end

function reset()
	score = 0

	playing = false
	gameOver = false
	elapsedTime = 0
	
	youJoint:setTarget(STARTING_POSITION.x, STARTING_POSITION.y)
	you.body:setX(STARTING_POSITION.x)
	you.body:setY(STARTING_POSITION.y)
	
	targetPosition = nil
end

function start()
	playing = true
end

function love.mousepressed(x, y, button)
	if not playing then
		if gameOver then
			reset()
		else
			start()
		end
	else
		-- movement is handled in update
	end
end

function love.mousereleased(x, y, button)
	if playing and targetPosition == nil then
		-- update uses this as a signal for whether it should actually set a position while the mouse is down
		targetPosition = STARTING_POSITION
	end
end

-- yes the naming is silly; this doesn't have anything to do with colors. whatever, I don’t feel like typing mixThreeNumberTables
function mixColors(a, b, f)
	return {a[1] + f * (b[1] - a[1]), a[2] + f * (b[2] - a[2]), a[3] + f * (b[3] - a[3])}
end

-- sine-curve interpolation
function slerp(a, b, f)
	f = math.max(math.min(f, 1), 0)

	return a + (b - a) * (1 - math.cos(f * math.pi)) / 2
end

function either(thing, one, two)
	if thing == one or thing == two then return true end
	return false
end

