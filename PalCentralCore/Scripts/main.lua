-- ================================================
-- PALWORLD CENTRAL DATA AND FUNCTIONS MOD
-- Version: 1.0.0
-- Description: Central system for handling Pal data
-- ================================================
local json = require("json") -- Add this line at the top!
print("THE CENTRAL MOD IS WORKING!!!!!!!!!!!!!!!!!")
local PalCentralCore = {}
PalCentralCore.__index = PalCentralCore

-- ================================================
-- GLOBAL CONFIGURATIONS
-- ================================================
local CONFIG = {
    MOD_VERSION = "1.0.0",
    DEBUG_MODE = true,
    DATABASE_FILE = "palworld_central_data.json",
    MAX_PAL_LEVEL = 50,
    MAX_BREEDING_ATTEMPTS = 3,
    BACKUP_INTERVAL = 300 -- 5 minutes
}

-- ================================================
-- PAL DATA STRUCTURE
-- ================================================
local PAL_DATA_STRUCTURE = {
    id = "",
    species = "",
    name = "",
    level = 1,
    exp = 0,
    stats = {
        hp = 0,
        attack = 0,
        defense = 0,
        work_speed = 0,
        food = 0
    },
    passives = {}, -- Array of passives
    breeding_value = 0, -- Market value based on passives
    gender = "", -- "male" or "female"
    parent1_id = nil,
    parent2_id = nil,
    generation = 1,
    owner_id = "",
    creation_date = 0,
    last_bred = 0,
    bred_count = 0,
    is_perfect = false, -- 4 perfect passives
    market_status = "available", -- "available", "for_sale", "in_auction"
    custom_data = {} -- For future expansions
}

-- ================================================
-- LOG AND DEBUG SYSTEM
-- ================================================
function PalCentralCore:Log(message, level)
    level = level or "INFO"
    if CONFIG.DEBUG_MODE then
        local timestamp = os.date("%Y-%m-%d %H:%M:%S")
        print(string.format("[%s][%s] %s", timestamp, level, message))
        
        -- Save to log file if needed
        local log_file = io.open("palworld_mod.log", "a")
        if log_file then
            log_file:write(string.format("[%s][%s] %s\n", timestamp, level, message))
            log_file:close()
        end
    end
end

-- ================================================
-- PERSISTENT DATA SYSTEM
-- ================================================
function PalCentralCore:LoadData()
    local file = io.open(CONFIG.DATABASE_FILE, "r")
    if not file then
        self:Log("Data file not found, creating new...", "WARN")
        return {
            pals = {},
            players = {},
            market = {
                direct_sales = {},
                auctions = {},
                trade_history = {}
            },
            breeding = {
                combinations = {},
                success_rates = {}
            },
            ranking = {
                seasons = {},
                current_season = 1,
                leaderboard = {}
            }
        }
    end
    
    local content = file:read("*all")
    file:close()
    
    local data = {}
    local success, result = pcall(function()
        return json.decode(content)
    end)
    
    if success then
        data = result
        self:Log("Data loaded successfully!")
    else
        self:Log("Error loading data: " .. tostring(result), "ERROR")
        data = self:LoadData() -- Recurse to create new data
    end
    
    return data
end

function PalCentralCore:SaveData(data)
    local success, json_string = pcall(function()
        return json.encode(data)
    end)
    
    if not success then
        self:Log("Error serializing data: " .. tostring(json_string), "ERROR")
        return false
    end
    
    local file = io.open(CONFIG.DATABASE_FILE, "w")
    if not file then
        self:Log("Error opening file for writing", "ERROR")
        return false
    end
    
    file:write(json_string)
    file:close()
    
    self:Log("Data saved successfully!")
    return true
end

-- ================================================
-- UNIQUE ID GENERATION SYSTEM
-- ================================================
function PalCentralCore:GenerateUniqueID(prefix)
    prefix = prefix or "PAL"
    local timestamp = tostring(os.time())
    local random = tostring(math.random(1000, 9999))
    return prefix .. "_" .. timestamp .. "_" .. random
end

-- ================================================
-- PAL VALIDATION SYSTEM
-- ================================================
function PalCentralCore:ValidatePalData(pal_data)
    if not pal_data then
        return false, "Pal data not provided"
    end
    
    -- Check required fields
    local required_fields = {"species", "name", "level", "stats", "passives", "gender", "owner_id"}
    for _, field in ipairs(required_fields) do
        if not pal_data[field] then
            return false, "Required field missing: " .. field
        end
    end
    
    -- Validate level
    if pal_data.level < 1 or pal_data.level > CONFIG.MAX_PAL_LEVEL then
        return false, "Invalid level: must be between 1 and " .. CONFIG.MAX_PAL_LEVEL
    end
    
    -- Validate passives (maximum 4)
    if #pal_data.passives > 4 then
        return false, "Maximum of 4 passives allowed"
    end
    
    -- Validate gender
    if pal_data.gender ~= "male" and pal_data.gender ~= "female" then
        return false, "Gender must be 'male' or 'female'"
    end
    
    return true, "Data valid"
end

