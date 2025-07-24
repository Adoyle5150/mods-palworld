-- ================================================
-- PALWORLD BATTLE PASS - REWARDS MODULE
-- Handles reward distribution and item giving
-- ================================================

local Rewards = {}
Rewards.__index = Rewards

-- Access global configuration
local CONFIG = _G.PALBP_CONFIG
local TIER_CONFIG = _G.PALBP_TIER_CONFIG

-- ================================================
-- REWARD PROCESSING SYSTEM
-- ================================================
function Rewards:Log(message, level)
    level = level or "INFO"
    local timestamp = os.date("%H:%M:%S")
    print(string.format("[%s] [PalBattlePass-Rewards] [%s] %s", timestamp, level, message))
end

function Rewards:ProcessReward(playerID, reward)
    if not playerID or not reward then
        self:Log("Invalid reward parameters", "ERROR")
        return false
    end
    
    self:Log("Processing reward for " .. playerID .. ": " .. (reward.name or "Unknown Reward"))
    
    local success = false
    
    -- Route to appropriate reward handler
    if reward.type == "pal_souls" then
        success = self:GivePalSouls(playerID, reward)
    elseif reward.type == "gold" then
        success = self:GiveGold(playerID, reward)
    elseif reward.type == "legendary_pal" then
        success = self:GiveLegendaryPal(playerID, reward)
    elseif reward.type == "ancient_parts" then
        success = self:GiveAncientParts(playerID, reward)
    elseif reward.type == "title" then
        success = self:GiveTitle(playerID, reward)
    elseif reward.type == "seasonal_exclusive" then
        success = self:GiveSeasonalExclusive(playerID, reward)
    elseif reward.type == "ultimate_reward" then
        success = self:GiveUltimateReward(playerID, reward)
    else
        success = self:GiveGenericReward(playerID, reward)
    end
    
    if success then
        self:Log("Successfully gave reward: " .. reward.name .. " to " .. playerID)
        self:LogRewardToHistory(playerID, reward)
    else
        self:Log("Failed to give reward: " .. reward.name .. " to " .. playerID, "ERROR")
    end
    
    return success
end

-- ================================================
-- SPECIFIC REWARD HANDLERS
-- ================================================

function Rewards:GivePalSouls(playerID, reward)
    local rarity = reward.rarity or "small"
    local amount = reward.amount or 1
    
    -- Map rarity to item IDs (these would be your actual Palworld item IDs)
    local soulItemIDs = {
        small = "PalSoul_Small",
        medium = "PalSoul_Medium", 
        large = "PalSoul_Large"
    }
    
    local itemID = soulItemIDs[rarity]
    if not itemID then
        self:Log("Unknown Pal Soul rarity: " .. rarity, "ERROR")
        return false
    end
    
    return self:GiveItem(playerID, itemID, amount)
end

function Rewards:GiveGold(playerID, reward)
    local amount = reward.amount or 1000
    
    -- Try multiple methods to give gold
    local success = false
    
    -- Method 1: Direct UE4SS item giving
    success = self:GiveItem(playerID, "Gold", amount) or success
    
    -- Method 2: Player inventory manipulation
    success = self:AddToPlayerInventory(playerID, "currency", "gold", amount) or success
    
    -- Method 3: Through PalCentralCore if available
    if _G.PalCentralCore and _G.PalCentralCore.data and _G.PalCentralCore.data.players then
        local playerData = _G.PalCentralCore.data.players[playerID]
        if not playerData then
            _G.PalCentralCore.data.players[playerID] = {}
            playerData = _G.PalCentralCore.data.players[playerID]
        end
        
        if not playerData.currency then
            playerData.currency = {}
        end
        
        playerData.currency.gold = (playerData.currency.gold or 0) + amount
        success = true
        
        self:Log("Added " .. amount .. " gold to player data storage")
    end
    
    return success
end

