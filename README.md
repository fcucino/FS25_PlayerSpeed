# FS25_PlayerSpeed
Player Speed mod for Farming Simulator 25

## Download!
To play Player Speed Mod, please download from the Giants ModHub: [https://www.farming-simulator.com/mod.php?mod_id=307750&title=fs2025](https://www.farming-simulator.com/mod.php?mod_id=307750&title=fs2025). 

## Warning!
You are looking at the ***DEVELOPMENT VERSION*** of the Player Speed Mod.  
This development version might break your game.

## How it works
Hit `V` key to reduce the player speed.

Hit `B` key to increase the player speed.


## Custom speeds
At the first start the mod creates `modSettings/FS25_PlayerSpeed.xml` in the game's user folder (e.g. `Documents/My Games/FarmingSimulator2025/modSettings/`).

```xml
<playerSpeed>
    <ratios>
        <ratio value="0.2"/>
        <ratio value="0.5"/>
        <ratio value="0.7"/>
        <ratio value="1"/>
        <ratio value="3"/>
        <ratio value="8"/>
        <ratio value="15"/>
    </ratios>
    <lastRatio value="1"/>
</playerSpeed>
```

- `ratios`: the selectable speeds. The file starts with the default ones (`0.2 0.5 0.7 1 3 8 15`); edit, add or remove them freely. Up to 10 values, each greater than 0 and at most 100, rounded to 1 decimal; invalid values and those after the 10th are skipped with a warning in `log.txt`. If the file is not valid XML, the default speeds are used, an error is written to `log.txt` and the file is not overwritten. Without any valid value, the default speeds are used.
- `lastRatio`: the last selected speed. It is stored when you save the game (multiplayer clients: when leaving the game) and restored at the next start.

## For mod authors
PlayerSpeed publishes `MessageType.PLAYER_SPEED_CHANGED` through `g_messageCenter` whenever the ratio applied to the local farmer changes, with two arguments:
- `isHandling`: `true` when PlayerSpeed changes the farmer speed (ratio other than 1). It is `false` at the standard speed, while the game's super speed is on (PlayerSpeed pauses then) and when the savegame is closed.
- `ratio`: the applied ratio (1 when not handling).

```lua
-- PlayerSpeed may not be installed
if MessageType.PLAYER_SPEED_CHANGED ~= nil then
    g_messageCenter:subscribe(MessageType.PLAYER_SPEED_CHANGED, function(self, isHandling, ratio)
        -- ...
    end, myObject)
end
-- unsubscribe when your object is deleted: g_messageCenter:unsubscribeAll(myObject)
```

The current state can also be read directly, while a savegame is loaded:

```lua
local playerSpeed = FS25_PlayerSpeed ~= nil and FS25_PlayerSpeed.g_playerSpeed
if playerSpeed ~= nil and playerSpeed:getIsHandlingSpeed() then
    local ratio = playerSpeed:getRatio()
end
```
