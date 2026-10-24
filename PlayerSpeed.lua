-- PlayerSpeed Mod

-- FS17 refactor, FS19, FS22 and FS25 by *TurboStar*

-- v1.0.0.0  		Initial FS25 release
-- v1.1.0.0 		Fix slow start and stop with high speeds

PlayerSpeed = {}
PlayerSpeed.RATIOS = {0.2, 0.5, 0.7, 1.0, 3.0, 8.0, 15.0} -- ratio
PlayerSpeed.TEXT_KEYS = {"ps_slow02", "ps_slow05", "ps_slow07", "ps_x1", "ps_x3", "ps_x8", "ps_x15"}
PlayerSpeed.DEFAULT_CONT = 4

local PlayerSpeed_mt = Class(PlayerSpeed)

-- Private helpers: file-local, so not reachable from other files or mods

-- Below this horizontal speed (m/s) the player counts as stopped
local STOPPED_SPEED = 0.1

local function getControlledPlayer()
	local player = g_localPlayer
	if player ~= nil and player.isControlled then
		return player
	end
	return nil
end

-- Horizontal speed of the player (also correct in flight mode, see syncFlightVelocity)
local function getPlayerSpeed(player)
	return player.mover:getSpeed()
end

-- Acceleration and deceleration scale with high ratios only, see scaleAcceleration
local function getTargetAccDecMltp(self)
	return math.max(1.0, self.ratio)
end

-- A higher multiplier is applied at once. A lower one waits until the player has stopped,
-- so a fast moving player does not slide for a long time after lowering the speed
local function updateAccDecMltp(self, player, applyNow)
	local target = getTargetAccDecMltp(self)
	if target == self.accDecMltp then
		return
	end
	if applyNow or target > self.accDecMltp or player == nil or getPlayerSpeed(player) <= STOPPED_SPEED then
		self.accDecMltp = target
	end
end

-- Only needs to run when cont changes or events are (re)registered, not every frame
local function refreshActionEvents(self)
	local canReduce = self.cont ~= 1
	local canIncrease = self.cont ~= self.ratiosLen
	if self.eventIdReduce ~= nil then
		g_inputBinding:setActionEventActive(self.eventIdReduce, canReduce)
		g_inputBinding:setActionEventTextVisibility(self.eventIdReduce, canReduce)
	end
	if self.eventIdIncrease ~= nil then
		g_inputBinding:setActionEventActive(self.eventIdIncrease, canIncrease)
		g_inputBinding:setActionEventTextVisibility(self.eventIdIncrease, canIncrease)
	end
end

function PlayerSpeed.new(customMt)
	Logging.info("PlayerSpeed: init mod...")
	local self = setmetatable({}, customMt or PlayerSpeed_mt)
	self.ratios = PlayerSpeed.RATIOS
	self.ratiosLen = #self.ratios
	-- Resolve translations once instead of every frame
	self.texts = {}
	for i, key in ipairs(PlayerSpeed.TEXT_KEYS) do
		self.texts[i] = g_i18n:getText(key)
	end
	self.cont = PlayerSpeed.DEFAULT_CONT -- It starts with default ratio
	self.ratio = self.ratios[self.cont]
	self.accDecMltp = getTargetAccDecMltp(self)
	self.eventIdReduce, self.eventIdIncrease = nil, nil
	self.firstTime = true
	return self
end

function PlayerSpeed:delete()
	self:unregisterActionEvents()
end

function PlayerSpeed:registerActionEvents()
	-- Reset at start
	if self.firstTime then
		self:setCont(PlayerSpeed.DEFAULT_CONT, true)
		self.firstTime = false
	end

	g_inputBinding:beginActionEventsModification(PlayerInputComponent.INPUT_CONTEXT_NAME)
	local valid, eventId = g_inputBinding:registerActionEvent(InputAction.SPEEDMINUS, self, self.reduceSpeed, false, true, false, true, -1, true) --
	self.eventIdReduce = valid and eventId or nil
	valid, eventId = g_inputBinding:registerActionEvent(InputAction.SPEEDPLUS, self, self.incrementSpeed, false, true, false, true, 1, true) --
	self.eventIdIncrease = valid and eventId or nil
	g_inputBinding:endActionEventsModification()
	refreshActionEvents(self)
end

function PlayerSpeed:unregisterActionEvents()
	if self.eventIdReduce == nil and self.eventIdIncrease == nil then
		return
	end
	-- Events are registered with the PlayerSpeed instance as target, not the input component
	g_inputBinding:beginActionEventsModification(PlayerInputComponent.INPUT_CONTEXT_NAME)
	g_inputBinding:removeActionEventsByTarget(self)
	g_inputBinding:endActionEventsModification()
	self.eventIdReduce, self.eventIdIncrease = nil, nil
end