function Rewards:GiveLegendaryPal(playerID, reward)
    local species = reward.species or "Shadowbeak"
    local passives = reward.passives or {}
    local level = reward.level or 50
    
    -- Create legendary Pal data
    local palData = {
        species = species,
        level = level,
        passives = passives,
        is_legendary = true,
        source = "battle_pass_reward",
        stats = {
            hp = 100,
            attack = 100,
            defense = 100,
            speed = 100
        }
    }
    
    -- Try to spawn/give the Pal
    local success = false
    
    -- Method 1: UE4SS Pal spawning
    success = self:SpawnPalForPlayer(playerID, palData) or success
    
    -- Method 2: Add to player's Pal storage in PalCentralCore
    if _G.PalCentralCore and _G.PalCentralCore.data and _G.PalCentralCore.data.players then
        local playerData = _G.PalCentralCore.data.players[playerID]
        if not playerData then
            _G.PalCentralCore.data.players[playerID] = {}
            playerData = _G.PalCentralCore.data.players[playerID]
        end
        
        if not playerData.pals then
            playerData.pals = {}
        end
        
        -- Generate unique Pal ID
        local palID = "bp_legendary_" .. species .. "_" .. os.time()
        playerData.pals[palID] = palData
        success = true
        
        self:Log("Added legendary " .. species .. " to player Pal storage")
    end
    
    return success
end

function Rewards:GiveAncientParts(playerID, reward)
    local amount = reward.amount or 1
    return self:GiveItem(playerID, "AncientCivilizationParts", amount)
end

function Rewards:GiveTitle(playerID, reward)
    local title = reward.title or "Battle Pass Warrior"
    
    -- Store title in player data
    if _G.PalCentralCore and _G.PalCentralCore.data and _G.PalCentralCore.data.players then
        local playerData = _G.PalCentralCore.data.players[playerID]
        if not playerData then
            _G.PalCentralCore.data.players[playerID] = {}
            playerData = _G.PalCentralCore.data.players[playerID]
        end
        
        if not playerData.titles then
            playerData.titles = {}
        end
        
        -- Add title if not already owned
        local hasTitle = false
        for _, ownedTitle in ipairs(playerData.titles) do
            if ownedTitle == title then
                hasTitle = true
                break
            end
        end
        
        if not hasTitle then
            table.insert(playerData.titles, title)
            playerData.active_title = title -- Set as active title
            self:Log("Granted title '" .. title .. "' to player " .. playerID)
            return true
        else
            self:Log("Player " .. playerID .. " already has title '" .. title .. "'")
            return true -- Not an error, just already owned
        end
    end
    
    return false
end

function Rewards:GiveSeasonalExclusive(playerID, reward)
    local item = reward.item or "SeasonalExclusive"
    local season = CONFIG.CURRENT_SEASON.id
    
    -- Create seasonal exclusive item data
    local itemData = {
        item_id = item,
        season = season,
        rarity = "seasonal_exclusive",
        obtained_date = os.time(),
        description = reward.description or "A rare seasonal exclusive item!"
    }
    
    -- Store in player data
    if _G.PalCentralCore and _G.PalCentralCore.data and _G.PalCentralCore.data.players then
        local playerData = _G.PalCentralCore.data.players[playerID]
        if not playerData then
            _G.PalCentralCore.data.players[playerID] = {}
            playerData = _G.PalCentralCore.data.players[playerID]
        end
        
        if not playerData.seasonal_items then
            playerData.seasonal_items = {}
        end
        
        playerData.seasonal_items[item] = itemData
        self:Log("Granted seasonal exclusive '" .. item .. "' to player " .. playerID)
        return true
    end
    
    return false
end

