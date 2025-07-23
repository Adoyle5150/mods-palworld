-- ================================================
-- MARKET MOD - PALWORLD
-- Version: 1.0.0
-- Description: Complete economic system with sales and auctions
-- ================================================
-- Dependencies
local core = _G.PalCentralCoreInstance -- Use the global core instance
local breedingSystem = require("BreedingCore.Scripts.main") -- This one yes, as it is a separate module
local PalMarketSystem = {}
PalMarketSystem.__index = PalMarketSystem

-- ================================================
-- MARKET CONFIGURATIONS
-- ================================================
local MARKET_CONFIG = {
    MARKET_TAX_RATE = 0.05, -- 5% tax on sales
    AUCTION_DURATION = 86400, -- 24 hours in seconds
    MIN_AUCTION_INCREMENT = 100, -- Minimum increment in auctions
    MAX_LISTINGS_PER_PLAYER = 10,
    DIRECT_SALE_EXPIRY = 604800, -- 7 days for direct sales
    TRADE_TIMEOUT = 300, -- 5 minutes to accept trades
    MINIMUM_SALE_PRICE = 50,
    AUCTION_START_PERCENTAGE = 0.7, -- 70% of the estimated value
    FEATURED_LISTINGS_COUNT = 5,
    SEARCH_RESULTS_LIMIT = 50,
    
    -- Listing categories
    CATEGORIES = {
        "all", "perfect", "rare_passives", "high_level", "breeding_ready", 
        "new_generation", "specific_species", "competitive"
    }
}

-- ================================================
-- MARKET DATA STRUCTURES
-- ================================================
local LISTING_STRUCTURE = {
    id = "",
    type = "", -- "direct_sale", "auction", "trade_offer"
    pal_id = "",
    seller_id = "",
    price = 0, -- For direct sales
    starting_bid = 0, -- For auctions
    current_bid = 0,
    current_bidder = "",
    buyout_price = 0, -- Price for immediate purchase in auctions
    created_at = 0,
    expires_at = 0,
    status = "", -- "active", "sold", "expired", "cancelled"
    description = "",
    category = "all",
    featured = false,
    view_count = 0,
    bid_history = {}, -- Array of bids for auctions
    trade_offers = {} -- Array of trade offers
}

local BID_STRUCTURE = {
    bidder_id = "",
    amount = 0,
    timestamp = 0,
    auto_bid = false -- Auto-bid system
}

local TRADE_OFFER_STRUCTURE = {
    id = "",
    offeror_id = "",
    offered_pals = {}, -- Array of offered Pal IDs
    gold_amount = 0,
    message = "",
    created_at = 0,
    expires_at = 0,
    status = "pending" -- "pending", "accepted", "rejected", "expired"
}

-- ================================================
-- MARKET LOG SYSTEM
-- ================================================
function PalMarketSystem:LogMarket(message, level)
    level = level or "INFO"
    local core = {}
    setmetatable(core, PalCentralCore)
    core:Log("[MARKET] " .. message, level)
end

-- ================================================
-- LISTING VALIDATION
-- ================================================
function PalMarketSystem:ValidateListing(pal_id, seller_id, listing_type, data)
    local core = {}
    setmetatable(core, PalCentralCore)
    
    -- Check if the Pal exists
    local pal, error_msg = core:GetPal(pal_id, data)
    if not pal then
        return false, "Pal not found: " .. (error_msg or "unknown error")
    end
    
    -- Check ownership
    if pal.owner_id ~= seller_id then
        return false, "You are not the owner of this Pal"
    end
    
    -- Check if the Pal is available
    if pal.market_status ~= "available" then
        return false, "Pal is not available for sale (Status: " .. pal.market_status .. ")"
    end
    
    -- Check player's listing limit
    local player_listings = self:GetPlayerListings(seller_id, data)
    if #player_listings >= MARKET_CONFIG.MAX_LISTINGS_PER_PLAYER then
        return false, "Listing limit reached (" .. MARKET_CONFIG.MAX_LISTINGS_PER_PLAYER .. ")"
    end
    
    -- Type-specific validations
    if listing_type == "auction" then
        -- Auctions require higher value Pals
        if pal.breeding_value < 500 then
            return false, "Pals in auction must have a minimum value of 500"
        end
    end
    
    return true, "Listing valid"
