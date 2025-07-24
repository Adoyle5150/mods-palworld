-- ================================================
-- PALWORLD BATTLE PASS - INTEGRATION MODULE
-- Handles battle detection and win registration
-- ================================================

local Integration = {}
Integration.__index = Integration

-- Access global configuration
local CONFIG = _G.PALBP_CONFIG
local TIER_CONFIG = _G.PALBP_TIER_CONFIG

-- ================================================
-- BATTLE DETECTION SYSTEM
-- ================================================
Integration.activeBattles = {}
Integration.recentWins = {}
Integration.battleHooks = {}

function Integration:Log(message, level)
    level = level or "INFO"
    local timestamp = os.date("%H:%M:%S")
    print(string.format("[%s] [PalBattlePass-Integration] [%s] %s", timestamp, level, message))
end

-- ================================================
-- UE4SS HOOK REGISTRATION
-- ================================================
function Integration:RegisterBattleHooks()
    self:Log("Registering battle detection hooks...")
    
    -- Try multiple methods to detect battles
    self:RegisterPvPHooks()
    self:RegisterPalBattleHooks()
    self:RegisterDamageHooks()
    
    self:Log("Battle hooks registration completed!")
end

function Integration:RegisterPvPHooks()
    if not (RegisterHook and FindFirstOf) then
        self:Log("UE4SS functions not available for PvP hooks", "WARN")
        return
    end
    
    local success = pcall(function()
        -- Hook into player vs player combat initiation
        RegisterHook("/Script/Pal.PalPlayerCharacter:StartCombat", function(PlayerCharacter, Target)
            if PlayerCharacter and Target then
                self:OnCombatStart(PlayerCharacter, Target)
            end
        end)
        
        -- Hook into combat end/victory
        RegisterHook("/Script/Pal.PalPlayerCharacter:EndCombat", function(PlayerCharacter, Result)
            if PlayerCharacter and Result then
                self:OnCombatEnd(PlayerCharacter, Result)
            end
        end)
        
        -- Hook into player defeat events
        RegisterHook("/Script/Pal.PalPlayerCharacter:OnDeath", function(PlayerCharacter, Killer)
            if PlayerCharacter and Killer then
                self:OnPlayerDefeat(PlayerCharacter, Killer)
            end
        end)
    end)
    
    if success then
        self:Log("PvP combat hooks registered successfully!")
    else
        self:Log("Failed to register PvP hooks - using alternative detection", "WARN")
    end
end

function Integration:RegisterPalBattleHooks()
    if not (RegisterHook and FindFirstOf) then
        return
    end
    
    local success = pcall(function()
        -- Hook into Pal battle results (for Pal vs Pal combat)
        RegisterHook("/Script/Pal.PalIndividualCharacterHandle:OnBattleResult", function(PalHandle, Winner, Loser)
            if PalHandle and Winner and Loser then
                self:OnPalBattleResult(PalHandle, Winner, Loser)
            end
        end)
        
        -- Hook into capture events (successful Pal captures in PvP)
        RegisterHook("/Script/Pal.PalCaptureManager:OnCaptureSuccess", function(CaptureManager, CapturedPal, Capturer)
            if CapturedPal and Capturer then
                self:OnPalCapture(CapturedPal, Capturer)
            end
        end)
    end)
    
    if success then
        self:Log("Pal battle hooks registered successfully!")
    end
end

function Integration:RegisterDamageHooks()
    if not (RegisterHook and FindFirstOf) then
        return
    end
    
    local success = pcall(function()
        -- Hook into damage events to track combat
        RegisterHook("/Script/Pal.PalDamageReactionComponent:TakeDamage", function(DamageComponent, DamageAmount, DamageEvent, EventInstigator, DamageCauser)
            if DamageComponent and EventInstigator and DamageAmount then
                self:OnDamageDealt(DamageComponent, DamageAmount, EventInstigator, DamageCauser)
            end
        end)
    end)
    
    if success then
        self:Log("Damage tracking hooks registered!")
    end
end

-- ================================================
-- BATTLE EVENT HANDLERS
-- ================================================
function Integration:OnCombatStart(attacker, target)
    local attackerID = self:GetPlayerIDFromCharacter(attacker)
    local targetID = self:GetPlayerIDFromCharacter(target)
    
    if attackerID and targetID and attackerID ~= targetID then
        -- This is a PvP battle
        local battleID = attackerID .. "_vs_" .. targetID .. "_" .. os.time()
        
        self.activeBattles[battleID] = {
            attacker = attackerID,
            target = targetID,
            start_time = os.time(),
            participants = {attackerID, targetID},
            valid_pvp = true
        }
        
        self:Log("PvP battle started: " .. attackerID .. " vs " .. targetID)
    end