-- ================================================
-- PAL HANDLING SYSTEM
-- ================================================
function PalCentralCore:CreatePal(pal_data)
    local is_valid, error_msg = self:ValidatePalData(pal_data)
    if not is_valid then
        self:Log("Pal validation error: " .. error_msg, "ERROR")
        return nil, error_msg
    end
    
    -- Create complete Pal structure
    local new_pal = {}
    for key, value in pairs(PAL_DATA_STRUCTURE) do
        if type(value) == "table" then
            new_pal[key] = {}
            for sub_key, sub_value in pairs(value) do
                new_pal[key][sub_key] = pal_data[key] and pal_data[key][sub_key] or sub_value
            end
        else
            new_pal[key] = pal_data[key] or value
        end
    end
    
    -- Generate unique ID
    new_pal.id = self:GenerateUniqueID("PAL")
    new_pal.creation_date = os.time()
    
    -- Calculate breeding value based on passives
    new_pal.breeding_value = self:CalculateBreedingValue(new_pal)
    
    -- Check if perfect (4 passives)
    new_pal.is_perfect = (#new_pal.passives == 4)
    
    self:Log("Pal created: " .. new_pal.name .. " (" .. new_pal.id .. ")")
    return new_pal, nil
end

function PalCentralCore:GetPal(pal_id, data)
    if not data or not data.pals then
        return nil, "Database not initialized"
    end
    
    for _, pal in pairs(data.pals) do
        if pal.id == pal_id then
            return pal, nil
        end
    end
    
    return nil, "Pal not found"
end

function PalCentralCore:UpdatePal(pal_id, updates, data)
    local pal, error_msg = self:GetPal(pal_id, data)
    if not pal then
        return false, error_msg
    end
    
    -- Apply updates
    for key, value in pairs(updates) do
        if PAL_DATA_STRUCTURE[key] ~= nil then
            pal[key] = value
        end
    end
    
    -- Recalculate breeding value if needed
    if updates.passives then
        pal.breeding_value = self:CalculateBreedingValue(pal)
        pal.is_perfect = (#pal.passives == 4)
    end
    
    self:Log("Pal updated: " .. pal.name .. " (" .. pal_id .. ")")
    return true, nil
end

-- ================================================
-- BREEDING VALUE CALCULATION SYSTEM
-- ================================================
function PalCentralCore:CalculateBreedingValue(pal)
    if not pal or not pal.passives then
        return 0
    end
    
    local base_value = 100
    local passive_multiplier = {
        [1] = 1.0,   -- 1 passive
        [2] = 2.5,   -- 2 passives
        [3] = 5.0,   -- 3 passives
        [4] = 10.0   -- 4 passives (perfect)
    }
    
    local num_passives = #pal.passives
    local multiplier = passive_multiplier[num_passives] or 1.0
    
    -- Bonus for level
    local level_bonus = pal.level * 10
    
    -- Bonus for generation (quality parents)
    local generation_bonus = (pal.generation - 1) * 50
    
    return math.floor(base_value * multiplier + level_bonus + generation_bonus)
end

-- ================================================
-- SEARCH AND FILTER SYSTEM
-- ================================================
function PalCentralCore:SearchPals(data, filters)
    if not data or not data.pals then
        return {}
    end
    
    local results = {}
    
    for _, pal in pairs(data.pals) do
        local matches = true
        
        -- Filter by species
        if filters.species and pal.species ~= filters.species then
            matches = false
        end
        
        -- Filter by owner
        if filters.owner_id and pal.owner_id ~= filters.owner_id then
            matches = false
        end
        
        -- Filter by minimum level
        if filters.min_level and pal.level < filters.min_level then
            matches = false
        end
        
        -- Filter by number of passives
        if filters.min_passives and #pal.passives < filters.min_passives then
            matches = false
        end
        
        -- Filter by market status
        if filters.market_status and pal.market_status ~= filters.market_status then
            matches = false
        end
        
        -- Filter by perfect status
        if filters.is_perfect ~= nil and pal.is_perfect ~= filters.is_perfect then
            matches = false
        end
        
        if matches then
            table.insert(results, pal)
        end
    end
    
    return results
end

-- ================================================
-- AUTOMATIC BACKUP SYSTEM
-- ================================================
function PalCentralCore:StartAutoBackup(data)
    -- This function would be called periodically by the server
    local backup_file = "backup_" .. os.date("%Y%m%d_%H%M%S") .. "_" .. CONFIG.DATABASE_FILE
    
    local file = io.open(backup_file, "w")
    if file then
        local json_string = json.encode(data)
        file:write(json_string)
        file:close()
        self:Log("Backup created: " .. backup_file)
        
        -- Keep only the 10 most recent backups (implement cleanup)
        return true
    end
    
    return false
end

-- ================================================
-- SYSTEM INITIALIZATION
-- ================================================
function PalCentralCore:Initialize()
    self:Log("Initializing Central Data Mod v" .. CONFIG.MOD_VERSION)
    
    local data = self:LoadData()
    
    -- Verify data integrity
    if not data.pals then data.pals = {} end
    if not data.players then data.players = {} end
    if not data.market then 
        data.market = {
            direct_sales = {},
            auctions = {},
            trade_history = {}
        }
    end
    
    self:Log("Central Mod initialized successfully!")
    return data
end

-- ================================================
-- EXPORT MODULE
-- ================================================
_G.PalCentralCoreInstance = PalCentralCore:Initialize() -- Initialize and store globally for testing
return PalCentralCore