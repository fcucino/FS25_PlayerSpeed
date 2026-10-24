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