function PlayerSpeed:reduceSpeed(actionName, keyStatus)
	if self.cont > 1 then
		self:setCont(self.cont - 1)
	end
	-- g_inputBinding.events[self.eventIdReduce].callbackState is -1 here
end

function PlayerSpeed:incrementSpeed(actionName, keyStatus)
	if self.cont < self.ratiosLen then
		self:setCont(self.cont + 1)
	end
	-- g_inputBinding.events[self.eventIdIncrease].callbackState is 1 here
end

-- Selects a ratio. The speed changes at once, a lower acceleration only once the player has stopped (see PlayerSpeed:update)
function PlayerSpeed:setCont(cont, applyNow)
	self.cont = cont
	self.ratio = self.ratios[cont]
	updateAccDecMltp(self, getControlledPlayer(), applyNow)
	refreshActionEvents(self)
end

function PlayerSpeed:update(dt)
	if not g_currentMission:getIsClient() then
		return
	end
	local player = getControlledPlayer()

	-- Apply a deferred lower acceleration once the player has stopped (or left the on-foot state)
	updateAccDecMltp(self, player)

	if player == nil or (g_gui ~= nil and g_gui:getIsGuiVisible()) then
		return
	end

	g_currentMission:addExtraPrintText(self.texts[self.cont])
end

-- Base game hooks are installed once and forward to the current instance
PlayerInputComponent.registerActionEvents = Utils.appendedFunction(PlayerInputComponent.registerActionEvents, function(inputComponent)
	if g_playerSpeed ~= nil and inputComponent.player.isOwner then
		g_playerSpeed:registerActionEvents()
	end
end)

PlayerInputComponent.unregisterActionEvents = Utils.appendedFunction(PlayerInputComponent.unregisterActionEvents, function(inputComponent)
	if g_playerSpeed ~= nil and inputComponent.player.isOwner then
		g_playerSpeed:unregisterActionEvents()
	end
end)

-- Shared override for every player movement state
function PlayerSpeed.scaleVelocity(state, superFunc, directionX, directionY)
	local speedX, speedY = superFunc(state, directionX, directionY)
	local ratio = g_playerSpeed ~= nil and g_playerSpeed.ratio
	if ratio then
		return speedX*ratio, speedY*ratio
	end
	return speedX, speedY
end

for _, stateClass in ipairs({PlayerStateWalk, PlayerStateJump, PlayerStateCrouch, PlayerStateFall, PlayerStateSwim}) do
	stateClass.calculateDesiredHorizontalVelocity = Utils.overwrittenFunction(stateClass.calculateDesiredHorizontalVelocity, PlayerSpeed.scaleVelocity)
end

-- Faster start and stop at high ratios, only for the local player
function PlayerSpeed.scaleAcceleration(mover, superFunc)
	local value = superFunc(mover)
	if g_playerSpeed ~= nil and mover.player.isOwner then
		return value * g_playerSpeed.accDecMltp
	end
	return value
end

PlayerMover.getAcceleration = Utils.overwrittenFunction(PlayerMover.getAcceleration, PlayerSpeed.scaleAcceleration)
PlayerMover.getDeceleration = Utils.overwrittenFunction(PlayerMover.getDeceleration, PlayerSpeed.scaleAcceleration)

-- Ground walk/run speed for the current input
local function calculateGroundSpeed(player, walkState)
	local input = player.inputComponent
	if input.walkAxis <= 0 then
		return 0
	end
	local maxWalkSpeed = walkState:getMaximumWalkSpeed()
	local runMultiplier = player:getRunMultiplier()
	if input.runAxis > 0 and runMultiplier > 0 then
		return player.mover:calculateSmoothSpeed(input.runAxis * input.walkAxis * runMultiplier, false, maxWalkSpeed, walkState:getMaximumRunSpeed())
	end
	return player.mover:calculateSmoothSpeed(input.walkAxis * player:getWalkMultiplier(), false, 0, maxWalkSpeed)
end

-- Flight mode (gsPlayerFlightToggle): move horizontally at the ground walk/run speed scaled by the ratio,
-- with the same acceleration and deceleration as on foot
function PlayerSpeed.syncFlightVelocity(mover, superFunc, dt)
	local player = mover.player
	if not mover.isFlightActive or g_playerSpeed == nil or not player.isOwner or player.inputComponent == nil then
		return superFunc(mover, dt)
	end
	local walkState = player.stateMachine.states.onFoot.states.walking

	local speed = calculateGroundSpeed(player, walkState) * g_playerSpeed.ratio
	local input = player.inputComponent
	mover.currentForceX = input.worldDirectionX * speed
	mover.currentForceZ = input.worldDirectionZ * speed

	mover.isFlightActive = false
	superFunc(mover, dt)
	mover.isFlightActive = true
end

PlayerMover.updateHorizontalVelocity = Utils.overwrittenFunction(PlayerMover.updateHorizontalVelocity, PlayerSpeed.syncFlightVelocity)