end

function Integration:OnCombatEnd(character, result)
    local playerID = self:GetPlayerIDFromCharacter(character)
    
    if not playerID then return end
    
    -- Find active battles involving this player
    for battleID, battle in pairs(self.activeBattles) do
        if battle.attacker == playerID or battle.target == playerID then
            -- Determine winner based on result
            local isWinner = self:DetermineWinner(character, result, battle)
            
            if isWinner then
                self:ProcessBattleWin(playerID, battle)
            end
            
            -- Clean up battle
            self.activeBattles[battleID] = nil
            break
        end
    end
end

function Integration:OnPlayerDefeat(defeated, killer)
    local defeatedID = self:GetPlayerIDFromCharacter(defeated)
    local killerID = self:GetPlayerIDFromCharacter(killer)
    
    if defeatedID and killerID and defeatedID ~= killerID then
        -- Find the active battle
        for battleID, battle in pairs(self.activeBattles) do
            if (battle.attacker == defeatedID and battle.target == killerID) or
               (battle.attacker == killerID and battle.target == defeatedID) then
                
                -- Killer wins the battle
                self:ProcessBattleWin(killerID, battle)
                self.activeBattles[battleID] = nil
                break
            end
        end
    end
end

function Integration:OnPalBattleResult(palHandle, winner, loser)
    -- Extract player IDs from Pal owners
    local winnerPlayerID = self:GetPlayerIDFromPal(winner)
    local loserPlayerID = self:GetPlayerIDFromPal(loser)
    
    if winnerPlayerID and loserPlayerID and winnerPlayerID ~= loserPlayerID then
        -- This is a Pal vs Pal PvP battle
        local battle = {
            attacker = winnerPlayerID,
            target = loserPlayerID,
            start_time = os.time(),
            participants = {winnerPlayerID, loserPlayerID},
            valid_pvp = true,
            battle_type = "pal_battle"
        }
        
        self:ProcessBattleWin(winnerPlayerID, battle)
        self:Log("Pal battle victory: " .. winnerPlayerID .. " defeated " .. loserPlayerID)
    end
end

function Integration:OnPalCapture(capturedPal, capturer)
    local capturerID = self:GetPlayerIDFromCharacter(capturer)
    local originalOwnerID = self:GetPlayerIDFromPal(capturedPal)
    
    if capturerID and originalOwnerID and capturerID ~= originalOwnerID then
        -- Capturing another player's Pal is a form of PvP victory
        local battle = {
            attacker = capturerID,
            target = originalOwnerID,
            start_time = os.time(),
            participants = {capturerID, originalOwnerID},
            valid_pvp = true,
            battle_type = "pal_capture"
        }
        
        self:ProcessBattleWin(capturerID, battle)
        self:Log("Pal capture victory: " .. capturerID .. " captured from " .. originalOwnerID)
    end
end

function Integration:OnDamageDealt(damageComponent, damageAmount, instigator, causer)
    -- Track damage for combat validation
    local attackerID = self:GetPlayerIDFromCharacter(instigator)
    local targetID = self:GetPlayerIDFromDamageComponent(damageComponent)
    
    if attackerID and targetID and attackerID ~= targetID then
        -- Update active battles with damage tracking
        for battleID, battle in pairs(self.activeBattles) do
            if (battle.attacker == attackerID and battle.target == targetID) or
               (battle.attacker == targetID and battle.target == attackerID) then
                
                battle.total_damage = (battle.total_damage or 0) + (damageAmount or 0)
                battle.last_damage_time = os.time()
                break
            end
        end
    end
end

-- ================================================
-- BATTLE VALIDATION & PROCESSING
-- ================================================
function Integration:ProcessBattleWin(winnerID, battle)
    -- Validate the battle
    if not self:ValidateBattle(battle) then
        self:Log("Battle validation failed for " .. winnerID, "WARN")
        return false
    end
    
    -- Prevent duplicate wins
    if self:IsRecentWin(winnerID, battle) then
        self:Log("Duplicate win prevented for " .. winnerID, "WARN")
        return false
    end
    
    -- Register the win
    return self:RegisterRankedWin(winnerID, battle)
end

function Integration:ValidateBattle(battle)
    -- Check battle duration (must be at least 30 seconds for legitimate PvP)
    local duration = os.time() - battle.start_time
    if duration < 30 then
        return false
    end
    
    -- Check if participants are different players
    if #battle.participants < 2 then
        return false
    end
    
    -- Check for damage dealt (if available)
    if battle.total_damage and battle.total_damage < 100 then
        return false -- Too little damage for legitimate battle
    end
    
    -- Additional validation rules can be added here
    return true
