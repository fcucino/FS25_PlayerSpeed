-- PlayerSpeed Mod

-- Mod event listener: owns the PlayerSpeed instance for the lifetime of a loaded savegame
-- Must be loaded after PlayerSpeed.lua (see extraSourceFiles in modDesc.xml)

local PlayerSpeedListener = {}

function PlayerSpeedListener:loadMap()
	g_playerSpeed = PlayerSpeed.new()
end

function PlayerSpeedListener:deleteMap()
	if g_playerSpeed ~= nil then
		g_playerSpeed:delete()
		g_playerSpeed = nil
	end
end

function PlayerSpeedListener:update(dt)
	if g_playerSpeed ~= nil then
		g_playerSpeed:update(dt)
	end
end

addModEventListener(PlayerSpeedListener)
