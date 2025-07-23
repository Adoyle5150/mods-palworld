-- ================================================
-- MOD DE BREEDING - PALWORLD
-- Version: 1.0.0
-- Description: Breeding system with guaranteed inheritance
-- ================================================

local PalBreedingSystem = {}
PalBreedingSystem.__index = PalBreedingSystem

-- ================================================
-- BREEDING CONFIGURATIONS
-- ================================================
local BREEDING_CONFIG = {
    BREEDING_COOLDOWN = 3600, -- 1 hour in seconds
    MAX_BREEDING_ATTEMPTS = 3,
    BREEDING_COST_BASE = 1000, -- Base cost in gold
    SUCCESS_RATE_BASE = 85, -- 85% base success rate
    PERFECT_BONUS_RATE = 15, -- Bonus for perfect parents
    GENERATION_PENALTY = 5, -- -5% per high generation
    PASSIVE_INHERITANCE_GUARANTEED = true,
    CONSUME_PARENTS = true, -- Parents are consumed in breeding
    MIN_LEVEL_TO_BREED = 15,
    BREEDING_FACILITIES = {
        basic = {cost_multiplier = 1.0, success_bonus = 0},
        advanced = {cost_multiplier = 1.5, success_bonus = 10},
        premium = {cost_multiplier = 2.0, success_bonus = 20}
    }
}

-- ================================================
-- BREEDING COMBINATIONS TABLE
-- ================================================
local BREEDING_COMBINATIONS = {
    -- Format: "parent1_species-parent2_species" = {result_species, success_rate_modifier}
    ["Lamball-Cattiva"] = {"Lamball", 0},
    ["Lamball-Chikipi"] = {"Lifmunk", 5},
    ["Cattiva-Chikipi"] = {"Cattiva", -5},
    ["Lifmunk-Foxparks"] = {"Foxparks", 10},
    ["Depresso-Lamball"] = {"Depresso", -10},
    
    -- Special combinations for rare Pals
    ["Anubis-Jormuntide"] = {"Anubis", 20},
    ["Blazamut-Suzaku"] = {"Blazamut", 15},
    ["Paladius-Necromus"] = {"Shadowbeak", 25},
    
    -- Default same-species combinations
    default_same_species = {success_rate_modifier = 10}
}

-- ================================================
-- PASSIVES AND RARITY SYSTEM
-- ================================================
local PASSIVE_RARITIES = {
    common = {"Swift", "Runner", "Workaholic", "Diet Lover", "Positive Thinker"},
    uncommon = {"Artisan", "Serious", "Nimble", "Stronghold Strategist", "Lucky"},
    rare = {"Legend", "Musclehead", "Ferocious", "Burly Body", "Aggressive"},
    epic = {"Lord of Lightning", "Lord of the Sea", "Spirit Emperor", "Flame Emperor"},
    legendary = {"Alpha", "Emperor", "Divine Dragon", "Transcendent"}
}

-- ================================================
-- BREEDING-SPECIFIC LOG SYSTEM
-- ================================================
function PalBreedingSystem:LogBreeding(message, level)
    level = level or "INFO"
    -- Try multiple methods to find PalCentralCore
    local core = _G.PalCentralCoreInstance or 
                package.loaded["PalCentralCoreInstance"] or 
                package.loaded["PalCentralCore"]
    
    -- Try file-based approach if others fail
    if not core then
        local success, file_core = pcall(dofile, "palcentral_instance.lua")
        if success and file_core then
            core = file_core
        end
    end
    
    if core and core.Log then
        core:Log("[BREEDING] " .. message, level)
    else
        print(string.format("[BREEDING LOG] %s", message))
    end
end

