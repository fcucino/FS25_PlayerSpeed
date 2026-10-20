-- PlayerSpeed Mod

-- FS17 refactor, FS19, FS22 and FS25 by *TurboStar*

-- v1.0.0.0  		Initial FS25 release
-- v1.1.0.0 		Fix slow start and stop with high speeds

PlayerSpeed = {}

function PlayerSpeed:loadMap()
	self.ACC = PlayerMover.ACCELERATION or 16.0
	self.DEC = PlayerMover.DECELERATION or 10.0
	self.RATIOS = {0.2, 0.5, 0.7, 1.0, 3.0, 8.0, 15.0} -- ratio
	self.RATIOS_LEN = #self.RATIOS
	-- Resolve translations once instead of every frame
	self.TEXTS = {}
	for i, key in ipairs({"ps_slow02", "ps_slow05", "ps_slow07", "ps_x1", "ps_x3", "ps_x8", "ps_x15"}) do
		self.TEXTS[i] = g_i18n:getText(key)
	end
	self.cont = 4 -- It starts with default ratio
	self.ratio = self.RATIOS[self.cont]
	self.eventIdReduce, self.eventIdIncrease = nil, nil
	self.errorDisplayed, self.firstTime = false, true
end

function PlayerSpeed:registerActionEvents()
	if self.player.isOwner then
		g_inputBinding:beginActionEventsModification(PlayerInputComponent.INPUT_CONTEXT_NAME)
		-- Reset at start
		if PlayerSpeed.firstTime then
			PlayerSpeed.setCont(4)
			PlayerSpeed.firstTime = false
		end
		_, PlayerSpeed.eventIdReduce = g_inputBinding:registerActionEvent(InputAction.SPEEDMINUS, PlayerSpeed, PlayerSpeed.reduceSpeed, false, true, false, true, -1, true) --
		_, PlayerSpeed.eventIdIncrease = g_inputBinding:registerActionEvent(InputAction.SPEEDPLUS, PlayerSpeed, PlayerSpeed.incrementSpeed, false, true, false, true, 1, true) --
		g_inputBinding:endActionEventsModification()
		PlayerSpeed.refreshActionEvents()
	end
end
PlayerInputComponent.registerActionEvents = Utils.appendedFunction(PlayerInputComponent.registerActionEvents, PlayerSpeed.registerActionEvents)

function PlayerSpeed:unregisterActionEvents()
	if self.player.isOwner then
		-- Events are registered with PlayerSpeed as target, not the input component
		g_inputBinding:beginActionEventsModification(PlayerInputComponent.INPUT_CONTEXT_NAME)
		g_inputBinding:removeActionEventsByTarget(PlayerSpeed)
		g_inputBinding:endActionEventsModification()
		PlayerSpeed.eventIdReduce, PlayerSpeed.eventIdIncrease = nil, nil
	end
end
PlayerInputComponent.unregisterActionEvents = Utils.appendedFunction(PlayerInputComponent.unregisterActionEvents, PlayerSpeed.unregisterActionEvents)

function PlayerSpeed:reduceSpeed(actionName, keyStatus)
	if self.cont > 1 then
		self.setCont(self.cont - 1)
	end
	-- g_inputBinding.events[PlayerSpeed.eventIdReduce].callbackState is -1 here
end

function PlayerSpeed:incrementSpeed(actionName, keyStatus)
	if self.cont < self.RATIOS_LEN then
		self.setCont(self.cont + 1)
	end
	-- g_inputBinding.events[PlayerSpeed.eventIdIncrease].callbackState is 1 here
end

function PlayerSpeed.setCont(cont)
	PlayerSpeed.cont = cont
	PlayerSpeed.ratio = PlayerSpeed.RATIOS[cont]
	PlayerSpeed.setAccDec(math.max(1.0, PlayerSpeed.ratio))
	PlayerSpeed.refreshActionEvents()
end

-- Only needs to run when cont changes or events are (re)registered, not every frame
function PlayerSpeed.refreshActionEvents()
	local canReduce = PlayerSpeed.cont ~= 1
	local canIncrease = PlayerSpeed.cont ~= PlayerSpeed.RATIOS_LEN
	if PlayerSpeed.eventIdReduce ~= nil then
		g_inputBinding:setActionEventActive(PlayerSpeed.eventIdReduce, canReduce)
		g_inputBinding:setActionEventTextVisibility(PlayerSpeed.eventIdReduce, canReduce)
	end
	if PlayerSpeed.eventIdIncrease ~= nil then
		g_inputBinding:setActionEventActive(PlayerSpeed.eventIdIncrease, canIncrease)
		g_inputBinding:setActionEventTextVisibility(PlayerSpeed.eventIdIncrease, canIncrease)
	end
end

function PlayerSpeed:update(dt, isActiveForInput, isSelected)
	if not g_currentMission:getIsClient() or (g_gui ~= nil and g_gui.currentGuiName ~= "") then
		return
	end
	local player = g_currentMission.playerSystem.playersByUserId[g_currentMission.playerUserId]
	if not player or not player.isControlled then
		return
	end

	local text = self.cont and self.TEXTS[self.cont]
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

function PlayerSpeed.setAccDec(mltp)
	PlayerMover.ACCELERATION = PlayerSpeed.ACC * mltp
	PlayerMover.DECELERATION = PlayerSpeed.DEC * mltp
end

-- Shared override for every player movement state
function PlayerSpeed.scaleVelocity(state, superFunc, directionX, directionY)
	local speedX, speedY = superFunc(state, directionX, directionY)
	local ratio = PlayerSpeed.ratio
	if ratio then
		return speedX*ratio, speedY*ratio
	end
	return speedX, speedY
end

for _, stateClass in ipairs({PlayerStateWalk, PlayerStateJump, PlayerStateCrouch, PlayerStateFall, PlayerStateSwim}) do
	stateClass.calculateDesiredHorizontalVelocity = Utils.overwrittenFunction(stateClass.calculateDesiredHorizontalVelocity, PlayerSpeed.scaleVelocity)
end

addModEventListener(PlayerSpeed)
print("    Loading PlayerSpeed Mod...")
