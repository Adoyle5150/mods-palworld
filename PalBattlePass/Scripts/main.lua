-- ================================================
-- PALWORLD BATTLE PASS SYSTEM
-- Version: 1.0.0
-- Description: Seasonal ranked battle progression system
-- ================================================

print("[PalBattlePass] 🏆 Loading Battle Pass System v1.0.0...")

-- ================================================
-- GLOBAL CONFIGURATION
-- ================================================
-- Global configuration that all modules can access
_G.PALBP_CONFIG = {
    MOD_VERSION = "1.0.0",
    DEBUG_MODE = true,
    SERVER_SIDE = true,
    CHAT_PREFIX = "[BATTLE PASS]",
    
    -- Season Configuration
    CURRENT_SEASON = {
        id = "Season_Winter_2025",
        name = "❄️ Winter Conquest",
        start_date = os.time(),
        end_date = os.time() + (90 * 24 * 60 * 60), -- 90 days
        max_tiers = 50,
        epic_reward_wins = 100,
        description = "Prove your dominance in the frozen battlegrounds!"
    }
}

-- Global tier configuration
_G.PALBP_TIER_CONFIG = {
    -- Wins required for each tier (progressive system)
    REQUIREMENTS = {
        [1] = 2,    [2] = 4,    [3] = 7,    [4] = 10,   [5] = 14,
        [6] = 18,   [7] = 23,   [8] = 28,   [9] = 34,   [10] = 40,
        [11] = 47,  [12] = 54,  [13] = 62,  [14] = 70,  [15] = 79,
        [16] = 88,  [17] = 98,  [18] = 108, [19] = 119, [20] = 130,
        [21] = 142, [22] = 154, [23] = 167, [24] = 180, [25] = 194,
        [26] = 208, [27] = 223, [28] = 238, [29] = 254, [30] = 270,
        [31] = 287, [32] = 304, [33] = 322, [34] = 340, [35] = 359,
        [36] = 378, [37] = 398, [38] = 418, [39] = 439, [40] = 460,
        [41] = 482, [42] = 504, [43] = 527, [44] = 550, [45] = 574,
        [46] = 598, [47] = 623, [48] = 648, [49] = 674, [50] = 700
    },
    
    -- Epic rewards configuration
    REWARDS = {
        -- Early tiers (1-10) - Basic rewards
        [1] = {type = "pal_souls", rarity = "small", amount = 3, name = "Pal Soul Cache"},
        [2] = {type = "gold", amount = 5000, name = "Victory Bonus"},
        [3] = {type = "pal_souls", rarity = "small", amount = 5, name = "Enhanced Soul Cache"},
        [4] = {type = "ancient_parts", amount = 2, name = "Ancient Fragments"},
        [5] = {type = "title", title = "Apprentice Warrior", name = "🗡️ Title: Apprentice Warrior"},
        
        -- Mid tiers (10-25) - Good rewards
        [10] = {type = "pal_souls", rarity = "medium", amount = 3, name = "Medium Soul Cache"},
        [15] = {type = "legendary_pal", species = "Shadowbeak", passives = {"Swift"}, name = "🦅 Legendary Shadowbeak"},
        [20] = {type = "title", title = "Battle Veteran", name = "⚔️ Title: Battle Veteran"},
        [25] = {type = "ancient_parts", amount = 10, name = "Ancient Relic Bundle"},
        
        -- High tiers (25-40) - Great rewards  
        [30] = {type = "pal_souls", rarity = "large", amount = 2, name = "Large Soul Cache"},
        [35] = {type = "legendary_pal", species = "Paladius", passives = {"Swift", "Ferocious"}, name = "🛡️ Legendary Paladius"},
        [40] = {type = "title", title = "Elite Commander", name = "👑 Title: Elite Commander"},
        
        -- Final tiers (40-50) - Epic rewards
        [45] = {type = "pal_souls", rarity = "large", amount = 5, name = "Epic Soul Hoard"},
        [50] = {type = "seasonal_exclusive", item = "WinterConqueror_Crown", name = "❄️ Winter Conqueror's Crown"},
        
        -- Ultimate reward (100 wins)
        [100] = {type = "ultimate_reward", 
                item = "SeasonalLegendPal", 
                name = "🌟 ULTIMATE: Seasonal Legend Pal",
                description = "An exclusive Pal that can never be obtained again!"},
    }
}

local PalBattlePass = {}
PalBattlePass.__index = PalBattlePass

-- Dependencies
local PalCentralCore
-- Note: JSON handling done manually to avoid dependency issues