-- ================================================
-- PARENT VALIDATION FOR BREEDING
-- ================================================
function PalBreedingSystem:ValidateBreedingPair(parent1, parent2, data)
    if not parent1 or not parent2 then
        return false, "One or both parents not found"
    end
    
    -- Check if they belong to different owners or same owner allows
    if parent1.owner_id ~= parent2.owner_id then
        return false, "Parents must belong to the same player for direct breeding"
    end
    
    -- Check minimum levels
    if parent1.level < BREEDING_CONFIG.MIN_LEVEL_TO_BREED then
        return false, parent1.name .. " must be level " .. BREEDING_CONFIG.MIN_LEVEL_TO_BREED .. " or higher"
    end
    
    if parent2.level < BREEDING_CONFIG.MIN_LEVEL_TO_BREED then
        return false, parent2.name .. " must be level " .. BREEDING_CONFIG.MIN_LEVEL_TO_BREED .. " or higher"
    end
    
    -- Check breeding cooldown
    local current_time = os.time()
    if parent1.last_bred and (current_time - parent1.last_bred) < BREEDING_CONFIG.BREEDING_COOLDOWN then
        local remaining = BREEDING_CONFIG.BREEDING_COOLDOWN - (current_time - parent1.last_bred)
        return false, parent1.name .. " is still on cooldown for " .. math.ceil(remaining/60) .. " minutes"
    end
    
    if parent2.last_bred and (current_time - parent2.last_bred) < BREEDING_CONFIG.BREEDING_COOLDOWN then
        local remaining = BREEDING_CONFIG.BREEDING_COOLDOWN - (current_time - parent2.last_bred)
        return false, parent2.name .. " is still on cooldown for " .. math.ceil(remaining/60) .. " minutes"
    end
    
    -- Check if they are the same Pal
    if parent1.id == parent2.id then
        return false, "A Pal cannot breed with itself"
    end
    
    -- Check for different genders
    if parent1.gender == parent2.gender then
        return false, "Parents must have different genders for breeding"
    end
    
    -- Check breeding attempt limit
    if parent1.bred_count >= BREEDING_CONFIG.MAX_BREEDING_ATTEMPTS then
        return false, parent1.name .. " has reached the maximum breeding limit"
    end
    
    if parent2.bred_count >= BREEDING_CONFIG.MAX_BREEDING_ATTEMPTS then
        return false, parent2.name .. " has reached the maximum breeding limit"
    end
    
    -- Check if available for breeding
    if parent1.market_status ~= "available" then
        return false, parent1.name .. " is not available (status: " .. parent1.market_status .. ")"
    end
    
    if parent2.market_status ~= "available" then
        return false, parent2.name .. " is not available (status: " .. parent2.market_status .. ")"
    end
    
    return true, "Valid pair for breeding"
end

-- ================================================
-- DETERMINATION OF OFFSPRING SPECIES
-- ================================================
function PalBreedingSystem:DetermineOffspringSpecies(parent1, parent2)
    -- Ensure alphabetical order for the combination key to avoid duplication (e.g., "A-B" is the same as "B-A")
    local sorted_species = {parent1.species, parent2.species}
    table.sort(sorted_species) -- Ensures consistent order
    local combination_key = sorted_species[1] .. "-" .. sorted_species[2]
    
    -- Check specific combination
    if BREEDING_COMBINATIONS[combination_key] then
        return BREEDING_COMBINATIONS[combination_key][1], BREEDING_COMBINATIONS[combination_key][2]
    end
    
    -- If same species
    if parent1.species == parent2.species then
        return parent1.species, BREEDING_COMBINATIONS.default_same_species.success_rate_modifier
    end
    
    -- Default: randomly choose one of the parents' species
    local random_choice = math.random(1, 2)
    local chosen_species = random_choice == 1 and parent1.species or parent2.species
    
    return chosen_species, 0
end