function Rewards:GiveUltimateReward(playerID, reward)
    local item = reward.item or "UltimateReward"
    
    -- Ultimate rewards are extra special - multiple components
    local success = true
    
    -- Give seasonal exclusive
    success = self:GiveSeasonalExclusive(playerID, {
        item = item,
        description = reward.description or "The ultimate battle pass reward!"
    }) and success
    
    -- Give bonus gold
    success = self:GiveGold(playerID, {amount = 100000}) and success
    
    -- Give rare Pal souls
    success = self:GivePalSouls(playerID, {rarity = "large", amount = 10}) and success
    
    -- Grant special title
    success = self:GiveTitle(playerID, {title = "Seasonal Legend"}) and success
    
    -- Mark as ultimate reward recipient
    if _G.PalCentralCore and _G.PalCentralCore.data and _G.PalCentralCore.data.players then
        local playerData = _G.PalCentralCore.data.players[playerID]
        if playerData then
            if not playerData.achievements then
                playerData.achievements = {}
            end
            playerData.achievements.ultimate_reward_recipient = {
                season = CONFIG.CURRENT_SEASON.id,
                date = os.time()
            }
        end
    end
    
    return success
end

function Rewards:GiveGenericReward(playerID, reward)
    -- Fallback for unknown reward types
    self:Log("Processing generic reward: " .. (reward.name or "Unknown"))
    
    -- Try to give as an item
    local itemID = reward.item_id or reward.name or "GenericReward"
    local amount = reward.amount or 1
    
    return self:GiveItem(playerID, itemID, amount)
end

-- ================================================
-- LOW-LEVEL ITEM GIVING FUNCTIONS
-- ================================================

function Rewards:GiveItem(playerID, itemID, amount)
    amount = amount or 1
    
    -- Try UE4SS method first
    local success = self:GiveItemUE4SS(playerID, itemID, amount)
    
    if success then
        return true
    end
    
    -- Fallback to data storage
    return self:AddToPlayerInventory(playerID, "item", itemID, amount)
end

function Rewards:GiveItemUE4SS(playerID, itemID, amount)
    if not (ExecuteInGameThread and FindFirstOf) then
        return false
    end
    
    local success = pcall(function()
        ExecuteInGameThread(function()
            -- Try to find the player controller
            local playerController = self:FindPlayerController(playerID)
            if not playerController then
                return false
            end
            
            -- Try to give item through inventory system
            if playerController.AddItemToInventory then
                playerController:AddItemToInventory(itemID, amount)
            elseif playerController.GetPawn then
                local pawn = playerController:GetPawn()
                if pawn and pawn.AddItemToInventory then
                    pawn:AddItemToInventory(itemID, amount)
                end
            end
        end)
    end)
    
    if success then
        self:Log("Successfully gave " .. amount .. "x " .. itemID .. " via UE4SS")
        return true
    end
    
    return false
end

function Rewards:AddToPlayerInventory(playerID, category, itemID, amount)
    if not _G.PalCentralCore or not _G.PalCentralCore.data then
        return false
    end
    
    -- Ensure player data exists
    if not _G.PalCentralCore.data.players then
        _G.PalCentralCore.data.players = {}
    end
    
    if not _G.PalCentralCore.data.players[playerID] then
        _G.PalCentralCore.data.players[playerID] = {}
    end
    
    local playerData = _G.PalCentralCore.data.players[playerID]
    
    -- Initialize inventory
    if not playerData.inventory then
        playerData.inventory = {}
    end
    
    if not playerData.inventory[category] then
        playerData.inventory[category] = {}
    end
    
    -- Add item
    playerData.inventory[category][itemID] = (playerData.inventory[category][itemID] or 0) + amount
    
    self:Log("Added " .. amount .. "x " .. itemID .. " to player " .. playerID .. " inventory (" .. category .. ")")
    return true
end

function Rewards:SpawnPalForPlayer(playerID, palData)
    if not (ExecuteInGameThread and FindFirstOf) then
        return false
    end
    
    local success = pcall(function()
        ExecuteInGameThread(function()
            local playerController = self:FindPlayerController(playerID)
            if not playerController then
                return false
            end
            
            -- Try to spawn Pal (this is highly game-specific)
            -- This is a placeholder implementation
            local world = playerController:GetWorld()
            if world and world.SpawnActor then
                -- Spawn location near player
                local playerPawn = playerController:GetPawn()
                if playerPawn then
                    local location = playerPawn:GetActorLocation()
                    -- Adjust spawn location
                    location.X = location.X + 200 -- Spawn 200 units away
                    
                    -- Try to spawn the Pal
                    local palClass = self:GetPalClassBySpecies(palData.species)
                    if palClass then
                        local spawnedPal = world:SpawnActor(palClass, location)
                        if spawnedPal then
                            -- Set Pal properties
                            self:ConfigurePalStats(spawnedPal, palData)
                            self:Log("Successfully spawned " .. palData.species .. " for player " .. playerID)
                            return true
                        end
                    end
                end
            end
        end)
    end)
    
    return success
