-- ranked_system.lua - Ranking system for the Ranked Coliseum

local RankedSystem = {}

-- ================================================
-- RANK ENUMS AND CONSTANTS
-- ================================================
RankedSystem.Ranks = {
    IRON = {id = 0, name = "Iron", points_min = 0, points_max = 100},
    BRONZE = {id = 1, name = "Bronze", points_min = 101, points_max = 200},
    SILVER = {id = 2, name = "Silver", points_min = 201, points_max = 300},
    GOLD = {id = 3, name = "Gold", points_min = 301, points_max = 400},
    PLATINUM = {id = 4, name = "Platinum", points_min = 401, points_max = 500},
    EMERALD = {id = 5, name = "Emerald", points_min = 501, points_max = 600},
    DIAMOND = {id = 6, name = "Diamond", points_min = 601, points_max = 700},
    MASTER = {id = 7, name = "Master", points_min = 701, points_max = 800},
    GRAND_MASTER = {id = 8, name = "Grand Master", points_min = 801, points_max = 900},
    LEGEND = {id = 9, name = "Legend", points_min = 901, points_max = 9999} -- points_max is a theoretical limit, the rank is unique
}

RankedSystem.Categories = {"Ubers", "OU", "UU", "NU", "LC"}

-- ================================================
-- PLAYER DATA (Stored in RankedSystem's local memory)
-- ================================================
local players_data = {}
local current_legend = nil -- ID of the current Legend player

-- Reference to the PalCentralCore instance
local PalCentralCoreRef = nil

-- ================================================
-- RANKING SYSTEM INITIALIZATION
-- ================================================
function RankedSystem.Initialize(palCentralCore)
    PalCentralCoreRef = palCentralCore -- Store the core reference
    if not PalCentralCoreRef then
        print("[Ranked System][FATAL ERROR] PalCentralCore not available during RankedSystem initialization.")
        return
    end

    PalCentralCoreRef:Log("[Ranked System] System initialized.", "INFO")
    RankedSystem.LoadPlayerData()
    
    -- Set a timer for periodic data saving (for more frequent persistence)
    -- PalCentralCore must have CONFIG.BACKUP_INTERVAL
    -- Added check for PalCentralCoreRef.CONFIG
    if PalCentralCoreRef.CONFIG and PalCentralCoreRef.CONFIG.BACKUP_INTERVAL then
        Timer.SetInterval(function()
            RankedSystem.SavePlayerData()
        end, PalCentralCoreRef.CONFIG.BACKUP_INTERVAL * 1000) -- Save every X seconds (converted to milliseconds)
        PalCentralCoreRef:Log(string.format("[Ranked System] Scheduled automatic saving every %d seconds.", PalCentralCoreRef.CONFIG.BACKUP_INTERVAL), "DEBUG")
    else
        PalCentralCoreRef:Log("[Ranked System] Backup interval not defined in PalCentralCore. Automatic saving disabled.", "WARN")
    end
end

-- ================================================
-- PLAYER REGISTRATION AND UPDATE
-- ================================================
function RankedSystem.RegisterPlayer(player_character, palCentralCore)
    local core = palCentralCore or PalCentralCoreRef
    if not core then
        print("[Ranked System][ERROR] Core unavailable for player registration.")
        return
    end

    -- Safely obtain Player ID and Name
    local player_id_obj = player_character:GetPlayerID()
    local player_id = tostring(player_id_obj)
    local player_name = player_character:GetPlayerName()

    if not players_data[player_id] then
        players_data[player_id] = {
            id = player_id,
            name = player_name,
            points = 0,
            rank = RankedSystem.Ranks.IRON, -- Starts at Iron
            wins = 0,
            losses = 0,
            win_streak = 0,
            season_wins = 0, -- For Battle Pass
            category_points = { -- Points separated by category
                Ubers = 0, OU = 0, UU = 0, NU = 0, LC = 0
            },
            battle_pass_rewards = {} -- Battle Pass rewards already obtained
        }
        core:Log(string.format("[Ranked System] Player '%s' (ID: %s) registered.", player_name, player_id), "INFO")
        RankedSystem.SavePlayerData() -- Save after registering a new player
    else
        -- Update player name if it has changed (or other non-rank data)
        if players_data[player_id].name ~= player_name then
            players_data[player_id].name = player_name
            core:Log(string.format("[Ranked System] Player name '%s' (ID: %s) updated to '%s'.", players_data[player_id].name, player_id, player_name), "INFO")
            RankedSystem.SavePlayerData()
        end
    end
end

-- ================================================
-- BATTLE RESULT PROCESSING
-- ================================================
function RankedSystem.ProcessBattleResult(winner_id, loser_id, category)
    local core = PalCentralCoreRef
    if not core then
        print("[Ranked System][ERROR] Core unavailable for battle processing.")
        return
    end

    local winner = players_data[winner_id]
    local loser = players_data[loser_id]
    
    if not winner or not loser then
        core:Log(string.format("[Ranked System] Error: Winner (%s) or Loser (%s) not found for battle processing.", winner_id, loser_id), "WARN")
        return
    end
    
    -- Calculate points
    local points_gained = RankedSystem.CalculatePointsGained(winner, loser)
    local points_lost = RankedSystem.CalculatePointsLost(winner, loser)
    
    -- Update winner
    winner.points = winner.points + points_gained
    winner.wins = winner.wins + 1
    winner.win_streak = winner.win_streak + 1
    winner.season_wins = winner.season_wins + 1
    winner.category_points[category] = (winner.category_points[category] or 0) + points_gained
    
    -- Update loser
    loser.points = math.max(0, loser.points - points_lost)
    loser.losses = loser.losses + 1
    loser.win_streak = 0 -- Reset win streak
    loser.category_points[category] = math.max(0, (loser.category_points[category] or 0) - points_lost)
    
    -- Check rank changes
    RankedSystem.UpdatePlayerRank(winner)
    RankedSystem.UpdatePlayerRank(loser)
    
    RankedSystem.SavePlayerData()
    
    core:Log(string.format("[Ranked System] Battle processed: %s (+%d) vs %s (-%d) in category %s", 
        winner.name, points_gained, loser.name, points_lost, category), "INFO")
end

-- ================================================
-- POINTS CALCULATION
-- ================================================
function RankedSystem.CalculatePointsGained(winner, loser)
    local base_points = 25
    local rank_diff = loser.rank.id - winner.rank.id
    
    -- Bonus for defeating a stronger opponent
    if rank_diff > 0 then
        base_points = base_points + (rank_diff * 5)
    end
    
    -- Bonus for win streak
    if winner.win_streak >= 3 then
        base_points = base_points + 5
    end
    
    return math.max(20, math.min(30, base_points)) -- Points gained between 20 and 30
end

function RankedSystem.CalculatePointsLost(winner, loser)
    local base_points = 15
    local rank_diff = winner.rank.id - loser.rank.id
    
    -- Penalty for losing to a weaker opponent
    if rank_diff > 0 then
        base_points = base_points + (rank_diff * 5)
    end
    
    return math.max(10, math.min(20, base_points)) -- Points lost between 10 and 20
end

-- ================================================
-- RANK UPDATE
-- ================================================
function RankedSystem.UpdatePlayerRank(player)
    local core = PalCentralCoreRef
    if not core then return end -- Log already handled in ProcessBattleResult
    
    local old_rank = player.rank
    local new_rank = RankedSystem.GetRankByPoints(player.points)
    
    if new_rank.id ~= old_rank.id then
        player.rank = new_rank
        
        -- Check for Legend promotion
        if new_rank.id == RankedSystem.Ranks.LEGEND.id and old_rank.id ~= RankedSystem.Ranks.LEGEND.id then
            RankedSystem.HandleLegendPromotion(player)
        end
        
        core:Log(string.format("[Ranked System] %s (%s) promoted to %s!", player.name, player.id, new_rank.name), "INFO")
        -- If it's the player's first time reaching this rank, consider giving a reward here
    end
end

function RankedSystem.GetRankByPoints(points)
    for _, rank in pairs(RankedSystem.Ranks) do
        if points >= rank.points_min and points <= rank.points_max then
            return rank
        end
    end
    return RankedSystem.Ranks.IRON -- Return Iron if points are below the minimum
end

-- ================================================
-- LEGEND RANK LOGIC (UNIQUE RANK)
-- ================================================
function RankedSystem.HandleLegendPromotion(new_legend)
    local core = PalCentralCoreRef
    if not core then return end

    -- Demote previous Legend, if exists and not the same player
    if current_legend and current_legend ~= new_legend.id then
        local old_legend = players_data[current_legend]
        if old_legend then
            -- Demote to Grand Master
            old_legend.rank = RankedSystem.Ranks.GRAND_MASTER
            old_legend.points = RankedSystem.Ranks.GRAND_MASTER.points_max -- Ensure points fit the rank
            core:Log(string.format("[Ranked System] Previous Legend %s demoted to Grand Master.", old_legend.name), "INFO")
        end
    end
    
    current_legend = new_legend.id
    
    -- Broadcast to server
    RankedSystem.BroadcastLegendNotification(new_legend.name)
    RankedSystem.SavePlayerData() -- Save to persist the new Legend
end

function RankedSystem.BroadcastLegendNotification(player_name)
    local core = PalCentralCoreRef
    if not core then return end

    local message = string.format("🏆 %s has achieved the LEGEND rank and is the SUPREME MASTER of the Palworld Coliseum! 🏆", player_name)
    
    core:Log("[BROADCAST] " .. message, "INFO")
    
    -- Attempt to send message in game chat
    -- This functionality depends on the UE4SS API for chat.
    -- PalCentralCore would need to expose a function for this, or you would need
    -- to find a valid PlayerController to execute the 'say' command.
    -- For now, we're just logging, but ideally, the message should go to global chat.
    -- Example: core:SendGlobalChatMessage(message) (if the core has this function)
    local anyPlayerController = GetWorld():GetFirstPlayerController() -- Try to get any player controller
    if anyPlayerController and anyPlayerController.ExecuteConsoleCommand then
        anyPlayerController:ExecuteConsoleCommand("say " .. message)
    else
        core:Log("[BROADCAST ERROR] Unable to send message to game chat (PlayerController/API unavailable).", "WARN")
    end
end

-- ================================================
-- DATA PERSISTENCE
-- ================================================
function RankedSystem.SavePlayerData()
    local core = PalCentralCoreRef
    if not core then 
        print("[Ranked System][ERROR] Core unavailable for saving rank data.")
        return
    end

    -- Update the players section in the core's global database
    -- Ensure 'data.players_data' exists in the core's global structure
    if not core.data.players_data then
        core.data.players_data = {}
    end
    core.data.players_data = players_data -- Save the players table
    core.data.current_legend = current_legend -- Save the current Legend

    core:SaveData(core.data) -- Save the core's complete database to the JSON file
    core:Log("[Ranked System] Rank data saved to PalCentralCore.", "INFO")
end

function RankedSystem.LoadPlayerData()
    local core = PalCentralCoreRef
    if not core then 
        print("[Ranked System][ERROR] Core unavailable for loading rank data.")
        return
    end

    -- Load player data from the core's global database
    -- If core.data.players_data exists, use it; otherwise, initialize an empty table
    players_data = core.data.players_data or {}
    current_legend = core.data.current_legend or nil
    
    core:Log("[Ranked System] Rank data loaded from PalCentralCore.", "INFO")

    -- If Legend exists and is not in the correct rank (e.g., after a crash or manual demotion)
    if current_legend and players_data[current_legend] and players_data[current_legend].rank.id ~= RankedSystem.Ranks.LEGEND.id then
        local old_legend_player = players_data[current_legend]
        -- Fix the Legend's rank if it was demoted incorrectly due to a bug/restart
        old_legend_player.rank = RankedSystem.Ranks.LEGEND 
        old_legend_player.points = RankedSystem.Ranks.LEGEND.points_min -- Adjust points
        core:Log(string.format("[Ranked System] Legend (%s) revalidated after loading.", old_legend_player.name), "WARN")
    end
end

-- ================================================
-- QUERY FUNCTIONS
-- ================================================
function RankedSystem.GetPlayerData(player_id)
    return players_data[player_id]
end

function RankedSystem.GetLeaderboard(limit)
    limit = limit or 10
    local sorted_players = {}
    
    for _, player in pairs(players_data) do
        table.insert(sorted_players, player)
    end
    
    -- Sort by points (descending), then by wins (descending)
    table.sort(sorted_players, function(a, b)
        if a.points == b.points then
            return a.wins > b.wins
        end
        return a.points > b.points
    end)
    
    local result = {}
    -- Fix: was inserting the result instead of the player.
    -- Now inserts the sorted players into the 'result' array.
    for i = 1, math.min(limit, #sorted_players) do
        table.insert(result, sorted_players[i]) 
    end
    
    return result
end

-- ================================================
-- EXPORT MODULE
-- ================================================
return RankedSystem