-- ================================================
-- PASSIVE INHERITANCE SYSTEM
-- ================================================
function PalBreedingSystem:InheritPassives(parent1, parent2)
    local all_passives = {}
    
    -- Collect all passives from parents
    for _, passive in ipairs(parent1.passives) do
        table.insert(all_passives, passive)
    end
    
    for _, passive in ipairs(parent2.passives) do
        -- Avoid duplicates
        local already_exists = false
        for _, existing in ipairs(all_passives) do
            if existing == passive then
                already_exists = true
                break
            end
        end
        if not already_exists then
            table.insert(all_passives, passive)
        end
    end
    
    -- If guaranteed inheritance is enabled
    if BREEDING_CONFIG.PASSIVE_INHERITANCE_GUARANTEED then
        -- Ensure at least the best passives are inherited
        local inherited_passives = {}
        
        -- Take up to 4 passives (prioritize rarest)
        local sorted_passives = self:SortPassivesByRarity(all_passives)
        
        for i = 1, math.min(4, #sorted_passives) do
            table.insert(inherited_passives, sorted_passives[i])
        end
        
        return inherited_passives
    else
        -- Chance-based inheritance system
        local inherited_passives = {}
        
        for _, passive in ipairs(all_passives) do
            if math.random(1, 100) <= 75 then -- 75% chance to inherit each passive
                table.insert(inherited_passives, passive)
                if #inherited_passives >= 4 then
                    break
                end
            end
        end
        
        return inherited_passives
    end
end

-- ================================================
-- SORTING PASSIVES BY RARITY
-- ================================================
function PalBreedingSystem:SortPassivesByRarity(passives)
    local rarity_order = {legendary = 5, epic = 4, rare = 3, uncommon = 2, common = 1}
    
    local function getRarityValue(passive)
        for rarity, passive_list in pairs(PASSIVE_RARITIES) do
            for _, p in ipairs(passive_list) do
                if p == passive then
                    return rarity_order[rarity] or 0
                end
            end
        end
        return 0
    end
    
    table.sort(passives, function(a, b)
        return getRarityValue(a) > getRarityValue(b)
    end)
    
    return passives
end

-- ================================================
-- SUCCESS RATE CALCULATION
-- ================================================
function PalBreedingSystem:CalculateSuccessRate(parent1, parent2, facility_type, species_modifier)
    local base_rate = BREEDING_CONFIG.SUCCESS_RATE_BASE
    
    -- Facility bonus
    local facility_bonus = BREEDING_CONFIG.BREEDING_FACILITIES[facility_type].success_bonus or 0
    
    -- Perfect parents bonus
    local perfect_bonus = 0
    if parent1.is_perfect then perfect_bonus = perfect_bonus + BREEDING_CONFIG.PERFECT_BONUS_RATE end
    if parent2.is_perfect then perfect_bonus = perfect_bonus + BREEDING_CONFIG.PERFECT_BONUS_RATE end
    
    -- High generation penalty
    local avg_generation = (parent1.generation + parent2.generation) / 2
    local generation_penalty = math.max(0, (avg_generation - 2) * BREEDING_CONFIG.GENERATION_PENALTY)
    
    -- Species modifier
    local species_bonus = species_modifier or 0
    
    -- Final calculation
    local final_rate = base_rate + facility_bonus + perfect_bonus - generation_penalty + species_bonus
    
    -- Ensure it's between 10% and 95%
    final_rate = math.max(10, math.min(95, final_rate))
    
    return final_rate
end

-- ================================================
-- BREEDING COST CALCULATION
-- ================================================
function PalBreedingSystem:CalculateBreedingCost(parent1, parent2, facility_type)
    local base_cost = BREEDING_CONFIG.BREEDING_COST_BASE
    
    -- Facility multiplier
    local facility_multiplier = BREEDING_CONFIG.BREEDING_FACILITIES[facility_type].cost_multiplier or 1.0
    
    -- Cost based on parents' value
    local parents_value = parent1.breeding_value + parent2.breeding_value
    local value_cost = parents_value * 0.1 -- 10% of the total parents' value
    
    -- Cost per generation
    local avg_generation = (parent1.generation + parent2.generation) / 2
    local generation_cost = avg_generation * 200
    
    local total_cost = math.floor((base_cost + value_cost + generation_cost) * facility_multiplier)
    
    return total_cost
end

-- ================================================
-- MAIN BREEDING FUNCTION
-- ================================================
function PalBreedingSystem:PerformBreeding(parent1_id, parent2_id, facility_type, data)
    facility_type = facility_type or "basic"
    
    -- Try multiple methods to find PalCentralCore
    local core = _G.PalCentralCoreInstance or 
                package.loaded["PalCentralCoreInstance"] or 
                package.loaded["PalCentralCore"]
    
    -- Try file-based approach if others fail
    if not core then
        local success, file_core = pcall(dofile, "palcentral_instance.lua")
        if success and file_core then
            core = file_core
        end
    end
    
    if not core then
        self:LogBreeding("Error: PalCentralCoreInstance not available.", "ERROR")
        return nil, "Central system not initialized"
    end
    
    -- Fetch parents
    local parent1, err1 = core:GetPal(parent1_id, data)
    if not parent1 then
        return nil, "Parent 1 not found: " .. (err1 or "unknown error")
    end
    
    local parent2, err2 = core:GetPal(parent2_id, data)
    if not parent2 then
        return nil, "Parent 2 not found: " .. (err2 or "unknown error")
    end
    
    -- Validate the pair
    local is_valid, validation_error = self:ValidateBreedingPair(parent1, parent2, data)
    if not is_valid then
        return nil, validation_error
    end
    
    -- Determine offspring species
    local offspring_species, species_modifier = self:DetermineOffspringSpecies(parent1, parent2)
    
    -- Calculate success rate
    local success_rate = self:CalculateSuccessRate(parent1, parent2, facility_type, species_modifier)
    
    -- Calculate cost
    local breeding_cost = self:CalculateBreedingCost(parent1, parent2, facility_type)
    
    -- Check if breeding was successful
    local breeding_success = math.random(1, 100) <= success_rate
    
    if not breeding_success then
        -- Update cooldowns even on failure
        local current_time = os.time()
        core:UpdatePal(parent1_id, {
            last_bred = current_time,
            bred_count = (parent1.bred_count or 0) + 1
        }, data)
        
        core:UpdatePal(parent2_id, {
            last_bred = current_time,
            bred_count = (parent2.bred_count or 0) + 1
        }, data)
        
        self:LogBreeding("Breeding failed between " .. parent1.name .. " and " .. parent2.name .. " (Rate: " .. success_rate .. "%)", "WARN")
        return nil, "Breeding failed! Success rate was " .. success_rate .. "%"
    end
    
    -- Create the offspring
    local offspring_data = {
        species = offspring_species,
        name = "Offspring of " .. parent1.name .. " x " .. parent2.name,
        level = 1,
        exp = 0,
        stats = self:CalculateOffspringStats(parent1, parent2),
        passives = self:InheritPassives(parent1, parent2),
        gender = math.random(1, 2) == 1 and "male" or "female",
        parent1_id = parent1_id,
        parent2_id = parent2_id,
        generation = math.max(parent1.generation, parent2.generation) + 1,
        owner_id = parent1.owner_id,
        bred_count = 0,
        market_status = "available"
    }
    
    local offspring, create_error = core:CreatePal(offspring_data)
    if not offspring then
        return nil, "Error creating offspring: " .. (create_error or "unknown error")
    end
    
    -- Add to the database
    data.pals[offspring.id] = offspring
    
    -- Consume parents if configured
    if BREEDING_CONFIG.CONSUME_PARENTS then
        data.pals[parent1_id] = nil -- Remove parent1 from the database
        data.pals[parent2_id] = nil -- Remove parent2 from the database
        self:LogBreeding("Parents consumed in breeding: " .. parent1.name .. " and " .. parent2.name, "INFO")
    else
        -- Update parents with cooldown and counter
        local current_time = os.time()
        core:UpdatePal(parent1_id, {
            last_bred = current_time,
            bred_count = (parent1.bred_count or 0) + 1
        }, data)
        
        core:UpdatePal(parent2_id, {
            last_bred = current_time,
            bred_count = (parent2.bred_count or 0) + 1
        }, data)
        self:LogBreeding("Parents updated with cooldown: " .. parent1.name .. " and " .. parent2.name, "INFO")
    end
    
    -- Record in the breeding history of PalCentralCore
    if not data.breeding then
        data.breeding = {combinations = {}, success_rates = {}}
    end
    
    table.insert(data.breeding.combinations, {
        parent1_species = parent1.species,
        parent2_species = parent2.species,
        offspring_species = offspring_species,
        success_rate = success_rate,
        timestamp = os.time(),
        facility_used = facility_type,
        cost = breeding_cost,
        offspring_id = offspring.id -- Add offspring ID for tracking
    })
    
    self:LogBreeding("Breeding successful! " .. offspring.name .. " was born from " .. parent1.name .. " x " .. parent2.name .. " (ID: " .. offspring.id .. ")", "INFO")
    
    return {
        offspring = offspring,
        success_rate = success_rate,
        cost = breeding_cost,
        parents_consumed = BREEDING_CONFIG.CONSUME_PARENTS,
        facility_used = facility_type
    }, nil
end

-- ================================================
-- OFFSPRING STATS CALCULATION
-- ================================================
function PalBreedingSystem:CalculateOffspringStats(parent1, parent2)
    local offspring_stats = {}
    
    for stat_name, _ in pairs(parent1.stats) do
        -- Average of parents' stats with random variation
        local avg_stat = (parent1.stats[stat_name] + parent2.stats[stat_name]) / 2
        local variation = math.random(-10, 15) -- -10% to +15% variation
        local final_stat = math.floor(avg_stat * (1 + variation/100))
        
        offspring_stats[stat_name] = math.max(1, final_stat)
    end
    
    return offspring_stats
end

-- ================================================
-- BREEDING PREVIEW SYSTEM
-- ================================================
function PalBreedingSystem:PreviewBreeding(parent1_id, parent2_id, facility_type, data)
    facility_type = facility_type or "basic"
    
    -- Try multiple methods to find PalCentralCore
    local core = _G.PalCentralCoreInstance or 
                package.loaded["PalCentralCoreInstance"] or 
                package.loaded["PalCentralCore"]
    
    -- Try file-based approach if others fail
    if not core then
        local success, file_core = pcall(dofile, "palcentral_instance.lua")
        if success and file_core then
            core = file_core
        end
    end
    
    if not core then
        self:LogBreeding("Error: PalCentralCoreInstance not available for preview.", "ERROR")
        return nil, "Central system not initialized for preview"
    end
    
    local parent1, err1 = core:GetPal(parent1_id, data)
    local parent2, err2 = core:GetPal(parent2_id, data)
    
    if not parent1 or not parent2 then
        return nil, "Parents not found"
    end
    
    local is_valid, validation_error = self:ValidateBreedingPair(parent1, parent2, data)
    if not is_valid then
        return nil, validation_error
    end
    
    local offspring_species, species_modifier = self:DetermineOffspringSpecies(parent1, parent2)
    local success_rate = self:CalculateSuccessRate(parent1, parent2, facility_type, species_modifier)
    local breeding_cost = self:CalculateBreedingCost(parent1, parent2, facility_type)
    local predicted_passives = self:InheritPassives(parent1, parent2)
    
    return {
        offspring_species = offspring_species,
        success_rate = success_rate,
        cost = breeding_cost,
        predicted_passives = predicted_passives,
        predicted_generation = math.max(parent1.generation, parent2.generation) + 1,
        parents_will_be_consumed = BREEDING_CONFIG.CONSUME_PARENTS,
        facility_bonus = BREEDING_CONFIG.BREEDING_FACILITIES[facility_type].success_bonus
    }, nil
end

-- ================================================
-- INITIALIZATION CHECK
-- ================================================
-- Debug: Show what globals we can see
print("[BreedingCore] Checking for PalCentralCore...")
print("[BreedingCore] _G.PalCentralCoreInstance =", _G.PalCentralCoreInstance and "FOUND" or "NOT FOUND")
print("[BreedingCore] package.loaded['PalCentralCoreInstance'] =", package.loaded["PalCentralCoreInstance"] and "FOUND" or "NOT FOUND")
print("[BreedingCore] package.loaded['PalCentralCore'] =", package.loaded["PalCentralCore"] and "FOUND" or "NOT FOUND")
print("[BreedingCore] Available global Pal* variables:")
for k, v in pairs(_G) do
    if type(k) == "string" and string.find(k, "Pal") then
        print("  - " .. k .. " = " .. type(v))
    end
end

-- Try multiple methods to find PalCentralCore (check each explicitly)
local core = nil
if _G.PalCentralCoreInstance then
    core = _G.PalCentralCoreInstance
    print("[BreedingCore] Found via _G.PalCentralCoreInstance")
elseif package.loaded["PalCentralCoreInstance"] then
    core = package.loaded["PalCentralCoreInstance"]
    print("[BreedingCore] Found via package.loaded['PalCentralCoreInstance']")
elseif package.loaded["PalCentralCore"] then
    core = package.loaded["PalCentralCore"]
    print("[BreedingCore] Found via package.loaded['PalCentralCore']")
else
    -- Try file-based approach
    local success, file_core = pcall(dofile, "palcentral_instance.lua")
    if success and file_core then
        core = file_core
        print("[BreedingCore] Found via file-based communication (palcentral_instance.lua)")
    else
        print("[BreedingCore] File-based load failed:", file_core or "unknown error")
    end
end

-- Verify that PalCentralCore is available
if not core then
    print("[BreedingCore] WARNING: PalCentralCore not found! Some features may not work properly.")
    print("[BreedingCore] Please ensure PalCentralCore loads before BreedingCore.")
else
    print("[BreedingCore] PalCentralCore dependency satisfied. Breeding system ready!")
    core:Log("[BreedingCore] Breeding system initialized successfully!", "INFO")
    -- Update the global reference for future use
    _G.PalCentralCoreInstance = core
end

-- ================================================
-- EXPORT MODULE
-- ================================================
_G.PalBreedingSystemInstance = PalBreedingSystem -- Expose the module instance globally
return PalBreedingSystem