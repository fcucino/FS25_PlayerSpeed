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

local function setAccDec(self, mltp)
	PlayerMover.ACCELERATION = self.acc * mltp
	PlayerMover.DECELERATION = self.dec * mltp
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
	local self = setmetatable({}, customMt or PlayerSpeed_mt)
	self.acc = PlayerMover.ACCELERATION or 16.0
	self.dec = PlayerMover.DECELERATION or 10.0
	self.ratios = PlayerSpeed.RATIOS
	self.ratiosLen = #self.ratios
	-- Resolve translations once instead of every frame
	self.texts = {}
	for i, key in ipairs(PlayerSpeed.TEXT_KEYS) do
		self.texts[i] = g_i18n:getText(key)
	end
	self.cont = PlayerSpeed.DEFAULT_CONT -- It starts with default ratio
	self.ratio = self.ratios[self.cont]
	self.eventIdReduce, self.eventIdIncrease = nil, nil
	self.errorDisplayed, self.firstTime = false, true
	return self
end

function PlayerSpeed:delete()
	self:unregisterActionEvents()
	-- Restore the base game values so the next savegame starts clean
	PlayerMover.ACCELERATION = self.acc
	PlayerMover.DECELERATION = self.dec
end

function PlayerSpeed:registerActionEvents()
	-- Reset at start
	if self.firstTime then
		self:setCont(PlayerSpeed.DEFAULT_CONT)
		self.firstTime = false
	end
	
	g_inputBinding:beginActionEventsModification(PlayerInputComponent.INPUT_CONTEXT_NAME)
	_, self.eventIdReduce = g_inputBinding:registerActionEvent(InputAction.SPEEDMINUS, self, self.reduceSpeed, false, true, false, true, -1, true) --
	_, self.eventIdIncrease = g_inputBinding:registerActionEvent(InputAction.SPEEDPLUS, self, self.incrementSpeed, false, true, false, true, 1, true) --
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

function PlayerSpeed:setCont(cont)
	self.cont = cont
	self.ratio = self.ratios[cont]
	setAccDec(self, math.max(1.0, self.ratio))
	refreshActionEvents(self)
end

function PlayerSpeed:update(dt)
	if not g_currentMission:getIsClient() or (g_gui ~= nil and g_gui.currentGuiName ~= "") then
		return
	end
	local player = g_currentMission.playerSystem.playersByUserId[g_currentMission.playerUserId]
	if not player or not player.isControlled then
		return
	end

	local text = self.cont and self.texts[self.cont]
	if text == nil then
		if not self.errorDisplayed then
			print("PlayerSpeed: something is wrong on PlayerSpeed... Aborting functionality. Please report your log.txt")
			self.errorDisplayed = true
		end
		return
	end

	-- Extra print text is cleared every frame, so it has to be re-added each update
	g_currentMission:addExtraPrintText(text)
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

print("    Loading PlayerSpeed Mod...")
