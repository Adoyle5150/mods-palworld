-- main.lua (inside PalColiseum/scripts) - Main file for the Ranked Coliseum mod
-- ================================================

-- Dependencies
-- Accesses the global instance of PalCentralCore, which must be initialized first by its own mod.
local PalCentralCore = _G.PalCentralCoreInstance 

-- Requires other modules WITHIN THE SAME 'PalColiseum/scripts' FOLDER
-- UE4SS will configure package.path so that 'require("ranked_system")' finds 'ranked_system.lua'
local RankedSystem = require("ranked_system") 
local BattleManager = require("battle_manager")
local UIManager = require("ui_manager")

-- Mod configuration
local ModConfig = {
    name = "Ranked Coliseum",
    version = "1.0.0",
    max_level = 50,
    server_side = true
}

-- Mod initialization
local function InitializeMod()
    -- Check if PalCentralCore is available before using it
    if not PalCentralCore then
        print("[Ranked Coliseum][FATAL ERROR] PalCentralCoreInstance not available. Check the load order in mods.txt!")
        return
    end

    PalCentralCore:Log("[Ranked Coliseum] Initializing mod...", "INFO")
    
    -- Register Unreal Engine events
    RegisterHook("/Script/Pal.PalPlayerCharacter:BeginPlay", function(self)
        -- `self` here is the PalPlayerCharacter object
        -- We need to check if it is valid and if we can get the ID and Name
        if PalCentralCore then
            PalCentralCore:Log("[Ranked Coliseum] Player connected - PalCentralCore available: " .. tostring(PalCentralCore ~= nil), "DEBUG")
            -- For the initial test, let's just print the player's ID if it's valid
            local playerID = self:GetPlayerID() -- Assumes GetPlayerID() exists and works
            local playerName = self:GetPlayerName() -- Assumes GetPlayerName() exists and works
            if playerID then
                PalCentralCore:Log("Player connected: " .. tostring(playerName) .. " (ID: " .. tostring(playerID) .. ")", "INFO")
                RankedSystem.RegisterPlayer(self, PalCentralCore) -- Pass PalCentralCore as an argument
            else
                PalCentralCore:Log("Player connected, but unable to retrieve PlayerID/Name.", "WARN")
            end
        end
    end)

    -- Hook for battle detection (Still in testing/discovery phase for exact hook names)
    -- These hooks may not trigger in all game versions or for all battle types.
    RegisterHook("/Script/Pal.PalBattleManager:StartBattle", function(self, context)
        if PalCentralCore then
            PalCentralCore:Log("[Ranked Coliseum] Battle started (Hook BattleManager:StartBattle)", "DEBUG")
            BattleManager.OnBattleStart(context, PalCentralCore, RankedSystem) -- Pass dependencies
        end
    end)

    -- Hook for battle end
    RegisterHook("/Script/Pal.PalBattleManager:EndBattle", function(self, result)
        if PalCentralCore then
            PalCentralCore:Log("[Ranked Coliseum] Battle ended (Hook BattleManager:EndBattle)", "DEBUG")
            BattleManager.OnBattleEnd(result, PalCentralCore, RankedSystem) -- Pass dependencies
        end
    end)
    
    -- Initialize systems
    RankedSystem.Initialize(PalCentralCore) -- Pass PalCentralCore
    BattleManager.Initialize(PalCentralCore, RankedSystem) -- Will error if BattleManager lacks the function
    UIManager.Initialize(PalCentralCore, RankedSystem)     -- Will error if UIManager lacks the function
    
    PalCentralCore:Log("[Ranked Coliseum] Mod loaded successfully!", "INFO")
end

-- Exports the initialization function to be called by _PalCentralCore\scripts\main.lua
-- (If this is the main entry point for the Coliseum mod, it will be called automatically by UE4SS
-- if `PalColiseum = 1` in mods.txt. The `InitializeMod()` line below calls it).
InitializeMod()

return {} -- Does not return a module here if it is the main file