end

-- ================================================
-- SUGGESTED PRICE CALCULATION
-- ================================================
function PalMarketSystem:CalculateSuggestedPrice(pal)
    if not pal then return 0 end
    
    local base_price = pal.breeding_value
    
    -- Bonus for level
    local level_multiplier = 1 + (pal.level - 1) * 0.05 -- 5% per level above 1
    
    -- Bonus for rare passives
    local passive_bonus = 0
    for _, passive in ipairs(pal.passives) do
        if self:IsPassiveRare(passive) then
            passive_bonus = passive_bonus + 200
        elseif self:IsPassiveEpic(passive) then
            passive_bonus = passive_bonus + 500
        elseif self:IsPassiveLegendary(passive) then
            passive_bonus = passive_bonus + 1000
        end
    end
    
    -- Bonus for perfection
    local perfect_multiplier = pal.is_perfect and 2.0 or 1.0
    
    -- Penalty for high generation
    local generation_penalty = math.max(0, (pal.generation - 2) * 0.1)
    
    -- Final calculation
    local final_price = math.floor((base_price + passive_bonus) * level_multiplier * perfect_multiplier * (1 - generation_penalty))
    
    return math.max(MARKET_CONFIG.MINIMUM_SALE_PRICE, final_price)
end

-- ================================================
-- PASSIVE RARITY VERIFICATION
-- ================================================
function PalMarketSystem:IsPassiveRare(passive)
    local rare_passives = {"Legend", "Musclehead", "Ferocious", "Burly Body", "Aggressive"}
    for _, rare_passive in ipairs(rare_passives) do
        if passive == rare_passive then return true end
    end
    return false
end

function PalMarketSystem:IsPassiveEpic(passive)
    local epic_passives = {"Lord of Lightning", "Lord of the Sea", "Spirit Emperor", "Flame Emperor"}
    for _, epic_passive in ipairs(epic_passives) do
        if passive == epic_passive then return true end
    end
    return false
end

function PalMarketSystem:IsPassiveLegendary(passive)
    local legendary_passives = {"Alpha", "Emperor", "Divine Dragon", "Transcendent"}
    for _, legendary_passive in ipairs(legendary_passives) do
        if passive == legendary_passive then return true end
    end
    return false
end

-- ================================================
-- DIRECT SALE CREATION
-- ================================================
function PalMarketSystem:CreateDirectSale(pal_id, seller_id, price, description, category, data)
    category = category or "all"
    description = description or ""
    
    -- Validate listing
    local is_valid, validation_error = self:ValidateListing(pal_id, seller_id, "direct_sale", data)
    if not is_valid then
        return nil, validation_error
    end
    
    -- Validate price
    if price < MARKET_CONFIG.MINIMUM_SALE_PRICE then
        return nil, "Minimum price is " .. MARKET_CONFIG.MINIMUM_SALE_PRICE .. " gold"
    end
    
    local core = {}
    setmetatable(core, PalCentralCore)
    
    -- Create listing
    local listing = {}
    for key, value in pairs(LISTING_STRUCTURE) do
        listing[key] = value
    end
    
    listing.id = core:GenerateUniqueID("SALE")
    listing.type = "direct_sale"
    listing.pal_id = pal_id
    listing.seller_id = seller_id
    listing.price = price
    listing.created_at = os.time()
    listing.expires_at = os.time() + MARKET_CONFIG.DIRECT_SALE_EXPIRY
    listing.status = "active"
    listing.description = description
    listing.category = category
    
    -- Add to database
    if not data.market then
        data.market = {direct_sales = {}, auctions = {}, trade_history = {}}
    end
    
    data.market.direct_sales[listing.id] = listing
    
    -- Update Pal status
    core:UpdatePal(pal_id, {market_status = "for_sale"}, data)
    
    self:LogMarket("Direct sale created: " .. listing.id .. " for " .. price .. " gold")
    return listing, nil
