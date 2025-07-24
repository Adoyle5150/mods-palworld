-- ================================================
-- PALWORLD BATTLE PASS - CHAT COMMANDS MODULE
-- Handles all player chat commands and interactions
-- ================================================

local Commands = {}
Commands.__index = Commands

-- Access global configuration
local CONFIG = _G.PALBP_CONFIG
local TIER_CONFIG = _G.PALBP_TIER_CONFIG

-- ================================================
-- CHAT MESSAGING SYSTEM
-- ================================================
function Commands:SendMessage(playerID, message, color)
    color = color or "white"
    local formattedMessage = string.format("%s %s", CONFIG.CHAT_PREFIX, message)
    
    -- Try multiple methods to send chat message
    local success = false
    
    -- Method 1: Direct UE4SS chat (if available)
    if ExecuteInGameThread and FindFirstOf then
        success = pcall(function()
            ExecuteInGameThread(function()
                local PlayerController = FindFirstOf("PlayerController")
                if PlayerController then
                    -- Send chat message (this is UE4-specific)
                    PlayerController:ClientMessage(formattedMessage)
                end
            end)
        end)
    end
    
    -- Method 2: Console output (fallback)
    if not success then
        print(string.format("[CHAT] %s: %s", tostring(playerID), formattedMessage))
    end
end

function Commands:SendMultilineMessage(playerID, lines)
    for _, line in ipairs(lines) do
        self:SendMessage(playerID, line)
        -- Small delay between messages to prevent spam
        local start = os.clock()
        while os.clock() - start < 0.1 do end
    end
end

-- ================================================
-- COMMAND HANDLERS
-- ================================================

