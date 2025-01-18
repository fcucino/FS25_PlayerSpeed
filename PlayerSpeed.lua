-- PlayerSpeed Mod

-- FS17 refactor, FS19, FS22 and FS25 by *TurboStar*

-- v1.0.0.0  		Initial FS25 release
-- v1.1.0.0 		Fix slow start and stop with high speeds

PlayerSpeed = {}

function PlayerSpeed:loadMap()
	self.ACC = PlayerMover.ACCELERATION or 16.0
	self.DEC = PlayerMover.DECELERATION or 10.0
	self.SPEEDS = {0.2, 0.5, 0.7, 1.0, 3.0, 8.0, 15.0} -- ratio
	self.SPEEDS_LENGTH = #self.SPEEDS
	self.TEXTS = {"ps_slow02", "ps_slow05", "ps_slow07", "ps_x1", "ps_x3", "ps_x8", "ps_x15", ["other"] = "ps_othermod"}
	self.cont = 4 -- It starts with default speed
	self.eventIdReduce, self.eventIdIncrease = nil, nil
	self.errorDisplayed, self.firstTime = false, true
end

function PlayerSpeed:registerActionEvents()
	if self.player.isOwner then
		g_inputBinding:beginActionEventsModification(PlayerInputComponent.INPUT_CONTEXT_NAME)
		-- Reset at start
		if PlayerSpeed.firstTime then
			PlayerSpeed.cont = 4
			PlayerSpeed.firstTime = false
		end
		_, PlayerSpeed.eventIdReduce = g_inputBinding:registerActionEvent(InputAction.SPEEDMINUS, PlayerSpeed, PlayerSpeed.reduceSpeed, false, true, false, true, -1, true) --
		_, PlayerSpeed.eventIdIncrease = g_inputBinding:registerActionEvent(InputAction.SPEEDPLUS, PlayerSpeed, PlayerSpeed.incrementSpeed, false, true, false, true, 1, true) --
		g_inputBinding:endActionEventsModification()
	end
end
PlayerInputComponent.registerActionEvents = Utils.appendedFunction(PlayerInputComponent.registerActionEvents, PlayerSpeed.registerActionEvents)

function PlayerSpeed:unregisterActionEvents()
	if self.player.isOwner then
		g_inputBinding:removeActionEventsByTarget(self)
	end
end
PlayerInputComponent.unregisterActionEvents = Utils.appendedFunction(PlayerInputComponent.unregisterActionEvents, PlayerSpeed.unregisterActionEvents)

function PlayerSpeed:reduceSpeed(actionName, keyStatus)
	if (self.cont == 1) then return end
	self.cont = self.cont - 1
	PlayerSpeed.setAccDec(math.max(1.0, self.SPEEDS[self.cont]))
	-- g_inputBinding.events[PlayerSpeed.eventIdReduce].callbackState is -1 here
end

function PlayerSpeed:incrementSpeed(actionName, keyStatus)
	if (self.cont == self.SPEEDS_LENGTH) then return end
	self.cont = self.cont + 1
	PlayerSpeed.setAccDec(math.max(1.0, self.SPEEDS[self.cont]))
	-- g_inputBinding.events[PlayerSpeed.eventIdIncrease].callbackState is 1 here
end

function PlayerSpeed:update(dt, isActiveForInput, isSelected)
	local player = g_currentMission.playerSystem.playersByUserId[g_currentMission.playerUserId]
	if not g_currentMission:getIsClient() or not player or (player and not player.isControlled) or (g_gui ~= nil and g_gui.currentGuiName ~= "") then
        return
    end

	if (self.cont ~= nil and (self.cont < 1 or self.cont > self.SPEEDS_LENGTH)) or self.cont == nil then
		if not self.errorDisplayed then
			print("PlayerSpeed: something is wrong on PlayerSpeed.cont variable... Aborting functionality. Please report your log.txt")
			self.errorDisplayed = true
		end
		return
	end

	g_inputBinding:setActionEventActive(self.eventIdReduce, self.cont ~= 1)
	g_inputBinding:setActionEventTextVisibility(self.eventIdReduce, self.cont ~= 1)
	g_inputBinding:setActionEventActive(self.eventIdIncrease, self.cont ~= self.SPEEDS_LENGTH)
	g_inputBinding:setActionEventTextVisibility(self.eventIdIncrease, self.cont ~= self.SPEEDS_LENGTH)

	if self.cont ~= nil and self.TEXTS ~= nil and self.TEXTS[self.cont] ~= nil then
		g_currentMission:addExtraPrintText(g_i18n:getText(self.TEXTS[self.cont]))
	elseif self.TEXTS and self.TEXTS ~= nil and self.TEXTS["other"] then
		g_currentMission:addExtraPrintText(g_i18n:getText(self.TEXTS["other"]))
	end