end

-- ================================================
-- AUCTION CREATION
-- ================================================
function PalMarketSystem:CreateAuction(pal_id, seller_id, starting_bid, buyout_price, description, category, data)
    category = category or "all"
    description = description or ""
    buyout_price = buyout_price or 0
    
    -- Validate listing
    local is_valid, validation_error = self:ValidateListing(pal_id, seller_id, "auction", data)
    if not is_valid then
        return nil, validation_error
    end
    
    -- Calculate suggested starting price if not provided
    if starting_bid <= 0 then
        local core = {}
        setmetatable(core, PalCentralCore)
        local pal = core:GetPal(pal_id, data)
        starting_bid = math.floor(self:CalculateSuggestedPrice(pal) * MARKET_CONFIG.AUCTION_START_PERCENTAGE)
    end
    
    if starting_bid < MARKET_CONFIG.MINIMUM_SALE_PRICE then
        return nil, "Minimum starting bid is " .. MARKET_CONFIG.MINIMUM_SALE_PRICE .. " gold"
    end
    
    if buyout_price > 0 and buyout_price <= starting_bid then
        return nil, "Buyout price must be higher than the starting bid"
    end
    
    local core = {}
    setmetatable(core, PalCentralCore)
    
    -- Create auction
    local auction = {}
    for key, value in pairs(LISTING_STRUCTURE) do
        auction[key] = value
    end
    
    auction.id = core:GenerateUniqueID("AUCTION")
    auction.type = "auction"
    auction.pal_id = pal_id
    auction.seller_id = seller_id
    auction.starting_bid = starting_bid
    auction.current_bid = starting_bid
    auction.current_bidder = ""
    auction.buyout_price = buyout_price
    auction.created_at = os.time()
    auction.expires_at = os.time() + MARKET_CONFIG.AUCTION_DURATION
    auction.status = "active"
    auction.description = description
    auction.category = category
    auction.bid_history = {}
    
    -- Add to database
    if not data.market then
        data.market = {direct_sales = {}, auctions = {}, trade_history = {}}
    end
    
    data.market.auctions[auction.id] = auction
    
    -- Update Pal status
    core:UpdatePal(pal_id, {market_status = "in_auction"}, data)
    
    self:LogMarket("Auction created: " .. auction.id .. " with starting bid of " .. starting_bid .. " gold")
    return auction, nil
end

-- ================================================
-- BIDDING SYSTEM
-- ================================================
function PalMarketSystem:PlaceBid(auction_id, bidder_id, bid_amount, data)
    if not data.market or not data.market.auctions[auction_id] then
        return false, "Auction not found"
    end
    
    local auction = data.market.auctions[auction_id]
    
    -- Check if the auction is active
    if auction.status ~= "active" then
        return false, "Auction is no longer active"
    end
    
    -- Check if it has expired
    if os.time() > auction.expires_at then
        auction.status = "expired"
        return false, "Auction expired"
    end
    
    -- Check if it is not the seller themselves
    if bidder_id == auction.seller_id then
        return false, "Seller cannot bid on their own auction"
    end
    
    -- Check minimum increment
    local minimum_bid = auction.current_bid + MARKET_CONFIG.MIN_AUCTION_INCREMENT
    if bid_amount < minimum_bid then
        return false, "Minimum bid is " .. minimum_bid .. " gold"
    end
    
    -- Register bid
    local bid = {
        bidder_id = bidder_id,
        amount = bid_amount,
        timestamp = os.time(),
        auto_bid = false
    }
    
    table.insert(auction.bid_history, bid)
    auction.current_bid = bid_amount
    auction.current_bidder = bidder_id
    
    -- Check for buyout
    if auction.buyout_price > 0 and bid_amount >= auction.buyout_price then
        return self:ExecuteBuyout(auction_id, bidder_id, data)
    end
    
    self:LogMarket("Bid of " .. bid_amount .. " gold placed on auction " .. auction_id)
    return true, "Bid registered successfully"