end

function Integration:IsRecentWin(playerID, battle)
    local recentKey = playerID .. "_" .. (battle.target or "unknown")
    local lastWinTime = self.recentWins[recentKey]
    
    if lastWinTime and (os.time() - lastWinTime) < 300 then -- 5 minute cooldown
        return true
    end
    
    self.recentWins[recentKey] = os.time()
    return false
end

function Integration:RegisterRankedWin(playerID, battle)
    local bp = _G.PalBattlePassInstance:GetPlayerBattlePass(playerID)
    
    -- Update battle pass stats
    bp.ranked_wins = bp.ranked_wins + 1
    bp.total_battles = bp.total_battles + 1
    bp.last_battle_time = os.time()
    bp.last_updated = os.time()
    
    -- Update win streak
    bp.win_streak = bp.win_streak + 1
    if bp.win_streak > bp.best_win_streak then
        bp.best_win_streak = bp.win_streak
    end
    
    -- Calculate new tier
    local oldTier = bp.current_tier
    bp.current_tier = _G.PalBattlePassInstance:CalculateTierFromWins(bp.ranked_wins)
    
    -- Update global season stats
    if _G.PalCentralCore and _G.PalCentralCore.data.battle_pass.season_stats then
        _G.PalCentralCore.data.battle_pass.season_stats.total_battles = 
            (_G.PalCentralCore.data.battle_pass.season_stats.total_battles or 0) + 1
    end
    
    self:Log("Ranked win registered for " .. playerID .. " (Total: " .. bp.ranked_wins .. ")")
    
    -- Notify player of progress
    self:NotifyPlayerProgress(playerID, bp, oldTier, battle)
    
    -- Save data
    if _G.PalCentralCore and _G.PalCentralCore.SaveData then
        pcall(function()
            _G.PalCentralCore:SaveData()
        end)
    end
    
    return true
end

function Integration:NotifyPlayerProgress(playerID, bp, oldTier, battle)
    local messages = {}
    
    -- Basic win notification
    table.insert(messages, "🏆 RANKED VICTORY! (" .. bp.ranked_wins .. " total wins)")
    
    -- Tier progression
    if bp.current_tier > oldTier then
        table.insert(messages, "🎯 TIER UP! You reached Tier " .. bp.current_tier .. "!")
        local reward = TIER_CONFIG.REWARDS[bp.current_tier]
        if reward then
            table.insert(messages, "🎁 New reward available: " .. reward.name)
        end
        table.insert(messages, "💰 Use '/bp claim' to collect rewards!")
    end
    
    -- Win streak notification
    if bp.win_streak > 1 then
        table.insert(messages, "🔥 Win Streak: " .. bp.win_streak .. " victories!")
    end
    
    -- Progress to next tier
    local nextTier = bp.current_tier + 1
    if nextTier <= CONFIG.CURRENT_SEASON.max_tiers then
        local nextReq = TIER_CONFIG.REQUIREMENTS[nextTier]
        local needed = nextReq - bp.ranked_wins
        table.insert(messages, "📈 Next tier in " .. needed .. " wins")
    elseif bp.ranked_wins < CONFIG.CURRENT_SEASON.epic_reward_wins then
        local needed = CONFIG.CURRENT_SEASON.epic_reward_wins - bp.ranked_wins
        table.insert(messages, "🌟 Epic reward in " .. needed .. " wins!")
    end
    
    -- Send notifications using the safest available method
    self:SendNotifications(playerID, messages)
end

-- Safe notification sending with multiple fallback methods
function Integration:SendNotifications(playerID, messages)
    local sent = false
    
    -- Method 1: Through main battle pass instance
    if _G.PalBattlePassInstance and _G.PalBattlePassInstance.Commands and _G.PalBattlePassInstance.Commands.SendMessage then
        local success = pcall(function()
            for _, message in ipairs(messages) do
                _G.PalBattlePassInstance.Commands:SendMessage(playerID, message)
            end
        end)
        if success then
            sent = true
        end
    end
    
    -- Method 2: Direct UE4SS chat (if available)
    if not sent and ExecuteInGameThread and FindFirstOf then
        local success = pcall(function()
            ExecuteInGameThread(function()
                local PlayerController = FindFirstOf("PlayerController")
                if PlayerController then
                    for _, message in ipairs(messages) do
                        local formattedMessage = string.format("%s %s", CONFIG.CHAT_PREFIX, message)
                        PlayerController:ClientMessage(formattedMessage)
                    end
                end
            end)
        end)
        if success then
            sent = true
        end
    end
    
    -- Method 3: Console output (always works)
    if not sent then
        for _, message in ipairs(messages) do
            print(string.format("[BP-NOTIFY] %s: %s %s", playerID, CONFIG.CHAT_PREFIX, message))
        end
    end
