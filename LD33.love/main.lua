require "vectors"

local world

local leftWall, you, youJoint
local boats = {}

local elapsedTime = 0
local lastBoatTime = 0

local targetPosition = nil

local backgroundImage
local boatImage
local youNormalImage, youGrabbyImage
local heartFullImage, heartEmptyImage
local wavesImage
local labelImages = {}

local playing = false
local gameOver = false

local isGrabbing = false
local grabbedBoats = {}

local youShader
local boatShader -- used to mess with the texture coordinates when sinking

local backgroundMusic

WALL_THICKNESS = 40
SHORE_WIDTH = 220
SIDE_CATEGORY = 3
YOU_CATEGORY = 4
BOAT_CATEGORY = 5
STARTING_POSITION = v(0, 0) -- calculated below from window dimensions
YOU_SPEED = 600
YOU_MINIMUM_SPEED = 200
YOU_GRABBING_SPEED_MULTIPLIER = 0.7
YOU_RADIUS = 18
BOAT_SPEED = 160
BOAT_ACCELERATION = 0.4 -- multiplied by max speed
GRAB_DISTANCE = 60
GRAB_HOLD_DISTANCE = GRAB_DISTANCE * .2
BOAT_RECOVER_SPEED = 10
BOAT_IMPACT_THRESHOLD = 60
BOAT_DAMAGE_INTERVAL = 1
BOAT_MAXIMUM_HEALTH = 3
BOAT_SINK_DURATION = 4
NUMBER_OF_LABELS = 6

BOAT_SPAWN_INTERVAL_INITIAL = 6
BOAT_SPAWN_INTERVAL_DELTA = -0.05 -- per second
BOAT_SPAWN_INTERVAL_MINIMUM = 1

local function contactBegan(fixture1, fixture2, contact)
	for i = 1, #boats do
		local boat = boats[i]
		if either(boat.fixture, fixture1, fixture2) then
			-- boat hit something! was it a boat?
			for j = 1, #boats do
				local otherBoat = boats[j]
				if either(otherBoat.fixture, fixture1, fixture2) then
					-- it was indeed. fast enough collision to do damage?
					local boatVelocityX, boatVelocityY = boat.body:getLinearVelocity()
					local otherBoatVelocityX, otherBoatVelocityY = otherBoat.body:getLinearVelocity()
					if vLen(vSub(v(boatVelocityX, boatVelocityY), v(otherBoatVelocityX, otherBoatVelocityY))) > BOAT_IMPACT_THRESHOLD then
						damageBoat(boat)
						damageBoat(otherBoat)
						local normalX, normalY = contact:getNormal()
						boat.collisionImpartedVelocity = vMul(v(normalX, normalY), 100)
						otherBoat.collisionImpartedVelocity = vMul(v(normalX, normalY), -100)
					end
				end
			end
		end
	end
	-- note: don’t remove objects in physics callback
end