end

-- ================================================
-- UTILITY FUNCTIONS
-- ================================================

function Rewards:FindPlayerController(playerID)
    -- This is a placeholder implementation
    -- You'll need to implement based on your specific player identification system
    
    if not FindFirstOf then
        return nil
    end
    
    local success, controller = pcall(function()
        -- Try to find all player controllers
        local controllers = FindAllOf("PlayerController")
        if controllers then
            for _, controller in ipairs(controllers) do
                -- Try to match player ID
                local controllerID = self:GetPlayerIDFromController(controller)
                if controllerID == playerID then
                    return controller
                end
            end
        end
        
        return nil
    end)
    
    return success and controller or nil
end

function Rewards:GetPlayerIDFromController(controller)
    -- Extract player ID from controller (same logic as integration module)
    if not controller then return nil end
    
    local success, playerID = pcall(function()
        if controller.GetUniqueID then
            return tostring(controller:GetUniqueID())
        elseif controller.PlayerState and controller.PlayerState.GetPlayerId then
            return tostring(controller.PlayerState:GetPlayerId())
        end
        
        return tostring(controller)
    end)
    
    return success and playerID or nil
end

function Rewards:GetPalClassBySpecies(species)
    -- Map species names to UE4 class paths
    local speciesClasses = {
        Shadowbeak = "/Game/Pal/Blueprint/Character/Monster/BP_Shadowbeak.BP_Shadowbeak_C",
        Paladius = "/Game/Pal/Blueprint/Character/Monster/BP_Paladius.BP_Paladius_C",
        -- Add more species mappings as needed
    }
    
    return speciesClasses[species]
end

function Rewards:ConfigurePalStats(pal, palData)
    if not pal then return end
    
    pcall(function()
        -- Set level
        if pal.SetLevel and palData.level then
            pal:SetLevel(palData.level)
        end
        
        -- Set stats
        if pal.SetStats and palData.stats then
            pal:SetStats(palData.stats)
        end
        
        -- Set passives/abilities
        if pal.SetPassiveAbilities and palData.passives then
            pal:SetPassiveAbilities(palData.passives)
        end
        
        -- Mark as legendary
        if palData.is_legendary and pal.SetLegendary then
            pal:SetLegendary(true)
        end
    end)
end

-- ================================================
-- REWARD HISTORY & ANALYTICS
-- ================================================

function Rewards:LogRewardToHistory(playerID, reward)
    if not _G.PalCentralCore or not _G.PalCentralCore.data then
        return
    end
    
    -- Initialize reward history
    if not _G.PalCentralCore.data.reward_history then
        _G.PalCentralCore.data.reward_history = {}
    end
    
    -- Add reward to history
    table.insert(_G.PalCentralCore.data.reward_history, {
        player_id = playerID,
        reward_type = reward.type,
        reward_name = reward.name,
        tier = reward.tier,
        season = CONFIG.CURRENT_SEASON.id,
        timestamp = os.time()
    })
    
    -- Keep only last 1000 reward entries
    if #_G.PalCentralCore.data.reward_history > 1000 then
        table.remove(_G.PalCentralCore.data.reward_history, 1)
    end
end

function Rewards:GetPlayerRewardHistory(playerID)
    if not _G.PalCentralCore or not _G.PalCentralCore.data.reward_history then
        return {}
    end
    
    local playerRewards = {}
    for _, reward in ipairs(_G.PalCentralCore.data.reward_history) do
        if reward.player_id == playerID then
            table.insert(playerRewards, reward)
        end
    end
    
    return playerRewards
end

print("[PalBattlePass] Rewards module loaded!")
return Rewards 