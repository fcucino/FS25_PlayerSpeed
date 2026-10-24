-- PlayerSpeed Mod

-- Development helpers (console commands)
-- Console commands need <development><controls>true</controls></development> in game.xml

local modDirectory = g_currentModDirectory

local PlayerSpeedDev = {}

-- psReload: sources PlayerSpeed.lua again and recreates the instance, keeping the selected ratio
function PlayerSpeedDev:consoleCommandReload()
	local wasLoaded = g_playerSpeed ~= nil
	local cont = wasLoaded and g_playerSpeed.cont or nil
	if wasLoaded then
		g_playerSpeed:delete()
		g_playerSpeed = nil
	end

	source(modDirectory .. "PlayerSpeed.lua")

	if wasLoaded then
		g_playerSpeed = PlayerSpeed.new()
		if g_localPlayer ~= nil and g_localPlayer.inputComponent ~= nil then
			g_playerSpeed:registerActionEvents()
		end
		g_playerSpeed:setCont(math.min(cont, g_playerSpeed.ratiosLen), true)
	end

	return "PlayerSpeed: PlayerSpeed.lua reloaded"
end

addConsoleCommand("psReload", "Reloads PlayerSpeed (development)", "consoleCommandReload", PlayerSpeedDev)
