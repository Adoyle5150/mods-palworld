-- Dependencies (loaded later)
local PalCentralCore
local RankedSystem
local BattleManager
local UIManager

local ModConfig = {
    name = "Ranked Coliseum",
    version = "1.0.0",
    max_level = 50,
    server_side = true
}

-- More reliable waiting function
local function WaitForPalCentralCore()
    local attempts = 0
    local max_attempts = 60 -- Wait up to 60 seconds
    
    while attempts < max_attempts do
        -- Try multiple methods to find PalCentralCore (check each explicitly)
        local core = nil
        if _G.PalCentralCoreInstance then
            core = _G.PalCentralCoreInstance
            print("[Ranked Coliseum] Found via _G.PalCentralCoreInstance")
        elseif package.loaded["PalCentralCoreInstance"] then
            core = package.loaded["PalCentralCoreInstance"]
            print("[Ranked Coliseum] Found via package.loaded['PalCentralCoreInstance']")
        elseif package.loaded["PalCentralCore"] then
            core = package.loaded["PalCentralCore"]
            print("[Ranked Coliseum] Found via package.loaded['PalCentralCore']")
        else
            -- Try file-based approach
            local success, file_core = pcall(dofile, "palcentral_instance.lua")
            if success and file_core then
                core = file_core
                print("[Ranked Coliseum] Found via file-based communication (palcentral_instance.lua)")
            end
        end
        
        -- Check if PalCentralCore instance exists and is properly initialized
        if core and core.data then
            print("[Ranked Coliseum] PalCentralCore found and ready!")
            -- Update global reference for consistency
            _G.PalCentralCoreInstance = core
            return true
        end
        
        print("[Ranked Coliseum] Waiting for PalCentralCoreInstance... (" .. attempts .. "/" .. max_attempts .. ")")
        
        -- More reliable sleep using ExecuteAsync if available, otherwise use fallback
        if ExecuteAsync then
            ExecuteAsync(function()
                -- Short delay
                local start = os.clock()
                while os.clock() - start < 1 do end
            end)
        else
            -- Fallback delay method
            local start = os.clock()
            while os.clock() - start < 1 do
                -- Busy wait for 1 second
            end
        end
        
        attempts = attempts + 1
    end
    
    print("[Ranked Coliseum] ERROR: PalCentralCoreInstance not found after " .. max_attempts .. " seconds.")
    print("[Ranked Coliseum] Available globals: ")
    for k, v in pairs(_G) do
        if string.find(k, "Pal") then
            print("  - " .. k .. " = " .. tostring(v))
        end
    end
    
    return false
end

-- Wait for PalCentralCore to be ready
if WaitForPalCentralCore() then
    local PalCentralCore = _G.PalCentralCoreInstance
    
    -- Load other dependencies
    local success, RankedSystem = pcall(require, "ranked_system")
    if not success then
        print("[Ranked Coliseum] ERROR: Failed to load ranked_system: " .. tostring(RankedSystem))
        return {}
    end
    
    local success, BattleManager = pcall(require, "battle_manager")
    if not success then
        print("[Ranked Coliseum] ERROR: Failed to load battle_manager: " .. tostring(BattleManager))
        return {}
    end
    
    local success, UIManager = pcall(require, "ui_manager")
    if not success then
        print("[Ranked Coliseum] ERROR: Failed to load ui_manager: " .. tostring(UIManager))
        return {}
    end

    -- Detect if running on dedicated server (check for server globals or lack of client ones)
    local is_server = ModConfig.server_side or not FindObject("/Script/Pal.PalPlayerCharacter")  -- If client class not found, assume server

    -- Register hooks only after all dependencies are loaded
    if not is_server then
        -- Client-side hook
        local success, err = pcall(RegisterHook, "/Script/Pal.PalPlayerCharacter:BeginPlay", function(self)
            local playerID = self:GetPlayerID()
            local playerName = self:GetPlayerName()
            if playerID then
                PalCentralCore:Log("Player connected: " .. tostring(playerName) .. " (ID: " .. tostring(playerID) .. ")", "INFO")
                RankedSystem.RegisterPlayer(self, PalCentralCore)
            else
                PalCentralCore:Log("Player connected, but failed to get PlayerID/Name.", "WARN")
            end
        end)
        if not success then
            print("[Ranked Coliseum] WARNING: Failed to register BeginPlay hook (client-only?): " .. tostring(err))
        end
    end

    -- Battle hooks (should work on server)
    local success, err = pcall(RegisterHook, "/Script/Pal.PalBattleManager:StartBattle", function(self, context)
        PalCentralCore:Log("[Ranked Coliseum] Battle started", "DEBUG")
        BattleManager.OnBattleStart(context, PalCentralCore, RankedSystem)
    end)
    if not success then
        print("[Ranked Coliseum] WARNING: Failed to register StartBattle hook: " .. tostring(err))
    end

    local success, err = pcall(RegisterHook, "/Script/Pal.PalBattleManager:EndBattle", function(self, result)
        PalCentralCore:Log("[Ranked Coliseum] Battle ended", "DEBUG")
        BattleManager.OnBattleEnd(result, PalCentralCore, RankedSystem)
    end)
    if not success then
        print("[Ranked Coliseum] WARNING: Failed to register EndBattle hook: " .. tostring(err))
    end

    -- Initialize all systems
    local init_success = true
    
    if not pcall(RankedSystem.Initialize, PalCentralCore) then
        print("[Ranked Coliseum] ERROR: Failed to initialize RankedSystem")
        init_success = false
    end
    
    if not pcall(BattleManager.Initialize, PalCentralCore, RankedSystem) then
        print("[Ranked Coliseum] ERROR: Failed to initialize BattleManager")
        init_success = false
    end
    
    if not pcall(UIManager.Initialize, PalCentralCore, RankedSystem) then
        print("[Ranked Coliseum] ERROR: Failed to initialize UIManager")
        init_success = false
    end
    
    if init_success then
        PalCentralCore:Log("[Ranked Coliseum] Mod loaded successfully!", "INFO")
    else
        print("[Ranked Coliseum] WARNING: Some components failed to initialize properly.")
    end
else
    print("[Ranked Coliseum] CRITICAL ERROR: Cannot function without PalCentralCore. Mod disabled.")
end

return {}