-- ================================================
-- CONFIGURATION (Access global config)
-- ================================================
local CONFIG = _G.PALBP_CONFIG
local TIER_CONFIG = _G.PALBP_TIER_CONFIG

-- ================================================
-- CORE BATTLE PASS DATA STRUCTURE
-- ================================================
local PLAYER_BP_STRUCTURE = {
    season_id = "",
    ranked_wins = 0,
    current_tier = 0,
    claimed_tiers = {},
    epic_claimed = false,
    season_join_date = 0,
    last_battle_time = 0,
    total_battles = 0,
    win_streak = 0,
    best_win_streak = 0,
    last_updated = 0
}

-- ================================================
-- INITIALIZATION & DEPENDENCY LOADING
-- ================================================
function PalBattlePass:Initialize()
    self:Log("Initializing Battle Pass System...")
    
    -- Wait for PalCentralCore dependency
    if not self:WaitForDependencies() then
        self:Log("Failed to load dependencies!", "ERROR")
        return false
    end
    
    -- Initialize data structures
    self:InitializeData()
    
    -- Register chat commands
    if not self:RegisterCommands() then
        self:Log("Failed to register commands!", "ERROR")
        return false
    end
    
    -- Register battle hooks
    if not self:RegisterBattleHooks() then
        self:Log("Failed to register battle hooks!", "ERROR")
        return false
    end
    
    -- Load rewards system
    if not self:LoadRewardsSystem() then
        self:Log("Failed to load rewards system!", "ERROR")
        return false
    end
    
    self:Log("Battle Pass System initialized successfully! Season: " .. CONFIG.CURRENT_SEASON.name)
    return true
end

function PalBattlePass:WaitForDependencies()
    local attempts = 0
    local max_attempts = 30
    
    while attempts < max_attempts do
        -- Check for direct global instance first
        if _G.PalCentralCoreInstance then
            PalCentralCore = _G.PalCentralCoreInstance
            self:Log("PalCentralCore dependency loaded!")
            return true
        end
        
        -- Check for file-based communication (same method other mods use)
        local success, instance = pcall(function()
            return dofile("palcentral_instance.lua")
        end)
        
        if success and instance and type(instance) == "table" then
            PalCentralCore = instance
            _G.PalCentralCoreInstance = instance  -- Set global for consistency
            self:Log("Found via file-based communication (palcentral_instance.lua)")
            self:Log("PalCentralCore dependency loaded!")
            return true
        end
        
        attempts = attempts + 1
        self:Log("Waiting for PalCentralCore... (" .. attempts .. "/" .. max_attempts .. ")")
        
        -- Simple delay using os.clock (more reliable than ExecuteAsync)
        local start_time = os.clock()
        while os.clock() - start_time < 0.5 do
            -- Brief wait between attempts
        end
    end
    
    return false
end

-- ================================================
-- DATA MANAGEMENT
-- ================================================
function PalBattlePass:InitializeData()
    -- Debug: Check what's available in PalCentralCore
    self:Log("Checking PalCentralCore structure...")
    
    if PalCentralCore then
        -- Log available methods and properties
        local methods = {}
        for key, value in pairs(PalCentralCore) do
            if type(value) == "function" then
                table.insert(methods, key)
            end
        end
        self:Log("Available methods: " .. table.concat(methods, ", "))
        
        -- Check if data exists
        if PalCentralCore.data then
            self:Log("PalCentralCore.data exists")
        else
            self:Log("PalCentralCore.data is nil - attempting to initialize...")
            PalCentralCore.data = {}
        end
    end
    
    -- Ensure battle pass data structure exists in PalCentralCore
    if not PalCentralCore.data then
        PalCentralCore.data = {}
    end
    
    if not PalCentralCore.data.battle_pass then
        PalCentralCore.data.battle_pass = {
            current_season = CONFIG.CURRENT_SEASON,
            season_stats = {
                total_players = 0,
                total_battles = 0,
                rewards_claimed = 0
            },
            leaderboard = {}
        }
        
        -- Try to save data if SaveData method exists
        if PalCentralCore.SaveData and type(PalCentralCore.SaveData) == "function" then
            local success, err = pcall(function()
                PalCentralCore:SaveData()
            end)
            
            if success then
                self:Log("Battle Pass data structure created and saved!")
            else
                self:Log("Battle Pass data created but save failed: " .. tostring(err), "WARN")
            end
        else
            self:Log("Battle Pass data structure created (SaveData method not available)")
        end
    end
