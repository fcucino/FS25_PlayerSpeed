-- PlayerSpeed Mod

-- FS17 refactor, FS19, FS22 and FS25 by *TurboStar*

-- v1.0.0.0  		Initial FS25 release
-- v1.1.0.0 		Fix slow start and stop with high speeds

PlayerSpeed = {}
PlayerSpeed.DEFAULT_RATIOS = {0.2, 0.5, 0.7, 1.0, 3.0, 8.0, 15.0} -- ratio
PlayerSpeed.STANDARD_TEXT_KEY = "ps_x1" -- text of DEFAULT_RATIO
PlayerSpeed.CUSTOM_TEXT_KEY = "ps_custom" -- text of any other ratio
PlayerSpeed.PAUSED_TEXT_KEY = "ps_othermod" -- text while super speed is on
PlayerSpeed.DEFAULT_RATIO = 1.0
PlayerSpeed.MAX_RATIO = 100.0
PlayerSpeed.MAX_RATIOS = 10 -- ratios read from the settings file
-- Ratios and last selected ratio, in the user's modSettings folder
PlayerSpeed.SETTINGS_FILE = "FS25_PlayerSpeed.xml"

local PlayerSpeed_mt = Class(PlayerSpeed)

-- Private helpers: file-local, so not reachable from other files or mods

-- Below this horizontal speed (m/s) the player counts as stopped
local STOPPED_SPEED = 0.1

-- Ratios closer than this count as the same ratio
local RATIO_EPSILON = 0.001

local function getSettingsDirectory()
	return getUserProfileAppPath() .. "modSettings/"
end

local function getSettingsPath()
	return getSettingsDirectory() .. PlayerSpeed.SETTINGS_FILE
end

-- Ratios from the settings file are rounded to 1 decimal
local function roundRatio(ratio)
	if ratio == nil then
		return nil
	end
	return math.floor(ratio * 10 + 0.5) / 10
end

local function isValidRatio(ratio)
	return ratio ~= nil and ratio > 0 and ratio <= PlayerSpeed.MAX_RATIO
end

-- Reads the ratios (unsorted) and the last selected ratio. Returns nil if the file can't be read
local function loadSettings(path)
	local xmlFile = XMLFile.load("playerSpeedSettings", path)
	if xmlFile == nil then
		Logging.error("[PlayerSpeed] could not parse '%s': it is not valid XML. The default ratios are used and the file is not overwritten, fix or delete it", path)
		return nil
	end
	local rootName = xmlFile:getRootName()
	if rootName ~= "playerSpeed" then
		Logging.error("[PlayerSpeed] could not parse '%s': root element is <%s> instead of <playerSpeed>. The default ratios are used and the file is not overwritten, fix or delete it", path, tostring(rootName))
		xmlFile:delete()
		return nil
	end
	local settingsRatios = {}
	xmlFile:iterate("playerSpeed.ratios.ratio", function(_, key)
		local ratio = roundRatio(xmlFile:getFloat(key .. "#value"))
		if #settingsRatios >= PlayerSpeed.MAX_RATIOS then
			Logging.warning("[PlayerSpeed] ignored ratios after the first %d in '%s'", PlayerSpeed.MAX_RATIOS, path)
			return false
		elseif isValidRatio(ratio) then
			table.insert(settingsRatios, ratio)
		else
			Logging.warning("[PlayerSpeed] skipped invalid ratio '%s' in '%s' (must be greater than 0 and at most %s)", tostring(xmlFile:getString(key .. "#value")), path, PlayerSpeed.MAX_RATIO)
		end
	end)
	-- A missing or invalid last ratio starts with the default ratio
	local lastRatio = roundRatio(xmlFile:getFloat("playerSpeed.lastRatio#value"))
	if not isValidRatio(lastRatio) then
		local lastRatioText = xmlFile:getString("playerSpeed.lastRatio#value")
		if lastRatioText ~= nil then
			Logging.warning("[PlayerSpeed] ignored invalid lastRatio '%s' in '%s' (must be greater than 0 and at most %s)", lastRatioText, path, PlayerSpeed.MAX_RATIO)
		end
		lastRatio = nil
	end
	xmlFile:delete()
	return settingsRatios, lastRatio
end