end

-- ================================================
-- BUYOUT
-- ================================================
function PalMarketSystem:ExecuteBuyout(auction_id, buyer_id, data)
    local auction = data.market.auctions[auction_id]
    
    return self:CompleteSale(auction.pal_id, auction.seller_id, buyer_id, auction.buyout_price, "buyout", data)
end

-- ================================================
-- DIRECT PURCHASE
-- ================================================
function PalMarketSystem:PurchaseDirectSale(sale_id, buyer_id, data)
    if not data.market or not data.market.direct_sales[sale_id] then
        return false, "Sale not found"
    end
    
    local sale = data.market.direct_sales[sale_id]
    
    if sale.status ~= "active" then
        return false, "Sale is no longer active"
    end
    
    if os.time() > sale.expires_at then
        sale.status = "expired"
        return false, "Sale expired"
    end
    
    if buyer_id == sale.seller_id then
        return false, "Cannot buy your own Pal"
    end
    
    return self:CompleteSale(sale.pal_id, sale.seller_id, buyer_id, sale.price, "direct_sale", data)
end

-- ================================================
-- SALE FINALIZATION
-- ================================================
function PalMarketSystem:CompleteSale(pal_id, seller_id, buyer_id, sale_price, sale_type, data)
    local core = {}
    setmetatable(core, PalCentralCore)
    
    -- Check if the Pal still exists
    local pal, error_msg = core:GetPal(pal_id, data)
    if not pal then
        return false, "Pal not found: " .. (error_msg or "unknown error")
    end
    
    -- Calculate market tax
    local market_tax = math.floor(sale_price * MARKET_CONFIG.MARKET_TAX_RATE)
    local seller_receives = sale_price - market_tax
    
    -- Transfer Pal ownership
    core:UpdatePal(pal_id, {
        owner_id = buyer_id,
        market_status = "available"
    }, data)
    
    -- Record transaction in history
    local transaction = {
        id = core:GenerateUniqueID("TRADE"),
        pal_id = pal_id,
        seller_id = seller_id,
        buyer_id = buyer_id,
        sale_price = sale_price,
        market_tax = market_tax,
        seller_receives = seller_receives,
        sale_type = sale_type,
        timestamp = os.time()
    }
    
    if not data.market.trade_history then
        data.market.trade_history = {}
    end
    table.insert(data.market.trade_history, transaction)
    
    -- Remove from active listings
    if sale_type == "direct_sale" then
        for sale_id, sale in pairs(data.market.direct_sales or {}) do
            if sale.pal_id == pal_id then
                sale.status = "sold"
                break
            end
        end
    elseif sale_type == "auction" or sale_type == "buyout" then
        for auction_id, auction in pairs(data.market.auctions or {}) do
            if auction.pal_id == pal_id then
                auction.status = "sold"
                break
            end
        end
    end
    
    self:LogMarket("Sale completed: " .. pal.name .. " for " .. sale_price .. " gold (" .. sale_type .. ")")
    
    return true, {
        transaction = transaction,
        pal_transferred = pal,
        seller_receives = seller_receives,
        market_tax = market_tax
    }
end