end

function PalBattlePass:GetPlayerBattlePass(playerID)
    -- Ensure data structure exists
    if not PalCentralCore.data then
        PalCentralCore.data = {}
    end
    
    if not PalCentralCore.data.players then
        PalCentralCore.data.players = {}
    end
    
    -- Ensure player exists in PalCentralCore
    if not PalCentralCore.data.players[playerID] then
        PalCentralCore.data.players[playerID] = {}
    end
    
    -- Initialize battle pass data if missing
    if not PalCentralCore.data.players[playerID].battle_pass then
        PalCentralCore.data.players[playerID].battle_pass = {
            season_id = CONFIG.CURRENT_SEASON.id,
            ranked_wins = 0,
            current_tier = 0,
            claimed_tiers = {},
            epic_claimed = false,
            season_join_date = os.time(),
            last_battle_time = 0,
            total_battles = 0,
            win_streak = 0,
            best_win_streak = 0,
            last_updated = os.time()
        }
        
        -- Track new player (safely)
        if PalCentralCore.data.battle_pass and PalCentralCore.data.battle_pass.season_stats then
            PalCentralCore.data.battle_pass.season_stats.total_players = 
                (PalCentralCore.data.battle_pass.season_stats.total_players or 0) + 1
        end
            
        self:Log("New Battle Pass player initialized: " .. tostring(playerID))
    end
    
    return PalCentralCore.data.players[playerID].battle_pass
end

-- ================================================
-- TIER CALCULATION & PROGRESSION
-- ================================================
function PalBattlePass:CalculateTierFromWins(wins)
    local tier = 0
    for t = 1, CONFIG.CURRENT_SEASON.max_tiers do
        if wins >= TIER_CONFIG.REQUIREMENTS[t] then
            tier = t
        else
            break
        end
    end
    return tier
end

function PalBattlePass:GetNextTierRequirement(currentTier)
    if currentTier >= CONFIG.CURRENT_SEASON.max_tiers then
        return CONFIG.CURRENT_SEASON.epic_reward_wins -- Epic reward requirement
    end
    return TIER_CONFIG.REQUIREMENTS[currentTier + 1] or 0
end

function PalBattlePass:GetUnclaimedTiers(playerBP)
    local unclaimed = {}
    for tier = 1, playerBP.current_tier do
        if TIER_CONFIG.REWARDS[tier] and not self:IsTierClaimed(playerBP, tier) then
            table.insert(unclaimed, tier)
        end
    end
    
    -- Check epic reward
    if playerBP.ranked_wins >= CONFIG.CURRENT_SEASON.epic_reward_wins and not playerBP.epic_claimed then
        table.insert(unclaimed, 100) -- Special tier for epic reward
    end
    
    return unclaimed
end

function PalBattlePass:IsTierClaimed(playerBP, tier)
    for _, claimedTier in ipairs(playerBP.claimed_tiers) do
        if claimedTier == tier then
            return true
        end
    end
    return false
end

-- ================================================
-- LOGGING SYSTEM
-- ================================================
function PalBattlePass:Log(message, level)
    level = level or "INFO"
    local timestamp = os.date("%H:%M:%S")
    print(string.format("[%s] [PalBattlePass] [%s] %s", timestamp, level, message))
end

-- ================================================
-- INTEGRATION WITH OTHER MODULES
-- ================================================
function PalBattlePass:RegisterCommands()
    -- Load commands module
    local success, commandsModule = pcall(require, "commands")
    if not success then
        self:Log("Failed to load commands module: " .. tostring(commandsModule), "ERROR")
        return false
    end
    self.Commands = commandsModule
    
    -- Method 1: Register with PalDefender whitelist (if available)
    self:RegisterWithPalDefender()
    
    -- Method 2: Hook into chat system for multiple command formats
    if RegisterHook and FindFirstOf then
        local success, err = pcall(function()
            -- Hook into chat system - handles multiple formats to bypass PalDefender
            RegisterHook("/Script/Engine.PlayerController:ServerSay", function(PlayerController, message)
                if not message or type(message) ~= "string" then return end
                
                local command, args = self:ParseChatCommand(message)
                if command then
                    local playerID = self:GetPlayerIDFromController(PlayerController)
                    if playerID then
                        self.Commands:HandleCommand(playerID, command, args)
                    end
                end
            end)
        end)
        
        if success then
            self:Log("Chat commands registered successfully!")
        else
            self:Log("Failed to register chat commands: " .. tostring(err), "ERROR")
        end
    else
        self:Log("UE4SS hook functions not available. Chat commands disabled.", "WARN")
    end
    
    -- Method 3: Register global function for console access
    _G.BattlePassCommand = function(playerID, command, ...)
        local args = {...}
        if _G.PalBattlePassInstance and _G.PalBattlePassInstance.Commands then
            _G.PalBattlePassInstance.Commands:HandleCommand(playerID or "console", command or "bp", args)
        else
            print("[BattlePassCommand] System not ready yet!")
        end
    end
    
    self:Log("Multiple command access methods registered (chat, PalDefender, console)")
    return true