-- Ratios from the settings file, sorted ascending without duplicates.
-- The default ratios are used only if the settings file has no valid ratio
local function buildRatios(settingsRatios)
	local sorted = {}
	for i, ratio in ipairs(#settingsRatios > 0 and settingsRatios or PlayerSpeed.DEFAULT_RATIOS) do
		sorted[i] = ratio
	end
	table.sort(sorted)

	local ratios = {}
	for _, ratio in ipairs(sorted) do
		local last = ratios[#ratios]
		if last == nil or ratio - last >= RATIO_EPSILON then
			table.insert(ratios, ratio)
		end
	end
	return ratios
end

local function formatRatio(ratio)
	return string.format("%g", math.floor(ratio / RATIO_EPSILON + 0.5) * RATIO_EPSILON)
end

local function getControlledPlayer()
	local player = g_localPlayer
	if player ~= nil and player.isControlled then
		return player
	end
	return nil
end

-- Super speed (gsPlayerSuperSpeedToggle, also used by other mods) already scales speed and acceleration,
-- so the ratio is paused while it is on
local function isSuperSpeedActive(player)
	return player ~= nil and player.isOwner and player.toggleSuperSpeedCommand ~= nil and player.toggleSuperSpeedCommand.value == true
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

---Creates a new PlayerSpeed instance and loads or creates its settings
-- @param table customMt Optional custom metatable, defaults to PlayerSpeed_mt
-- @return PlayerSpeed The initialized PlayerSpeed instance
-- @includeCode
function PlayerSpeed.new(customMt)
	Logging.info("[PlayerSpeed] init mod...")
	local self = setmetatable({}, customMt or PlayerSpeed_mt)

	local settingsPath = getSettingsPath()
	local hasSettingsFile = fileExists(settingsPath)
	local settingsRatios, lastRatio
	if hasSettingsFile then
		settingsRatios, lastRatio = loadSettings(settingsPath)
		-- A settings file that can't be read is never overwritten
		self.canSaveSettings = settingsRatios ~= nil
	else
		-- The template starts with the default ratios, for the user to customize
		settingsRatios = {}
		for i, ratio in ipairs(PlayerSpeed.DEFAULT_RATIOS) do
			settingsRatios[i] = ratio
		end
		self.canSaveSettings = true
	end
	self.settingsRatios = settingsRatios or {}

	self.ratios = buildRatios(self.settingsRatios)
	-- Resolve translations once instead of every frame
	self.texts = {}
	local standardText = g_i18n:getText(PlayerSpeed.STANDARD_TEXT_KEY)
	local customText = g_i18n:getText(PlayerSpeed.CUSTOM_TEXT_KEY)
	for i, ratio in ipairs(self.ratios) do
		if math.abs(ratio - PlayerSpeed.DEFAULT_RATIO) < RATIO_EPSILON then
			self.texts[i] = standardText
		else
			self.texts[i] = string.format(customText, formatRatio(ratio))
		end
	end
	self.ratiosLen = #self.ratios
	self.pausedText = g_i18n:getText(PlayerSpeed.PAUSED_TEXT_KEY)

	-- It starts with the last selected ratio, or the default ratio
	self.startCont = self:findRatioIndex(lastRatio or PlayerSpeed.DEFAULT_RATIO)
	self.cont = self.startCont
	self.ratio = self.ratios[self.cont]
	self.accDecMltp = getTargetAccDecMltp(self)
	self.eventIdReduce, self.eventIdIncrease = nil, nil
	self.firstTime = true

	-- Template for the user to fill in
	if not hasSettingsFile then
		self:saveSettings()
	end
	return self
end

function PlayerSpeed:delete()
	-- Multiplayer clients don't save the savegame, so they remember the ratio when leaving
	if g_currentMission ~= nil and not g_currentMission:getIsServer() then
		self:saveSettings()
	end
	self:unregisterActionEvents()
end

-- Writes the ratios back and remembers the selected ratio
function PlayerSpeed:saveSettings()
	if not self.canSaveSettings then
		return
	end
	createFolder(getSettingsDirectory())
	local xmlFile = XMLFile.create("playerSpeedSettings", getSettingsPath(), "playerSpeed")
	if xmlFile == nil then
		return
	end
	xmlFile:addComment("playerSpeed", string.format(" Selectable ratios (at most %d, each greater than 0 and at most %s). Without any, the default ratios are used ",
		PlayerSpeed.MAX_RATIOS, formatRatio(PlayerSpeed.MAX_RATIO)))
	-- Default ratios ready to copy back into <ratios>
	local defaultRatios = {}
	for _, ratio in ipairs(PlayerSpeed.DEFAULT_RATIOS) do
		table.insert(defaultRatios, string.format("<ratio value=\"%s\"/>", formatRatio(ratio)))
	end
	xmlFile:addComment("playerSpeed", " Default ratios: <ratios> " .. table.concat(defaultRatios, " ") .. " </ratios>")
	for i, ratio in ipairs(self.settingsRatios) do
		xmlFile:setFloat(string.format("playerSpeed.ratios.ratio(%d)#value", i - 1), ratio)
	end
	xmlFile:setFloat("playerSpeed.lastRatio#value", self.ratio)
	xmlFile:save()
	xmlFile:delete()
end

-- Index of the ratio closest to the given one
function PlayerSpeed:findRatioIndex(ratio)
	local bestIndex, bestDiff = 1, math.huge
	for i, value in ipairs(self.ratios) do
		local diff = math.abs(value - ratio)
		if diff < bestDiff then
			bestIndex, bestDiff = i, diff
		end
	end
	return bestIndex
end

function PlayerSpeed:registerActionEvents()
	-- Reset at start
	if self.firstTime then
		self:setCont(self.startCont, true)
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

	if isSuperSpeedActive(player) then
		g_currentMission:addExtraPrintText(self.pausedText)
	else
		g_currentMission:addExtraPrintText(self.texts[self.cont])
	end
end

-- Base game hook functions forward to the current instance

function PlayerSpeed.onRegisterActionEvents(inputComponent)
	if g_playerSpeed ~= nil and inputComponent.player.isOwner then
		g_playerSpeed:registerActionEvents()
	end
end

function PlayerSpeed.onUnregisterActionEvents(inputComponent)
	if g_playerSpeed ~= nil and inputComponent.player.isOwner then
		g_playerSpeed:unregisterActionEvents()
	end
end

function PlayerSpeed.onSavegameSaved()
	if g_playerSpeed ~= nil then
		g_playerSpeed:saveSettings()
	end
end

-- Shared override for every player movement state
function PlayerSpeed.scaleVelocity(state, superFunc, directionX, directionY)
	local speedX, speedY = superFunc(state, directionX, directionY)
	local ratio = g_playerSpeed ~= nil and g_playerSpeed.ratio
	if ratio and not isSuperSpeedActive(state.player) then
		return speedX*ratio, speedY*ratio
	end
	return speedX, speedY
end

-- Faster start and stop at high ratios, only for the local player
function PlayerSpeed.scaleAcceleration(mover, superFunc)
	local value = superFunc(mover)
	if g_playerSpeed ~= nil and mover.player.isOwner and not isSuperSpeedActive(mover.player) then
		return value * g_playerSpeed.accDecMltp
	end
	return value
end

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
	if not mover.isFlightActive or g_playerSpeed == nil or not player.isOwner or player.inputComponent == nil or isSuperSpeedActive(player) then
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

-- Base game hooks are installed only once, also when this file is sourced again (psReload, see PlayerSpeedDev.lua).
-- They look up the PlayerSpeed functions on every call, so a reload replaces the code without wrapping twice.
if not g_playerSpeedHooksInstalled then
	g_playerSpeedHooksInstalled = true

	PlayerInputComponent.registerActionEvents = Utils.appendedFunction(PlayerInputComponent.registerActionEvents, function(...)
		return PlayerSpeed.onRegisterActionEvents(...)
	end)
	PlayerInputComponent.unregisterActionEvents = Utils.appendedFunction(PlayerInputComponent.unregisterActionEvents, function(...)
		return PlayerSpeed.onUnregisterActionEvents(...)
	end)

	-- Remember the selected ratio whenever the game is saved
	if FSCareerMissionInfo ~= nil then
		FSCareerMissionInfo.saveToXMLFile = Utils.appendedFunction(FSCareerMissionInfo.saveToXMLFile, function(...)
			return PlayerSpeed.onSavegameSaved(...)
		end)
	end

	for _, stateClass in ipairs({PlayerStateWalk, PlayerStateJump, PlayerStateCrouch, PlayerStateFall, PlayerStateSwim}) do
		stateClass.calculateDesiredHorizontalVelocity = Utils.overwrittenFunction(stateClass.calculateDesiredHorizontalVelocity, function(...)
			return PlayerSpeed.scaleVelocity(...)
		end)
	end

	local function scaleAcceleration(...)
		return PlayerSpeed.scaleAcceleration(...)
	end
	PlayerMover.getAcceleration = Utils.overwrittenFunction(PlayerMover.getAcceleration, scaleAcceleration)
	PlayerMover.getDeceleration = Utils.overwrittenFunction(PlayerMover.getDeceleration, scaleAcceleration)

	PlayerMover.updateHorizontalVelocity = Utils.overwrittenFunction(PlayerMover.updateHorizontalVelocity, function(...)
		return PlayerSpeed.syncFlightVelocity(...)
	end)
end