end

-- ================================================
-- MANUAL WIN REGISTRATION (FOR EXTERNAL MODS)
-- ================================================
function Integration:RegisterManualWin(playerID, isValid, battleData)
    if not playerID then
        self:Log("Invalid playerID for manual win registration", "ERROR")
        return false
    end
    
    -- Create a synthetic battle for validation
    local battle = battleData or {
        attacker = playerID,
        target = "manual",
        start_time = os.time() - 60, -- Fake 1 minute battle
        participants = {playerID},
        valid_pvp = isValid ~= false,
        battle_type = "manual",
        total_damage = 1000 -- Fake damage for validation
    }
    
    return self:ProcessBattleWin(playerID, battle)
end

-- ================================================
-- UTILITY FUNCTIONS
-- ================================================
function Integration:GetPlayerIDFromCharacter(character)
    if not character then return nil end
    
    local success, playerID = pcall(function()
        -- Try to get player controller
        if character.GetPlayerController then
            local controller = character:GetPlayerController()
            if controller then
                -- Try different methods to get player ID
                if controller.GetUniqueID then
                    return tostring(controller:GetUniqueID())
                elseif controller.PlayerState and controller.PlayerState.GetPlayerId then
                    return tostring(controller.PlayerState:GetPlayerId())
                end
            end
        end
        
        -- Try direct player ID method
        if character.GetPlayerID then
            return tostring(character:GetPlayerID())
        end
        
        -- Fallback to memory address
        return tostring(character)
    end)
    
    return success and playerID or nil
end

function Integration:GetPlayerIDFromPal(pal)
    if not pal then return nil end
    
    local success, playerID = pcall(function()
        -- Try to get Pal owner
        if pal.GetOwnerPlayerID then
            return tostring(pal:GetOwnerPlayerID())
        elseif pal.OwnerPlayerUID then
            return tostring(pal.OwnerPlayerUID)
        elseif pal.GetController then
            local controller = pal:GetController()
            if controller and controller.GetPlayerController then
                local playerController = controller:GetPlayerController()
                if playerController and playerController.GetUniqueID then
                    return tostring(playerController:GetUniqueID())
                end
            end
        end
        
        return nil
    end)
    
    return success and playerID or nil
end

function Integration:GetPlayerIDFromDamageComponent(damageComponent)
    if not damageComponent then return nil end
    
    local success, playerID = pcall(function()
        -- Try to get the owner of the damage component
        if damageComponent.GetOwner then
            local owner = damageComponent:GetOwner()
            if owner then
                return self:GetPlayerIDFromCharacter(owner)
            end
        end
        
        return nil
    end)
    
    return success and playerID or nil
end

function Integration:DetermineWinner(character, result, battle)
    -- This is a placeholder implementation
    -- You'll need to implement based on your specific result format
    
    if not result then return false end
    
    -- Common result types that might indicate victory
    local victoryKeywords = {"victory", "win", "success", "defeated"}
    local resultStr = tostring(result):lower()
    
    for _, keyword in ipairs(victoryKeywords) do
        if resultStr:find(keyword) then
            return true
        end
    end
    
    return false
end

-- ================================================
-- CLEANUP & MAINTENANCE
-- ================================================
function Integration:CleanupOldBattles()
    local cutoffTime = os.time() - 1800 -- 30 minutes
    
    for battleID, battle in pairs(self.activeBattles) do
        if battle.start_time < cutoffTime then
            self.activeBattles[battleID] = nil
            self:Log("Cleaned up stale battle: " .. battleID)
        end
    end
end

function Integration:CleanupRecentWins()
    local cutoffTime = os.time() - 3600 -- 1 hour
    
    for key, timestamp in pairs(self.recentWins) do
        if timestamp < cutoffTime then
            self.recentWins[key] = nil
        end
    end
end

-- Start cleanup timer
if ExecuteAsync and type(ExecuteAsync) == "function" then
    ExecuteAsync(function()
        while true do
            Integration:CleanupOldBattles()
            Integration:CleanupRecentWins()
            
            -- Wait 5 minutes between cleanups
            local start = os.clock()
            while os.clock() - start < 300 do
                -- Wait
            end
        end
    end)
end

print("[PalBattlePass] Integration module loaded!")
return Integration 