end

function PalBattlePass:RegisterBattleHooks()
    -- Load integration module
    local success, integrationModule = pcall(require, "integration")
    if not success then
        self:Log("Failed to load integration module: " .. tostring(integrationModule), "ERROR")
        return false
    end
    self.Integration = integrationModule
    
    -- Register battle tracking
    self.Integration:RegisterBattleHooks()
    return true
end

function PalBattlePass:LoadRewardsSystem()
    local success, rewardsModule = pcall(require, "rewards")
    if not success then
        self:Log("Failed to load rewards module: " .. tostring(rewardsModule), "ERROR")
        return false
    end
    
    self.Rewards = rewardsModule
    
    -- Connect rewards to commands with better error handling
    if self.Commands then
        self.Commands.GiveRewardToPlayer = function(cmdSelf, playerID, reward)
            if rewardsModule and rewardsModule.ProcessReward then
                return rewardsModule:ProcessReward(playerID, reward)
            else
                self:Log("Rewards module not available for reward: " .. tostring(reward.name), "ERROR")
                return false
            end
        end
        self:Log("Rewards system connected to commands successfully!")
    else
        self:Log("Commands module not available - cannot connect rewards", "ERROR")
        return false
    end
    
    return true
end

-- ================================================
-- PALDEFENDER INTEGRATION
-- ================================================
function PalBattlePass:RegisterWithPalDefender()
    -- Try to register battle pass commands with PalDefender whitelist
    if _G.PalDefenderInstance then
        local success = pcall(function()
            -- Register battle pass commands as safe/whitelisted
            _G.PalDefenderInstance:RegisterSafeCommand("bp", "Battle Pass commands")
            _G.PalDefenderInstance:RegisterSafeCommand("battlepass", "Battle Pass commands")
            _G.PalDefenderInstance:RegisterSafeCommand("bphelp", "Battle Pass help")
            
            self:Log("Successfully registered with PalDefender whitelist!")
        end)
        
        if not success then
            self:Log("Failed to register with PalDefender - will use alternative methods", "WARN")
        end
    else
        self:Log("PalDefender not found - using standard command handling")
    end
end

-- ================================================
-- CHAT COMMAND PARSING
-- ================================================
function PalBattlePass:ParseChatCommand(message)
    if not message or type(message) ~= "string" then
        return nil, nil
    end
    
    -- Remove leading/trailing whitespace
    message = message:match("^%s*(.-)%s*$")
    
    -- Support multiple command formats to bypass PalDefender
    local command_text = nil
    
    -- Format 1: Standard slash commands (/bp)
    if message:match("^/") then
        command_text = message:sub(2)
    -- Format 2: Exclamation commands (!bp) - common alternative
    elseif message:match("^!") then
        command_text = message:sub(2)
    -- Format 3: Dot commands (.bp) - another alternative
    elseif message:match("^%.") then
        command_text = message:sub(2)
    -- Format 4: Plain word commands (bp, battlepass) - most PalDefender-friendly
    elseif message:match("^(bp|battlepass|bphelp)%s") or message:match("^(bp|battlepass|bphelp)$") then
        command_text = message
    else
        return nil, nil
    end
    
    -- Split into command and arguments
    local parts = {}
    for part in command_text:gmatch("%S+") do
        table.insert(parts, part)
    end
    
    if #parts == 0 then
        return nil, nil
    end
    
    local command = parts[1]
    local args = {}
    for i = 2, #parts do
        table.insert(args, parts[i])
    end
    
    -- Only handle battle pass commands
    if command == "bp" or command == "battlepass" or command == "bphelp" then
        return command, args
    end
    
    return nil, nil
end