end

function PlayerSpeed.setAccDec(mltp)
	if PlayerSpeed and mltp then
		PlayerMover.ACCELERATION = PlayerSpeed.ACC * mltp
		PlayerMover.DECELERATION = PlayerSpeed.DEC * mltp
	end
end

function PlayerSpeed:speedWalk(superFunc, directionX, directionY)
	-- print("speed walk")
	local speedX, speedY = superFunc(self, directionX, directionY)
	if PlayerSpeed and PlayerSpeed.SPEEDS and PlayerSpeed.cont then
		return speedX*PlayerSpeed.SPEEDS[PlayerSpeed.cont], speedY*PlayerSpeed.SPEEDS[PlayerSpeed.cont]
	end
	return speedX, speedY
end
PlayerStateWalk.calculateDesiredHorizontalVelocity = Utils.overwrittenFunction(PlayerStateWalk.calculateDesiredHorizontalVelocity, PlayerSpeed.speedWalk)

function PlayerSpeed:speedJump(superFunc, directionX, directionY)
	-- print("speed jump")
	local speedX, speedY = superFunc(self, directionX, directionY)
	if PlayerSpeed and PlayerSpeed.SPEEDS and PlayerSpeed.cont then
		return speedX*PlayerSpeed.SPEEDS[PlayerSpeed.cont], speedY*PlayerSpeed.SPEEDS[PlayerSpeed.cont]
	end
	return speedX, speedY
end
PlayerStateJump.calculateDesiredHorizontalVelocity = Utils.overwrittenFunction(PlayerStateJump.calculateDesiredHorizontalVelocity, PlayerSpeed.speedJump)

function PlayerSpeed:speedCrouch(superFunc, directionX, directionY)
	-- print("speed crouch")
	local speedX, speedY = superFunc(self, directionX, directionY)
	if PlayerSpeed and PlayerSpeed.SPEEDS and PlayerSpeed.cont then
		return speedX*PlayerSpeed.SPEEDS[PlayerSpeed.cont], speedY*PlayerSpeed.SPEEDS[PlayerSpeed.cont]
	end
	return speedX, speedY
end
PlayerStateCrouch.calculateDesiredHorizontalVelocity = Utils.overwrittenFunction(PlayerStateCrouch.calculateDesiredHorizontalVelocity, PlayerSpeed.speedCrouch)

function PlayerSpeed:speedFall(superFunc, directionX, directionY)
	-- print("speed fall")
	local speedX, speedY = superFunc(self, directionX, directionY)
	if PlayerSpeed and PlayerSpeed.SPEEDS and PlayerSpeed.cont then
		return speedX*PlayerSpeed.SPEEDS[PlayerSpeed.cont], speedY*PlayerSpeed.SPEEDS[PlayerSpeed.cont]
	end
	return speedX, speedY
end
PlayerStateFall.calculateDesiredHorizontalVelocity = Utils.overwrittenFunction(PlayerStateFall.calculateDesiredHorizontalVelocity, PlayerSpeed.speedFall)

function PlayerSpeed:speedSwim(superFunc, directionX, directionY)
	-- print("speed swim")
	local speedX, speedY = superFunc(self, directionX, directionY)
	if PlayerSpeed and PlayerSpeed.SPEEDS and PlayerSpeed.cont then
		return speedX*PlayerSpeed.SPEEDS[PlayerSpeed.cont], speedY*PlayerSpeed.SPEEDS[PlayerSpeed.cont]
	end
	return speedX, speedY
end
PlayerStateSwim.calculateDesiredHorizontalVelocity = Utils.overwrittenFunction(PlayerStateSwim.calculateDesiredHorizontalVelocity, PlayerSpeed.speedSwim)

addModEventListener(PlayerSpeed)
print("    Loading PlayerSpeed Mod...")