function love.load()
	love.graphics.setLineStyle("smooth")
	math.randomseed(os.time())

	backgroundImage = love.graphics.newImage("graphics/background.png")
	boatImage = love.graphics.newImage("graphics/boat.png")
	youNormalImage = love.graphics.newImage("graphics/you normal.png")
	youGrabbyImage = love.graphics.newImage("graphics/you grabby.png")
	heartEmptyImage = love.graphics.newImage("graphics/heart empty.png")
	heartFullImage = love.graphics.newImage("graphics/heart full.png")
	wavesImage = love.graphics.newImage("graphics/waves.png")
	for i = 1, NUMBER_OF_LABELS do
		labelImages[#labelImages + 1] = love.graphics.newImage("graphics/labels/label " .. tostring(i) .. ".png")
	end

	backgroundMusic = love.audio.newSource("sounds/background.mp3")
	backgroundMusic:setLooping(true)
	backgroundMusic:play()

	-- physics

	local w, h = love.window.getDimensions()

	STARTING_POSITION = v(w / 2, h * 0.8)

	world = love.physics.newWorld()
	world:setCallbacks(contactBegan, nil, nil, nil)

	leftWall = {}
	leftWall.shape = love.physics.newRectangleShape(WALL_THICKNESS, h * 1.5)
	leftWall.body = love.physics.newBody(world, WALL_THICKNESS / 2, h / 2)
	leftWall.fixture = love.physics.newFixture(leftWall.body, leftWall.shape)
	leftWall.fixture:setCategory(SIDE_CATEGORY)
	leftWall.fixture:setRestitution(1)

	local rightWall = {}
	rightWall.shape = love.physics.newRectangleShape(WALL_THICKNESS, h * 1.5)
	rightWall.body = love.physics.newBody(world, w - SHORE_WIDTH + WALL_THICKNESS / 2, h / 2)
	rightWall.fixture = love.physics.newFixture(rightWall.body, rightWall.shape)
	rightWall.fixture:setCategory(SIDE_CATEGORY)
	rightWall.fixture:setRestitution(1)

	local floor = {}
	floor.shape = love.physics.newRectangleShape(w * 2, WALL_THICKNESS)
	floor.body = love.physics.newBody(world, 0, h - WALL_THICKNESS / 2)
	floor.fixture = love.physics.newFixture(floor.body, floor.shape)
	floor.fixture:setRestitution(0)

	local ceiling = {}
	ceiling.shape = love.physics.newRectangleShape(w * 2, WALL_THICKNESS)
	ceiling.body = love.physics.newBody(world, 0, WALL_THICKNESS / 2)
	ceiling.fixture = love.physics.newFixture(ceiling.body, ceiling.shape)
	ceiling.fixture:setRestitution(1)

	you = {}
	you.shape = love.physics.newCircleShape(30)
	you.body = love.physics.newBody(world, 0, 0, "dynamic") -- 0,0 for now — reset() is responsible for the actual starting position
	you.fixture = love.physics.newFixture(you.body, you.shape)
	you.fixture:setCategory(YOU_CATEGORY)
	you.fixture:setRestitution(0.9)

	youJoint = love.physics.newMouseJoint(you.body, 0, 0)

	youShader = love.graphics.newShader("you.fsh")
	boatShader = love.graphics.newShader("boat.fsh")

	-- get gameplay stuff ready

	for i = 1, 3 do
		boats[#boats + 1] = makeBoat(80 + math.random() * 150, 2 * WALL_THICKNESS + math.random() * (h - 4 * WALL_THICKNESS))
	end

	reset()
end

function love.draw()
	love.graphics.setColor(255, 255, 255, 255)
	local w, h = love.window.getDimensions()

	if playing then
		love.graphics.draw(backgroundImage, 0, 0)

		if isGrabbing then
			love.graphics.setColor(40, 10, 0, 255)
		else
			love.graphics.setColor(150, 101, 7, 255)
		end

		-- player
		local youImage = (isGrabbing and youGrabbyImage or youNormalImage)
		local youImageWidth, youImageHeight = youImage:getDimensions()
		love.graphics.push()
		love.graphics.translate(you.body:getX(), you.body:getY())
		love.graphics.setShader(youShader)
		love.graphics.draw(youImage, -youImageWidth / 2, -youImageHeight / 2, 0, 1)
		love.graphics.setShader(nil)
		love.graphics.pop()

		local boatImageWidth, boatImageHeight = boatImage:getDimensions()
		local heartImageWidth, heartImageHeight = heartFullImage:getDimensions()
		local heartPadding = 3
		local wavesImageWidth, wavesImageHeight = wavesImage:getDimensions()

		-- boats
		for i = 1, #boats do
			local boat = boats[i]

			love.graphics.setColor(40, 10, 0, 255)
			love.graphics.push()
			love.graphics.translate(boat.body:getX(), boat.body:getY())

			local health = boat.health
			local healthStartX = -((heartImageWidth * BOAT_MAXIMUM_HEALTH) + (heartPadding * (BOAT_MAXIMUM_HEALTH - 1))) / 2 - 4
			for i = 1, BOAT_MAXIMUM_HEALTH do
				local heartY = -36
				heartFraction = (i - 1) / BOAT_MAXIMUM_HEALTH
				if i <= health then
					heartY = heartY - math.pow(math.abs(math.sin(5 * elapsedTime + (boat.rockPhase + heartFraction) * math.pi)), .6) * 4
				elseif boat.ended then
					heartFallAmount = math.min(1, math.max(0, (elapsedTime - boat.endTime) / 0.9 - heartFraction * 0.2))
					love.graphics.setColor(40, 10, 0, 255 * (1.0 - math.pow(heartFallAmount, 6)))
					heartY = heartY + (2.4 * heartFallAmount * (heartFallAmount - 0.6)) * 60
				end
				love.graphics.draw(i > health and heartEmptyImage or heartFullImage, healthStartX + (heartImageWidth + heartPadding) * (i - 1), heartY)
			end
			
			local labelVisibility = 1 -- modified below if the label needs to be fading out

			local damageFactor = 1 - math.max(0,math.min(1,(elapsedTime - boat.lastDamageTime) / 0.5))
			
			local angle = math.sin(3 * elapsedTime + boat.rockPhase * math.pi) * .08 - .05
			if boat.ended == true then
				angle = 0
				
				local sinkProgress = (elapsedTime - boat.endTime) / BOAT_SINK_DURATION
				local waveProgress = 0
				if sinkProgress <= 1 then
					waveProgress = math.min(1.0, sinkProgress * 4)
				else
					waveProgress = math.max(0.0, 1.0 - (sinkProgress - 1) * 4)
					labelVisibility = waveProgress
				end
				love.graphics.setColor(100, 53, 0, waveProgress * 255)
				love.graphics.draw(wavesImage, 0, boatImageHeight / 2 + 6, 0, 1, 0.3 + waveProgress * 0.7 * (.7 + .3 * math.abs(math.sin(elapsedTime * 5 + boat.rockPhase * math.pi))), wavesImageWidth / 2, wavesImageHeight)

				love.graphics.setShader(boatShader)
				boatShader:send("progress", sinkProgress)
			end
			love.graphics.setColor(40 + damageFactor * 200, 10, 0,255)
			love.graphics.draw(boatImage, -boatImageWidth / 2, -boatImageHeight / 2, angle, 1) -- x, y, rotation, scale
			if boat.ended then
				love.graphics.setShader(nil)
			end

			local labelImage = labelImages[boat.labelIndex]
			local labelWidth, labelHeight = labelImage:getDimensions()
			
			love.graphics.setColor(100, 40, 0, 180 * labelVisibility)
			love.graphics.draw(labelImage, -labelWidth / 2, 30)

			love.graphics.pop()
		end

		-- TODO: score etc.
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
		local screenWidth, screenHeight = love.window.getDimensions()

		-- player movement
		local currentPositionX, currentPositionY = youJoint:getTarget()
		local currentPosition = v(currentPositionX, currentPositionY)
		local newPosition = currentPosition

		targetPosition = v(love.mouse.getX(), love.mouse.getY())

		local towards = vMul(vSub(targetPosition, currentPosition), 2)
		local towardsLength = vLen(towards)
		local maxSpeed = YOU_SPEED
		local minSpeed = YOU_MINIMUM_SPEED
		if isGrabbing then
			maxSpeed = maxSpeed * YOU_GRABBING_SPEED_MULTIPLIER
			minSpeed = minSpeed * YOU_GRABBING_SPEED_MULTIPLIER
		end
		if towardsLength > maxSpeed then
			towards = vMul(towards, maxSpeed / towardsLength)
		elseif towardsLength < minSpeed then
			towards = vMul(towards, minSpeed / towardsLength)
		end
		newPosition = vAdd(currentPosition, vMul(towards, dt))
		newPosition.x = math.max(math.min(newPosition.x, screenWidth - SHORE_WIDTH - YOU_RADIUS), WALL_THICKNESS + YOU_RADIUS)
		newPosition.y = math.max(math.min(newPosition.y, screenHeight - WALL_THICKNESS - YOU_RADIUS), WALL_THICKNESS + YOU_RADIUS)

		youJoint:setTarget(newPosition.x, newPosition.y)

		-- boat spawns
		local boatSpawnInterval = math.max(BOAT_SPAWN_INTERVAL_MINIMUM, BOAT_SPAWN_INTERVAL_INITIAL - BOAT_SPAWN_INTERVAL_DELTA * elapsedTime)
		if elapsedTime > lastBoatTime + boatSpawnInterval then
			boats[#boats + 1] = makeBoat(-WALL_THICKNESS * 2, 2 * WALL_THICKNESS + math.random() * (screenHeight - 4 * WALL_THICKNESS))
			lastBoatTime = elapsedTime
		end

		-- grabbing
		checkGrab()

		-- boat movement etc.
		local boatIndicesToRemove = {}
		for i = 1, #boats do
			local boat = boats[i]
			local boatPosition = v(boat.body:getX(), boat.body:getY())
			local collisionImpartedVelocity = boat.collisionImpartedVelocity
			if boat.health > 0 then
				if boat.isGrabbed == false then
					if boat.moveJoint ~= nil then
						if collisionImpartedVelocity ~= nil then
							-- if it just got hit, bounce it off
							doCollision(boat)
						else
							-- move normally (TODO: add some variety to this, few octaves of noise?)
							local speed = boat.speed
							if speed < BOAT_SPEED then
								speed = speed + (BOAT_SPEED * BOAT_ACCELERATION * dt)
								boat.speed = speed
							end
							boat.moveJoint:setTarget(boatPosition.x + boat.speed * dt, boatPosition.y)
						end
					else
						-- it’s not being moved — check whether it’s slowed down enough to start moving again
						local boatVelocityX, boatVelocityY = boat.body:getLinearVelocity()
						if vLen(v(boatVelocityX, boatVelocityY)) < BOAT_RECOVER_SPEED then
							setBoatMoving(boat, true)
						end
					end
				else -- boat is grabbed, but maybe it shouldn’t be — let’s check
					if collisionImpartedVelocity ~= nil then
						doCollision(boat)
					end
				end
			else
				-- boat’s dead :(
				if not boat.ended then
					endBoat(boat)
				elseif elapsedTime > boat.endTime + 2 * BOAT_SINK_DURATION then
					boatIndicesToRemove[#boatIndicesToRemove + 1] = i
				end
			end
		end

		local numberOfAlreadyRemovedBoats = 0
		for i = 1, #boatIndicesToRemove do
			local boat = boats[boatIndicesToRemove[i]]
			table.remove(boats, boatIndicesToRemove[i] - numberOfAlreadyRemovedBoats)
			numberOfAlreadyRemovedBoats = numberOfAlreadyRemovedBoats + 1
		end


		youShader:send("time", elapsedTime)
		youShader:send("grabbing", (isGrabbing and 1 or 0))

		world:update(dt)
	end
end

function makeBoat(x, y)
	local boat = {}
	boat.shape = love.physics.newCircleShape(20)
	boat.body = love.physics.newBody(world, x, y, "dynamic")
	boat.body:setLinearDamping(0.6)
	boat.fixture = love.physics.newFixture(boat.body, boat.shape)
	boat.fixture:setCategory(BOAT_CATEGORY)
	boat.fixture:setMask(SIDE_CATEGORY, YOU_CATEGORY)
	boat.speed = 0
	boat.health = BOAT_MAXIMUM_HEALTH
	boat.lastDamageTime = -60
	boat.isGrabbed = false
	boat.rockPhase = math.random()
	boat.labelIndex = math.random(NUMBER_OF_LABELS)
	boat.ended = false
	setBoatMoving(boat, true)
	return boat
end

function setBoatMoving(boat, moving)
	if not boat.ended then
		if boat.moveJoint == nil and moving then
			boat.speed = 0
			boat.moveJoint = love.physics.newMouseJoint(boat.body, boat.body:getX(), boat.body:getY())
		elseif boat.moveJoint ~= nil and not moving then
			boat.moveJoint:destroy()
			boat.moveJoint = nil
		end
	end
end

function endBoat(boat)
	setBoatMoving(boat, false)
	if boat.isGrabbed then
		endGrabbing()
	end
	boat.fixture:setMask(BOAT_CATEGORY, SIDE_CATEGORY, YOU_CATEGORY)
	boat.ended = true
	boat.endTime = elapsedTime
	boat.collisionImpartedVelocity = nil
	boat.body:setLinearVelocity(0, 0)
end

function doCollision(boat)
	setBoatMoving(boat, false)
	boat.body:applyLinearImpulse(boat.collisionImpartedVelocity.x, boat.collisionImpartedVelocity.y)
	boat.collisionImpartedVelocity = nil
	if boat.isGrabbed then
		endGrabbing()
	end
end

function damageBoat(boat)
	if elapsedTime > boat.lastDamageTime + BOAT_DAMAGE_INTERVAL then
		boat.health = math.max(0, boat.health - 1)
		boat.lastDamageTime = elapsedTime
		boat.speed = 0
		-- we don’t remove the boat here because it ain’t safe — this is called from the physics callback. 
	end
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
	playing = false
	gameOver = false
	elapsedTime = 0
	lastBoatTime = -BOAT_SPAWN_INTERVAL_INITIAL
	
	youJoint:setTarget(STARTING_POSITION.x, STARTING_POSITION.y)
	you.body:setX(STARTING_POSITION.x)
	you.body:setY(STARTING_POSITION.y)
	
	targetPosition = nil
end

function start()
	playing = true
end

function checkGrab()
	if isGrabbing and #grabbedBoats == 0 then
		for i = 1, #boats do
			local boat = boats[i]
			if boat.ended == false then
				local boatPosition = v(boat.body:getX(), boat.body:getY())
				local youPosition = v(you.body:getX(), you.body:getY())
				local boatDistance = vDist(boatPosition, youPosition)
				if boatDistance < GRAB_DISTANCE then
					setBoatMoving(boat, false)
					local grabPosition = vMix(youPosition, boatPosition, GRAB_HOLD_DISTANCE / boatDistance)
					local grabJoint = love.physics.newDistanceJoint(you.body, boat.body, grabPosition.x, grabPosition.y, boatPosition.x, boatPosition.y)
					boat.grabJoint = grabJoint
					boat.isGrabbed = true
					grabbedBoats[#grabbedBoats + 1] = boat
				end
			end
		end
	end
end

function endGrabbing()
	if isGrabbing then
		isGrabbing = false
		for i = 1, #grabbedBoats do
			local boat = grabbedBoats[i]
			boat.grabJoint:destroy()
			boat.grabJoint = nil
			boat.isGrabbed = false
		end
		grabbedBoats = {}
	end
end

function love.mousepressed(x, y, button)
	if not playing then
		if gameOver then
			reset()
		else
			start()
		end
	else
		if not isGrabbing then
			isGrabbing = true
			grabbedBoats = {}
			checkGrab()
		end
	end
end

function love.mousereleased(x, y, button)
	if playing then
		endGrabbing()
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

