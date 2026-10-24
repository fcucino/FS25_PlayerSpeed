-- PlayerSpeed Mod

-- Development helpers (console commands)
-- Console commands need <development><controls>true</controls></development> in game.xml

local modDirectory = g_currentModDirectory

local PlayerSpeedDev = {}

-- psReload: sources PlayerSpeed.lua again and recreates the instance, keeping the selected ratio
function PlayerSpeedDev:consoleCommandReload()
	local wasLoaded = g_playerSpeed ~= nil
	local ratio = wasLoaded and g_playerSpeed.ratio or nil
	if wasLoaded then
		g_playerSpeed:delete()
		g_playerSpeed = nil
	end

	source(modDirectory .. "PlayerSpeed.lua")

	-- Log the speed messages other mods receive
	g_messageCenter:unsubscribeAll(PlayerSpeedDev)
	g_messageCenter:subscribe(MessageType.PLAYER_SPEED_CHANGED, PlayerSpeedDev.onPlayerSpeedChanged, PlayerSpeedDev)

	if wasLoaded then
		g_playerSpeed = PlayerSpeed.new()
		if g_localPlayer ~= nil and g_localPlayer.inputComponent ~= nil then
			g_playerSpeed:registerActionEvents()
		end
		g_playerSpeed:setCont(g_playerSpeed:findRatioIndex(ratio), true)
	end

	return "[PlayerSpeed] PlayerSpeed.lua reloaded"
end

function PlayerSpeedDev:onPlayerSpeedChanged(isHandling, ratio)
	Logging.info("[PlayerSpeed dev] PLAYER_SPEED_CHANGED isHandling=%s ratio=%s", tostring(isHandling), tostring(ratio))
end

addConsoleCommand("psReload", "Reloads PlayerSpeed (development)", "consoleCommandReload", PlayerSpeedDev)