-- ================================================
-- MARKET SEARCH
-- ================================================
function PalMarketSystem:SearchMarket(filters, data)
    if not data.market then
        return {}
    end
    
    local results = {}
    local core = {}
    setmetatable(core, PalCentralCore)
    
    -- Search in direct sales
    for _, sale in pairs(data.market.direct_sales or {}) do
        if sale.status == "active" and os.time() <= sale.expires_at then
            local pal = core:GetPal(sale.pal_id, data)
            if pal and self:MatchesFilters(pal, sale, filters) then
                table.insert(results, {
                    type = "direct_sale",
                    listing = sale,
                    pal = pal,
                    current_price = sale.price
                })
            end
        end
    end
    
    -- Search in auctions
    for _, auction in pairs(data.market.auctions or {}) do
        if auction.status == "active" and os.time() <= auction.expires_at then
            local pal = core:GetPal(auction.pal_id, data)
            if pal and self:MatchesFilters(pal, auction, filters) then
                table.insert(results, {
                    type = "auction",
                    listing = auction,
                    pal = pal,
                    current_price = auction.current_bid,
                    time_remaining = auction.expires_at - os.time()
                })
            end
        end
    end
    
    -- Sort results
    table.sort(results, function(a, b)
        if filters.sort_by == "price_low" then
            return a.current_price < b.current_price
        elseif filters.sort_by == "price_high" then
            return a.current_price > b.current_price
        elseif filters.sort_by == "level" then
            return a.pal.level > b.pal.level
        elseif filters.sort_by == "breeding_value" then
            return a.pal.breeding_value > b.pal.breeding_value
        else -- Default: most recent
            return a.listing.created_at > b.listing.created_at
        end
    end)
    
    -- Limit results
    local limited_results = {}
    for i = 1, math.min(#results, MARKET_CONFIG.SEARCH_RESULTS_LIMIT) do
        table.insert(limited_results, results[i])
    end
    
    return limited_results
end

-- ================================================
-- FILTER VERIFICATION
-- ================================================
function PalMarketSystem:MatchesFilters(pal, listing, filters)
    if not filters then return true end
    
    -- Filter by species
    if filters.species and pal.species ~= filters.species then
        return false
    end
    
    -- Filter by maximum price
    if filters.max_price then
        local price = listing.type == "direct_sale" and listing.price or listing.current_bid
        if price > filters.max_price then
            return false
        end
    end
    
    -- Filter by minimum price
    if filters.min_price then
        local price = listing.type == "direct_sale" and listing.price or listing.current_bid
        if price < filters.min_price then
            return false
        end
    end
    
    -- Filter by minimum level
    if filters.min_level and pal.level < filters.min_level then
        return false
    end
    
    -- Filter by minimum passives
    if filters.min_passives and #pal.passives < filters.min_passives then
        return false
    end
    
    -- Filter by perfect only
    if filters.perfect_only and not pal.is_perfect then
        return false
    end
    
    -- Filter by category
    if filters.category and filters.category ~= "all" and listing.category ~= filters.category then
        return false
    end
    
    return true
end

-- ================================================
-- GET PLAYER LISTINGS
-- ================================================
function PalMarketSystem:GetPlayerListings(player_id, data)
    if not data.market then return {} end
    
    local listings = {}
    
    -- Direct sales
    for _, sale in pairs(data.market.direct_sales or {}) do
        if sale.seller_id == player_id and sale.status == "active" then
            table.insert(listings, sale)
        end
    end
    
    -- Auctions
    for _, auction in pairs(data.market.auctions or {}) do
        if auction.seller_id == player_id and auction.status == "active" then
            table.insert(listings, auction)
        end
    end
    
    return listings
end

-- ================================================
-- CANCEL LISTING
-- ================================================
function PalMarketSystem:CancelListing(listing_id, player_id, data)
    if not data.market then
        return false, "Market not initialized"
    end
    
    local core = {}
    setmetatable(core, PalCentralCore)
    
    -- Search in direct sales
    if data.market.direct_sales[listing_id] then
        local sale = data.market.direct_sales[listing_id]
        if sale.seller_id ~= player_id then
            return false, "You are not the seller of this listing"
        end
        
        sale.status = "cancelled"
        core:UpdatePal(sale.pal_id, {market_status = "available"}, data)
        
        self:LogMarket("Direct sale cancelled: " .. listing_id)
        return true, "Sale cancelled successfully"
    end
    
    -- Search in auctions
    if data.market.auctions[listing_id] then
        local auction = data.market.auctions[listing_id]
        if auction.seller_id ~= player_id then
            return false, "You are not the seller of this auction"
        end
        
        if #auction.bid_history > 0 then
            return false, "Cannot cancel auction with bids"
        end
        
        auction.status = "cancelled"
        core:UpdatePal(auction.pal_id, {market_status = "available"}, data)
        
        self:LogMarket("Auction cancelled: " .. listing_id)
        return true, "Auction cancelled successfully"
    end
    
    return false, "Listing not found"
end

-- ================================================
-- AUTOMATIC CLEANUP OF EXPIRED LISTINGS
-- ================================================
function PalMarketSystem:CleanupExpiredListings(data)
    if not data.market then return 0 end
    
    local cleaned_count = 0
    local current_time = os.time()
    local core = {}
    setmetatable(core, PalCentralCore)
    
    -- Clean expired direct sales
    for _, sale in pairs(data.market.direct_sales or {}) do
        if sale.status == "active" and current_time > sale.expires_at then
            sale.status = "expired"
            core:UpdatePal(sale.pal_id, {market_status = "available"}, data)
            cleaned_count = cleaned_count + 1
        end
    end
    
    -- Clean expired auctions and finalize with winning bid
    for _, auction in pairs(data.market.auctions or {}) do
        if auction.status == "active" and current_time > auction.expires_at then
            if auction.current_bidder and auction.current_bidder ~= "" then
                -- Finalize sale with winning bid
                self:CompleteSale(auction.pal_id, auction.seller_id, auction.current_bidder, auction.current_bid, "auction", data)
            else
                auction.status = "expired"
                core:UpdatePal(auction.pal_id, {market_status = "available"}, data)
            end
            cleaned_count = cleaned_count + 1
        end
    end
    
    if cleaned_count > 0 then
        self:LogMarket("Automatic cleanup: " .. cleaned_count .. " expired listings processed")
    end
    
    return cleaned_count
end

-- ================================================
-- MARKET STATISTICS
-- ================================================
function PalMarketSystem:GetMarketStatistics(data)
    if not data.market then
        return {
            total_active_listings = 0,
            total_sales_today = 0,
            average_sale_price = 0,
            most_popular_species = "N/A",
            total_market_volume = 0
        }
    end
    
    local stats = {
        total_active_listings = 0,
        active_direct_sales = 0,
        active_auctions = 0,
        total_sales_today = 0,
        total_sales_all_time = 0,
        average_sale_price = 0,
        total_market_volume = 0,
        species_popularity = {},
        most_popular_species = "N/A"
    }
    
    -- Count active listings
    for _, sale in pairs(data.market.direct_sales or {}) do
        if sale.status == "active" then
            stats.active_direct_sales = stats.active_direct_sales + 1
        end
    end
    
    for _, auction in pairs(data.market.auctions or {}) do
        if auction.status == "active" then
            stats.active_auctions = stats.active_auctions + 1
        end
    end
    
    stats.total_active_listings = stats.active_direct_sales + stats.active_auctions
    
    -- Analyze sales history
    local today_start = os.time() - (os.time() % 86400) -- Start of the current day
    local total_sales_value = 0
    
    for _, transaction in ipairs(data.market.trade_history or {}) do
        stats.total_sales_all_time = stats.total_sales_all_time + 1
        total_sales_value = total_sales_value + transaction.sale_price
        
        if transaction.timestamp >= today_start then
            stats.total_sales_today = stats.total_sales_today + 1
        end
        
        -- Count species popularity (would need to fetch the Pal)
        -- stats.species_popularity[pal.species] = (stats.species_popularity[pal.species] or 0) + 1
    end
    
    if stats.total_sales_all_time > 0 then
        stats.average_sale_price = math.floor(total_sales_value / stats.total_sales_all_time)
        stats.total_market_volume = total_sales_value
    end
    
    return stats
end

-- ================================================
-- EXPORT MODULE
-- ================================================
return PalMarketSystem