-- Main battle pass status command
function Commands:HandleBattlePassStatus(playerID, args)
    local bp = _G.PalBattlePassInstance:GetPlayerBattlePass(playerID)
    local unclaimedTiers = _G.PalBattlePassInstance:GetUnclaimedTiers(bp)
    local nextTierReq = _G.PalBattlePassInstance:GetNextTierRequirement(bp.current_tier)
    
    local messages = {
        "🏆 ═══════ BATTLE PASS STATUS ═══════",
        "🎯 Season: " .. CONFIG.CURRENT_SEASON.name,
        "⚔️  Ranked Wins: " .. bp.ranked_wins .. " victories",
        "🏅 Current Tier: " .. bp.current_tier .. "/" .. CONFIG.CURRENT_SEASON.max_tiers,
        "🔥 Win Streak: " .. bp.win_streak .. " (Best: " .. bp.best_win_streak .. ")",
        "",
        "📈 Progress to Next Tier:"
    }
    
    if bp.current_tier >= CONFIG.CURRENT_SEASON.max_tiers then
        table.insert(messages, "🌟 MAX TIER REACHED! Go for Epic Reward (" .. CONFIG.CURRENT_SEASON.epic_reward_wins .. " wins)")
    else
        local winsNeeded = nextTierReq - bp.ranked_wins
        table.insert(messages, "🎯 Need " .. winsNeeded .. " more wins (Total: " .. nextTierReq .. ")")
    end
    
    table.insert(messages, "")
    
    -- Unclaimed rewards
    if #unclaimedTiers > 0 then
        table.insert(messages, "🎁 UNCLAIMED REWARDS: " .. #unclaimedTiers .. " available!")
        table.insert(messages, "💰 Use '/bp claim' to collect them!")
    else
        table.insert(messages, "✅ All rewards claimed up to current tier")
    end
    
    -- Epic reward status
    if bp.ranked_wins >= CONFIG.CURRENT_SEASON.epic_reward_wins then
        if bp.epic_claimed then
            table.insert(messages, "🌟 Epic Reward: CLAIMED ✅")
        else
            table.insert(messages, "🌟 EPIC REWARD AVAILABLE! Use '/bp claim epic'")
        end
    else
        local epicNeeded = CONFIG.CURRENT_SEASON.epic_reward_wins - bp.ranked_wins
        table.insert(messages, "🌟 Epic Reward: " .. epicNeeded .. " wins remaining")
    end
    
    table.insert(messages, "")
    table.insert(messages, "💬 Commands: bp claim | bp rewards | bp leaderboard")
    table.insert(messages, "💡 Use 'bphelp' for command format options")
    
    self:SendMultilineMessage(playerID, messages)
end

-- Claim rewards command
function Commands:HandleClaimRewards(playerID, args)
    local bp = _G.PalBattlePassInstance:GetPlayerBattlePass(playerID)
    local unclaimedTiers = _G.PalBattlePassInstance:GetUnclaimedTiers(bp)
    
    -- Handle epic reward claim
    if args[1] == "epic" then
        if bp.ranked_wins >= CONFIG.CURRENT_SEASON.epic_reward_wins and not bp.epic_claimed then
            local epicReward = TIER_CONFIG.REWARDS[100]
            if self:GiveRewardToPlayer(playerID, epicReward) then
                bp.epic_claimed = true
                bp.last_updated = os.time()
                
                self:SendMessage(playerID, "🌟 EPIC REWARD CLAIMED: " .. epicReward.name .. "!")
                self:BroadcastAchievement(playerID, "claimed the Epic Seasonal Reward!")
                return
            else
                self:SendMessage(playerID, "❌ Failed to give epic reward. Try again later.")
                return
            end
        else
            self:SendMessage(playerID, "❌ Epic reward not available or already claimed.")
            return
        end
    end
    
    -- Claim regular tier rewards
    if #unclaimedTiers == 0 then
        self:SendMessage(playerID, "✅ No rewards to claim! Keep battling to unlock more tiers.")
        return
    end
    
    local claimedCount = 0
    local claimedRewards = {}
    
    for _, tier in ipairs(unclaimedTiers) do
        if tier ~= 100 then -- Don't auto-claim epic reward
            local reward = TIER_CONFIG.REWARDS[tier]
            if reward and self:GiveRewardToPlayer(playerID, reward) then
                table.insert(bp.claimed_tiers, tier)
                table.insert(claimedRewards, "Tier " .. tier .. ": " .. reward.name)
                claimedCount = claimedCount + 1
            end
        end
    end
    
    if claimedCount > 0 then
        bp.last_updated = os.time()
        
        local messages = {
            "🎁 ═══════ REWARDS CLAIMED ═══════",
            "✅ Successfully claimed " .. claimedCount .. " rewards:"
        }
        
        for _, rewardText in ipairs(claimedRewards) do
            table.insert(messages, "🏆 " .. rewardText)
        end
        
        table.insert(messages, "")
        table.insert(messages, "💰 Rewards added to your inventory!")
        
        self:SendMultilineMessage(playerID, messages)
        
        -- Update season stats
        if _G.PalCentralCore and _G.PalCentralCore.data.battle_pass.season_stats then
            _G.PalCentralCore.data.battle_pass.season_stats.rewards_claimed = 
                (_G.PalCentralCore.data.battle_pass.season_stats.rewards_claimed or 0) + claimedCount
        end
    else
        self:SendMessage(playerID, "❌ Failed to claim rewards. Try again later.")
    end
end

-- Show available rewards
function Commands:HandleShowRewards(playerID, args)
    local bp = _G.PalBattlePassInstance:GetPlayerBattlePass(playerID)
    
    local messages = {
        "🎁 ═══════ TIER REWARDS ═══════",
        "Current Tier: " .. bp.current_tier .. "/" .. CONFIG.CURRENT_SEASON.max_tiers
    }
    
    -- Show next few tiers
    local showTiers = {}
    for i = bp.current_tier + 1, math.min(bp.current_tier + 5, CONFIG.CURRENT_SEASON.max_tiers) do
        table.insert(showTiers, i)
    end
    
    if #showTiers > 0 then
        table.insert(messages, "")
        table.insert(messages, "🎯 UPCOMING REWARDS:")
        
        for _, tier in ipairs(showTiers) do
            local reward = TIER_CONFIG.REWARDS[tier]
            local winsReq = TIER_CONFIG.REQUIREMENTS[tier]
            
            if reward then
                table.insert(messages, string.format("Tier %d (%d wins): %s", tier, winsReq, reward.name))
            else
                table.insert(messages, string.format("Tier %d (%d wins): Standard Reward", tier, winsReq))
            end
        end
    end
    
    -- Show epic reward
    table.insert(messages, "")
    table.insert(messages, "🌟 EPIC REWARD (" .. CONFIG.CURRENT_SEASON.epic_reward_wins .. " wins):")
    local epicReward = TIER_CONFIG.REWARDS[100]
    if epicReward then
        table.insert(messages, "🏆 " .. epicReward.name)
        table.insert(messages, "📝 " .. (epicReward.description or "Ultimate seasonal exclusive!"))
    end
    
    self:SendMultilineMessage(playerID, messages)
end

-- Leaderboard command
function Commands:HandleLeaderboard(playerID, args)
    -- Collect all players' battle pass data
    local players = {}
    
    if _G.PalCentralCore and _G.PalCentralCore.data and _G.PalCentralCore.data.players then
        for pID, playerData in pairs(_G.PalCentralCore.data.players) do
            if playerData.battle_pass and playerData.battle_pass.season_id == CONFIG.CURRENT_SEASON.id then
                table.insert(players, {
                    id = pID,
                    wins = playerData.battle_pass.ranked_wins,
                    tier = playerData.battle_pass.current_tier,
                    streak = playerData.battle_pass.win_streak,
                    best_streak = playerData.battle_pass.best_win_streak
                })
            end
        end
    end
    
    -- Sort by wins (descending)
    table.sort(players, function(a, b) return a.wins > b.wins end)
    
    local messages = {
        "🏆 ═══════ BATTLE PASS LEADERBOARD ═══════",
        "🎯 Season: " .. CONFIG.CURRENT_SEASON.name,
        ""
    }
    
    if #players == 0 then
        table.insert(messages, "📊 No players found in current season")
    else
        table.insert(messages, "🥇 TOP WARRIORS:")
        
        for i = 1, math.min(10, #players) do
            local player = players[i]
            local rank = i == 1 and "🥇" or (i == 2 and "🥈" or (i == 3 and "🥉" or "🏅"))
            local playerName = self:GetPlayerName(player.id) or "Unknown"
            
            table.insert(messages, string.format("%s #%d: %s", rank, i, playerName))
            table.insert(messages, string.format("   ⚔️  %d wins | 🏅 Tier %d | 🔥 %d streak", 
                player.wins, player.tier, player.streak))
        end
        
        -- Show current player's rank if not in top 10
        local playerRank = nil
        for i, player in ipairs(players) do
            if player.id == playerID then
                playerRank = i
                break
            end
        end
        
        if playerRank and playerRank > 10 then
            table.insert(messages, "")
            table.insert(messages, "📍 YOUR RANK: #" .. playerRank)
        end
    end
    
    self:SendMultilineMessage(playerID, messages)
end

-- Admin commands
function Commands:HandleAdminCommand(playerID, args)
    -- Basic admin check (you can implement proper permissions)
    if not self:IsAdmin(playerID) then
        self:SendMessage(playerID, "❌ Access denied. Admin privileges required.")
        return
    end
    
    local subcommand = args[1]
    
    if subcommand == "stats" then
        self:HandleAdminStats(playerID, args)
    elseif subcommand == "reset" then
        self:HandleAdminReset(playerID, args)
    elseif subcommand == "give" then
        self:HandleAdminGiveWins(playerID, args)
    else
        local messages = {
            "🔧 ADMIN COMMANDS:",
            "/bpadmin stats - Season statistics",
            "/bpadmin reset [playerID] - Reset player progress",
            "/bpadmin give [playerID] [wins] - Give wins to player"
        }
        self:SendMultilineMessage(playerID, messages)
    end
end

function Commands:HandleAdminStats(playerID, args)
    local stats = _G.PalCentralCore.data.battle_pass.season_stats or {}
    
    local messages = {
        "📊 ═══════ SEASON STATISTICS ═══════",
        "🎯 Season: " .. CONFIG.CURRENT_SEASON.name,
        "👥 Total Players: " .. (stats.total_players or 0),
        "⚔️  Total Battles: " .. (stats.total_battles or 0),
        "🎁 Rewards Claimed: " .. (stats.rewards_claimed or 0),
        "",
        "📅 Season ends: " .. os.date("%Y-%m-%d", CONFIG.CURRENT_SEASON.end_date)
    }
    
    self:SendMultilineMessage(playerID, messages)
end

-- ================================================
-- UTILITY FUNCTIONS
-- ================================================
function Commands:GetPlayerName(playerID)
    -- This is a placeholder - implement based on your player system
    return "Player_" .. tostring(playerID):sub(-4)
end

function Commands:IsAdmin(playerID)
    -- Implement your admin check logic here
    -- For now, return false (no admin privileges)
    return false
end

function Commands:BroadcastAchievement(playerID, achievement)
    local playerName = self:GetPlayerName(playerID)
    local message = "🌟 " .. playerName .. " " .. achievement
    
    -- Broadcast to all players (if possible)
    print("[BROADCAST] " .. message)
end

-- Placeholder for reward giving (will be implemented by rewards module)
function Commands:GiveRewardToPlayer(playerID, reward)
    -- This will be replaced by the rewards module
    return true
end

-- ================================================
-- MAIN COMMAND ROUTER
-- ================================================
function Commands:HandleCommand(playerID, command, args)
    command = command:lower()
    
    -- Main battle pass commands
    if command == "bp" or command == "battlepass" then
        if not args or #args == 0 then
            self:HandleBattlePassStatus(playerID, args)
        elseif args[1] == "claim" then
            self:HandleClaimRewards(playerID, args)
        elseif args[1] == "rewards" then
            self:HandleShowRewards(playerID, args)
        elseif args[1] == "leaderboard" or args[1] == "lb" then
            self:HandleLeaderboard(playerID, args)
        else
            self:SendMessage(playerID, "💬 Commands: /bp | /bp claim | /bp rewards | /bp leaderboard")
        end
        
    -- Admin commands
    elseif command == "bpadmin" then
        self:HandleAdminCommand(playerID, args)
        
    -- Help command
    elseif command == "bphelp" then
        local messages = {
            "🏆 ═══════ BATTLE PASS HELP ═══════",
            "💬 Available Commands (multiple formats):",
            "bp / /bp / !bp / .bp - View your status",
            "bp claim / /bp claim - Claim available rewards", 
            "bp rewards / /bp rewards - View upcoming rewards",
            "bp leaderboard / /bp leaderboard - Top rankings",
            "",
            "🛡️ Server Security Note:",
            "• If /commands don't work, try: bp, !bp, or .bp",
            "• Battle pass works without registration!",
            "",
            "🎯 How it Works:",
            "• Win ranked PvP battles to earn progress",
            "• Unlock tiers with increasing win requirements", 
            "• Claim amazing rewards at each tier",
            "• Reach " .. CONFIG.CURRENT_SEASON.epic_reward_wins .. " wins for the Epic Reward!",
            "",
            "🔥 Current Season: " .. CONFIG.CURRENT_SEASON.name
        }
        self:SendMultilineMessage(playerID, messages)
    end
end

print("[PalBattlePass] Commands module loaded!")
return Commands 