function PalBattlePass:GetPlayerIDFromController(PlayerController)
    -- This would extract the player ID from the UE4 PlayerController
    -- Implementation depends on your specific setup
    
    if not PlayerController then
        return nil
    end
    
    -- Try to get player ID (this is a placeholder - adjust for your system)
    local success, playerID = pcall(function()
        if PlayerController.GetPawn then
            local pawn = PlayerController:GetPawn()
            if pawn and pawn.GetPlayerID then
                return pawn:GetPlayerID()
            end
        end
        
        -- Alternative: use controller's unique ID
        if PlayerController.GetUniqueID then
            return tostring(PlayerController:GetUniqueID())
        end
        
        return nil
    end)
    
    if success and playerID then
        return playerID
    end
    
    -- Fallback: use memory address as ID (not ideal but works for testing)
    return tostring(PlayerController)
end

-- ================================================
-- PUBLIC API FOR EXTERNAL MODS
-- ================================================

-- Allow other mods to register battle wins
function PalBattlePass:RegisterRankedWin(playerID, isValid)
    if not self.Integration then
        self:Log("Integration module not loaded!", "ERROR")
        return false
    end
    
    return self.Integration:RegisterManualWin(playerID, isValid)
end

-- Get player's battle pass status
function PalBattlePass:GetPlayerStatus(playerID)
    local bp = self:GetPlayerBattlePass(playerID)
    return {
        season = CONFIG.CURRENT_SEASON.name,
        wins = bp.ranked_wins,
        tier = bp.current_tier,
        max_tier = CONFIG.CURRENT_SEASON.max_tiers,
        unclaimed_rewards = #self:GetUnclaimedTiers(bp),
        win_streak = bp.win_streak,
        epic_unlocked = bp.ranked_wins >= CONFIG.CURRENT_SEASON.epic_reward_wins,
        epic_claimed = bp.epic_claimed
    }
end

-- ================================================
-- MODULE INITIALIZATION & STARTUP
-- ================================================
local success = PalBattlePass:Initialize()
if success then
    print("[PalBattlePass] 🏆 Battle Pass System loaded successfully!")
    print("[PalBattlePass] 🎮 Season: " .. CONFIG.CURRENT_SEASON.name)
    print("[PalBattlePass] 📊 Max Tiers: " .. CONFIG.CURRENT_SEASON.max_tiers)
    print("[PalBattlePass] 🌟 Epic Reward: " .. CONFIG.CURRENT_SEASON.epic_reward_wins .. " wins")
    print("[PalBattlePass] 💬 Players can use 'bp', '/bp', '!bp', or '.bp' to get started!")
    print("[PalBattlePass] 🛡️ Compatible with PalDefender - no registration required!")
    
    -- Export globally for other mods to access
    _G.PalBattlePassInstance = PalBattlePass
    
    -- Create simple test function
    _G.TestBattlePass = function()
        print("=== BATTLE PASS TEST ===")
        print("System exists:", _G.PalBattlePassInstance and "YES" or "NO")
        print("Commands exists:", _G.PalBattlePassInstance and _G.PalBattlePassInstance.Commands and "YES" or "NO")
        print("Rewards exists:", _G.PalBattlePassInstance and _G.PalBattlePassInstance.Rewards and "YES" or "NO")
        print("BattlePassCommand exists:", _G.BattlePassCommand and "YES" or "NO")
        
        if _G.PalBattlePassInstance and _G.PalBattlePassInstance.Commands then
            print("Testing status command...")
            _G.PalBattlePassInstance.Commands:HandleCommand("test_player", "bp", {})
            
            print("\nTesting help command...")
            _G.PalBattlePassInstance.Commands:HandleCommand("test_player", "bphelp", {})
            
            -- Test rewards connection
            if _G.PalBattlePassInstance.Commands.GiveRewardToPlayer then
                print("\nTesting rewards connection...")
                local testReward = {type = "gold", amount = 1000, name = "Test Gold"}
                local success = _G.PalBattlePassInstance.Commands:GiveRewardToPlayer("test_player", testReward)
                print("Reward test result:", success and "SUCCESS" or "FAILED")
            else
                print("\nRewards connection: NOT FOUND")
            end
        else
            print("System not ready for testing")
        end
        print("=== TEST COMPLETE ===")
    end
    
    print("[PalBattlePass] Global instance created and available!")
    print("[PalBattlePass] Instance verification: _G.PalBattlePassInstance =", _G.PalBattlePassInstance and "FOUND" or "NOT FOUND")
    print("[PalBattlePass] 🔧 Admin Console: Use TestBattlePass() or BattlePassCommand(playerID, 'bp') for testing")
else
    print("[PalBattlePass] ❌ Failed to initialize Battle Pass System!")
end

return PalBattlePass 