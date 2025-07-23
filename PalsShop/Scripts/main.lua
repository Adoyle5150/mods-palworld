-- ================================================
-- PALWORLD MARKET MOD
-- Version: 1.0.0
-- Description: Full economic system with sales and auctions
-- ================================================

-- Extend package.path to locate BreedingCore's breeding.lua
package.path = package.path .. ";E:/Palstorm/Pal/Binaries/Win64/Mods/BreedingCore/Scripts/?.lua"

-- Function to wait for PalCentralCore
local function WaitForPalCentralCore()
    local attempts = 0
    local max_attempts = 30 -- Wait up to 30 seconds
    
    while attempts < max_attempts do
        -- Try multiple methods to find PalCentralCore (check each explicitly)
        local core = nil
        if _G.PalCentralCoreInstance then
            core = _G.PalCentralCoreInstance
            print("[PalsShop] Found via _G.PalCentralCoreInstance")
        elseif package.loaded["PalCentralCoreInstance"] then
            core = package.loaded["PalCentralCoreInstance"]
            print("[PalsShop] Found via package.loaded['PalCentralCoreInstance']")
        elseif package.loaded["PalCentralCore"] then
            core = package.loaded["PalCentralCore"]
            print("[PalsShop] Found via package.loaded['PalCentralCore']")
        else
            -- Try file-based approach
            local success, file_core = pcall(dofile, "palcentral_instance.lua")
            if success and file_core then
                core = file_core
                print("[PalsShop] Found via file-based communication (palcentral_instance.lua)")
            end
        end
                    
        if core and core.data then
            print("[PalsShop] PalCentralCore found and ready!")
            return core
        end
        
        -- Also check for file indicator
        local flag_file = io.open("palcentral_ready.flag", "r")
        if flag_file then
            flag_file:close()
            print("[PalsShop] Flag file exists, re-checking package.loaded...")
            -- If flag exists, try one more time to get the instance
            if package.loaded["PalCentralCoreInstance"] then
                core = package.loaded["PalCentralCoreInstance"]
                print("[PalsShop] Found via package.loaded after flag check!")
                if core and core.data then
                    return core
                end
            end
        end
        
        print("[PalsShop] Waiting for PalCentralCoreInstance... (" .. attempts .. "/" .. max_attempts .. ")")
        
        -- Debug: Show what we can see every 5 attempts
        if attempts % 5 == 0 then
            print("[PalsShop] Debug - _G.PalCentralCoreInstance =", _G.PalCentralCoreInstance and "FOUND" or "NOT FOUND")
            print("[PalsShop] Debug - package.loaded['PalCentralCoreInstance'] =", package.loaded["PalCentralCoreInstance"] and "FOUND" or "NOT FOUND")
            print("[PalsShop] Debug - package.loaded['PalCentralCore'] =", package.loaded["PalCentralCore"] and "FOUND" or "NOT FOUND")
            print("[PalsShop] Debug - Available global Pal* variables:")
            for k, v in pairs(_G) do
                if type(k) == "string" and string.find(k, "Pal") then
                    print("  - " .. k .. " = " .. type(v))
                end
            end
        end
        
        -- Simple delay
        local start = os.clock()
        while os.clock() - start < 1 do end
        
        attempts = attempts + 1
    end
    
    print("[PalsShop] ERROR: PalCentralCoreInstance not found after " .. max_attempts .. " seconds.")
    return nil
end

-- Dependencies
local core = WaitForPalCentralCore()
if not core then
    print("[PalsShop] CRITICAL ERROR: Cannot function without PalCentralCore. Mod disabled.")
    return {}
end

local breedingSystem = require("breeding") -- Must match filename exactly: breeding.lua

-- Initialize market system
local PalMarketSystem = {}
PalMarketSystem.__index = PalMarketSystem

-- ================================================
-- MARKET CONFIGURATION
-- ================================================
local MARKET_CONFIG = {
    MARKET_TAX_RATE = 0.05,             -- 5% sales tax
    AUCTION_DURATION = 86400,           -- 24 hours
    MIN_AUCTION_INCREMENT = 100,        -- Minimum bid step
    MAX_LISTINGS_PER_PLAYER = 10,
    DIRECT_SALE_EXPIRY = 604800,        -- 7 days
    TRADE_TIMEOUT = 300,                -- 5 minutes
    MINIMUM_SALE_PRICE = 50,
    AUCTION_START_PERCENTAGE = 0.7,     -- Starts at 70% of value
    FEATURED_LISTINGS_COUNT = 5,
    SEARCH_RESULTS_LIMIT = 50,

    -- Listing filters
    CATEGORIES = {
        "all", "perfect", "rare_passives", "high_level", "breeding_ready",
        "new_generation", "specific_species", "competitive"
    }
}

-- ================================================
-- ESTRUTURAS DE DADOS DO MERCADO
-- ================================================
local LISTING_STRUCTURE = {
    id = "",
    type = "", -- "direct_sale", "auction", "trade_offer"
    pal_id = "",
    seller_id = "",
    price = 0, -- Para vendas diretas
    starting_bid = 0, -- Para leilões
    current_bid = 0,
    current_bidder = "",
    buyout_price = 0, -- Preço para compra imediata em leilões
    created_at = 0,
    expires_at = 0,
    status = "", -- "active", "sold", "expired", "cancelled"
    description = "",
    category = "all",
    featured = false,
    view_count = 0,
    bid_history = {}, -- Array de bids para leilões
    trade_offers = {} -- Array de ofertas de troca
}

local BID_STRUCTURE = {
    bidder_id = "",
    amount = 0,
    timestamp = 0,
    auto_bid = false -- Sistema de auto-bid
}

local TRADE_OFFER_STRUCTURE = {
    id = "",
    offeror_id = "",
    offered_pals = {}, -- Array de IDs de Pals oferecidos
    gold_amount = 0,
    message = "",
    created_at = 0,
    expires_at = 0,
    status = "pending" -- "pending", "accepted", "rejected", "expired"
}

-- ================================================
-- SISTEMA DE LOG DO MERCADO
-- ================================================
function PalMarketSystem:LogMarket(message, level)
    level = level or "INFO"
    local core = {}
    setmetatable(core, PalCentralCore)
    core:Log("[MARKET] " .. message, level)
end

-- ================================================
-- VALIDAÇÃO DE LISTAGEM
-- ================================================
function PalMarketSystem:ValidateListing(pal_id, seller_id, listing_type, data)
    local core = {}
    setmetatable(core, PalCentralCore)
    
    -- Verificar se o Pal existe
    local pal, error_msg = core:GetPal(pal_id, data)
    if not pal then
        return false, "Pal não encontrado: " .. (error_msg or "erro desconhecido")
    end
    
    -- Verificar propriedade
    if pal.owner_id ~= seller_id then
        return false, "Você não é o proprietário deste Pal"
    end
    
    -- Verificar se o Pal está disponível
    if pal.market_status ~= "available" then
        return false, "Pal não está disponível para venda (Status: " .. pal.market_status .. ")"
    end
    
    -- Verificar limite de listagens do jogador
    local player_listings = self:GetPlayerListings(seller_id, data)
    if #player_listings >= MARKET_CONFIG.MAX_LISTINGS_PER_PLAYER then
        return false, "Limite de listagens atingido (" .. MARKET_CONFIG.MAX_LISTINGS_PER_PLAYER .. ")"
    end
    
    -- Validações específicas por tipo
    if listing_type == "auction" then
        -- Leilões requerem Pals de maior valor
        if pal.breeding_value < 500 then
            return false, "Pals em leilão devem ter valor mínimo de 500"
        end
    end
    
    return true, "Listagem válida"
end

-- ================================================
-- CÁLCULO DE PREÇO SUGERIDO
-- ================================================
function PalMarketSystem:CalculateSuggestedPrice(pal)
    if not pal then return 0 end
    
    local base_price = pal.breeding_value
    
    -- Bonus por level
    local level_multiplier = 1 + (pal.level - 1) * 0.05 -- 5% por level acima de 1
    
    -- Bonus por passivas raras
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
    
    -- Bonus por perfeição
    local perfect_multiplier = pal.is_perfect and 2.0 or 1.0
    
    -- Penalty por geração alta
    local generation_penalty = math.max(0, (pal.generation - 2) * 0.1)
    
    -- Cálculo final
    local final_price = math.floor((base_price + passive_bonus) * level_multiplier * perfect_multiplier * (1 - generation_penalty))
    
    return math.max(MARKET_CONFIG.MINIMUM_SALE_PRICE, final_price)
end

-- ================================================
-- VERIFICAÇÃO DE RARIDADE DE PASSIVAS
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
-- CRIAÇÃO DE VENDA DIRETA
-- ================================================
function PalMarketSystem:CreateDirectSale(pal_id, seller_id, price, description, category, data)
    category = category or "all"
    description = description or ""
    
    -- Validar listagem
    local is_valid, validation_error = self:ValidateListing(pal_id, seller_id, "direct_sale", data)
    if not is_valid then
        return nil, validation_error
    end
    
    -- Validar preço
    if price < MARKET_CONFIG.MINIMUM_SALE_PRICE then
        return nil, "Preço mínimo é " .. MARKET_CONFIG.MINIMUM_SALE_PRICE .. " gold"
    end
    
    local core = {}
    setmetatable(core, PalCentralCore)
    
    -- Criar listagem
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
    
    -- Adicionar à base de dados
    if not data.market then
        data.market = {direct_sales = {}, auctions = {}, trade_history = {}}
    end
    
    data.market.direct_sales[listing.id] = listing
    
    -- Atualizar status do Pal
    core:UpdatePal(pal_id, {market_status = "for_sale"}, data)
    
    self:LogMarket("Venda direta criada: " .. listing.id .. " por " .. price .. " gold")
    return listing, nil
end

-- ================================================
-- CRIAÇÃO DE LEILÃO
-- ================================================
function PalMarketSystem:CreateAuction(pal_id, seller_id, starting_bid, buyout_price, description, category, data)
    category = category or "all"
    description = description or ""
    buyout_price = buyout_price or 0
    
    -- Validar listagem
    local is_valid, validation_error = self:ValidateListing(pal_id, seller_id, "auction", data)
    if not is_valid then
        return nil, validation_error
    end
    
    -- Calcular preço inicial sugerido se não fornecido
    if starting_bid <= 0 then
        local core = {}
        setmetatable(core, PalCentralCore)
        local pal = core:GetPal(pal_id, data)
        starting_bid = math.floor(self:CalculateSuggestedPrice(pal) * MARKET_CONFIG.AUCTION_START_PERCENTAGE)
    end
    
    if starting_bid < MARKET_CONFIG.MINIMUM_SALE_PRICE then
        return nil, "Lance inicial mínimo é " .. MARKET_CONFIG.MINIMUM_SALE_PRICE .. " gold"
    end
    
    if buyout_price > 0 and buyout_price <= starting_bid then
        return nil, "Preço de compra imediata deve ser maior que o lance inicial"
    end
    
    local core = {}
    setmetatable(core, PalCentralCore)
    
    -- Criar leilão
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
    
    -- Adicionar à base de dados
    if not data.market then
        data.market = {direct_sales = {}, auctions = {}, trade_history = {}}
    end
    
    data.market.auctions[auction.id] = auction
    
    -- Atualizar status do Pal
    core:UpdatePal(pal_id, {market_status = "in_auction"}, data)
    
    self:LogMarket("Leilão criado: " .. auction.id .. " com lance inicial de " .. starting_bid .. " gold")
    return auction, nil
end

-- ================================================
-- SISTEMA DE LANCES
-- ================================================
function PalMarketSystem:PlaceBid(auction_id, bidder_id, bid_amount, data)
    if not data.market or not data.market.auctions[auction_id] then
        return false, "Leilão não encontrado"
    end
    
    local auction = data.market.auctions[auction_id]
    
    -- Verificar se o leilão está ativo
    if auction.status ~= "active" then
        return false, "Leilão não está mais ativo"
    end
    
    -- Verificar se não expirou
    if os.time() > auction.expires_at then
        auction.status = "expired"
        return false, "Leilão expirado"
    end
    
    -- Verificar se não é o próprio vendedor
    if bidder_id == auction.seller_id then
        return false, "Vendedor não pode dar lances em seu próprio leilão"
    end
    
    -- Verificar incremento mínimo
    local minimum_bid = auction.current_bid + MARKET_CONFIG.MIN_AUCTION_INCREMENT
    if bid_amount < minimum_bid then
        return false, "Lance mínimo é " .. minimum_bid .. " gold"
    end
    
    -- Registrar lance
    local bid = {
        bidder_id = bidder_id,
        amount = bid_amount,
        timestamp = os.time(),
        auto_bid = false
    }
    
    table.insert(auction.bid_history, bid)
    auction.current_bid = bid_amount
    auction.current_bidder = bidder_id
    
    -- Verificar compra imediata
    if auction.buyout_price > 0 and bid_amount >= auction.buyout_price then
        return self:ExecuteBuyout(auction_id, bidder_id, data)
    end
    
    self:LogMarket("Lance de " .. bid_amount .. " gold colocado no leilão " .. auction_id)
    return true, "Lance registrado com sucesso"
end

-- ================================================
-- COMPRA IMEDIATA
-- ================================================
function PalMarketSystem:ExecuteBuyout(auction_id, buyer_id, data)
    local auction = data.market.auctions[auction_id]
    
    return self:CompleteSale(auction.pal_id, auction.seller_id, buyer_id, auction.buyout_price, "buyout", data)
end

-- ================================================
-- COMPRA DIRETA
-- ================================================
function PalMarketSystem:PurchaseDirectSale(sale_id, buyer_id, data)
    if not data.market or not data.market.direct_sales[sale_id] then
        return false, "Venda não encontrada"
    end
    
    local sale = data.market.direct_sales[sale_id]
    
    if sale.status ~= "active" then
        return false, "Venda não está mais ativa"
    end
    
    if os.time() > sale.expires_at then
        sale.status = "expired"
        return false, "Venda expirada"
    end
    
    if buyer_id == sale.seller_id then
        return false, "Não é possível comprar seu próprio Pal"
    end
    
    return self:CompleteSale(sale.pal_id, sale.seller_id, buyer_id, sale.price, "direct_sale", data)
end

-- ================================================
-- FINALIZAÇÃO DE VENDA
-- ================================================
function PalMarketSystem:CompleteSale(pal_id, seller_id, buyer_id, sale_price, sale_type, data)
    local core = {}
    setmetatable(core, PalCentralCore)
    
    -- Verificar se o Pal ainda existe
    local pal, error_msg = core:GetPal(pal_id, data)
    if not pal then
        return false, "Pal não encontrado: " .. (error_msg or "erro desconhecido")
    end
    
    -- Calcular taxa do mercado
    local market_tax = math.floor(sale_price * MARKET_CONFIG.MARKET_TAX_RATE)
    local seller_receives = sale_price - market_tax
    
    -- Transferir propriedade do Pal
    core:UpdatePal(pal_id, {
        owner_id = buyer_id,
        market_status = "available"
    }, data)
    
    -- Registrar transação no histórico
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
    
    -- Remover das listagens ativas
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
    
    self:LogMarket("Venda completada: " .. pal.name .. " por " .. sale_price .. " gold (" .. sale_type .. ")")
    
    return true, {
        transaction = transaction,
        pal_transferred = pal,
        seller_receives = seller_receives,
        market_tax = market_tax
    }
end

-- ================================================
-- BUSCA NO MERCADO
-- ================================================
function PalMarketSystem:SearchMarket(filters, data)
    if not data.market then
        return {}
    end
    
    local results = {}
    local core = {}
    setmetatable(core, PalCentralCore)
    
    -- Buscar em vendas diretas
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
    
    -- Buscar em leilões
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
    
    -- Ordenar resultados
    table.sort(results, function(a, b)
        if filters.sort_by == "price_low" then
            return a.current_price < b.current_price
        elseif filters.sort_by == "price_high" then
            return a.current_price > b.current_price
        elseif filters.sort_by == "level" then
            return a.pal.level > b.pal.level
        elseif filters.sort_by == "breeding_value" then
            return a.pal.breeding_value > b.pal.breeding_value
        else -- Default: mais recente
            return a.listing.created_at > b.listing.created_at
        end
    end)
    
    -- Limitar resultados
    local limited_results = {}
    for i = 1, math.min(#results, MARKET_CONFIG.SEARCH_RESULTS_LIMIT) do
        table.insert(limited_results, results[i])
    end
    
    return limited_results
end

-- ================================================
-- VERIFICAÇÃO DE FILTROS
-- ================================================
function PalMarketSystem:MatchesFilters(pal, listing, filters)
    if not filters then return true end
    
    -- Filtro por espécie
    if filters.species and pal.species ~= filters.species then
        return false
    end
    
    -- Filtro por preço máximo
    if filters.max_price then
        local price = listing.type == "direct_sale" and listing.price or listing.current_bid
        if price > filters.max_price then
            return false
        end
    end
    
    -- Filtro por preço mínimo
    if filters.min_price then
        local price = listing.type == "direct_sale" and listing.price or listing.current_bid
        if price < filters.min_price then
            return false
        end
    end
    
    -- Filtro por level mínimo
    if filters.min_level and pal.level < filters.min_level then
        return false
    end
    
    -- Filtro por passivas mínimas
    if filters.min_passives and #pal.passives < filters.min_passives then
        return false
    end
    
    -- Filtro por perfeitos
    if filters.perfect_only and not pal.is_perfect then
        return false
    end
    
    -- Filtro por categoria
    if filters.category and filters.category ~= "all" and listing.category ~= filters.category then
        return false
    end
    
    return true
end

-- ================================================
-- OBTER LISTAGENS DO JOGADOR
-- ================================================
function PalMarketSystem:GetPlayerListings(player_id, data)
    if not data.market then return {} end
    
    local listings = {}
    
    -- Vendas diretas
    for _, sale in pairs(data.market.direct_sales or {}) do
        if sale.seller_id == player_id and sale.status == "active" then
            table.insert(listings, sale)
        end
    end
    
    -- Leilões
    for _, auction in pairs(data.market.auctions or {}) do
        if auction.seller_id == player_id and auction.status == "active" then
            table.insert(listings, auction)
        end
    end
    
    return listings
end

-- ================================================
-- CANCELAR LISTAGEM
-- ================================================
function PalMarketSystem:CancelListing(listing_id, player_id, data)
    if not data.market then
        return false, "Mercado não inicializado"
    end
    
    local core = {}
    setmetatable(core, PalCentralCore)
    
    -- Procurar em vendas diretas
    if data.market.direct_sales[listing_id] then
        local sale = data.market.direct_sales[listing_id]
        if sale.seller_id ~= player_id then
            return false, "Você não é o vendedor desta listagem"
        end
        
        sale.status = "cancelled"
        core:UpdatePal(sale.pal_id, {market_status = "available"}, data)
        
        self:LogMarket("Venda direta cancelada: " .. listing_id)
        return true, "Venda cancelada com sucesso"
    end
    
    -- Procurar em leilões
    if data.market.auctions[listing_id] then
        local auction = data.market.auctions[listing_id]
        if auction.seller_id ~= player_id then
            return false, "Você não é o vendedor deste leilão"
        end
        
        if #auction.bid_history > 0 then
            return false, "Não é possível cancelar leilão com lances"
        end
        
        auction.status = "cancelled"
        core:UpdatePal(auction.pal_id, {market_status = "available"}, data)
        
        self:LogMarket("Leilão cancelado: " .. listing_id)
        return true, "Leilão cancelado com sucesso"
    end
    
    return false, "Listagem não encontrada"
end

-- ================================================
-- LIMPEZA AUTOMÁTICA DE LISTAGENS EXPIRADAS
-- ================================================
function PalMarketSystem:CleanupExpiredListings(data)
    if not data.market then return 0 end
    
    local cleaned_count = 0
    local current_time = os.time()
    local core = {}
    setmetatable(core, PalCentralCore)
    
    -- Limpar vendas diretas expiradas
    for _, sale in pairs(data.market.direct_sales or {}) do
        if sale.status == "active" and current_time > sale.expires_at then
            sale.status = "expired"
            core:UpdatePal(sale.pal_id, {market_status = "available"}, data)
            cleaned_count = cleaned_count + 1
        end
    end
    
    -- Limpar leilões expirados e finalizar com lance vencedor
    for _, auction in pairs(data.market.auctions or {}) do
        if auction.status == "active" and current_time > auction.expires_at then
            if auction.current_bidder and auction.current_bidder ~= "" then
                -- Finalizar venda com lance vencedor
                self:CompleteSale(auction.pal_id, auction.seller_id, auction.current_bidder, auction.current_bid, "auction", data)
            else
                auction.status = "expired"
                core:UpdatePal(auction.pal_id, {market_status = "available"}, data)
            end
            cleaned_count = cleaned_count + 1
        end
    end
    
    if cleaned_count > 0 then
        self:LogMarket("Limpeza automática: " .. cleaned_count .. " listagens expiradas processadas")
    end
    
    return cleaned_count
end

-- ================================================
-- ESTATÍSTICAS DO MERCADO
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
    
    -- Contar listagens ativas
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
    
    -- Analisar histórico de vendas
    local today_start = os.time() - (os.time() % 86400) -- Início do dia atual
    local total_sales_value = 0
    
    for _, transaction in ipairs(data.market.trade_history or {}) do
        stats.total_sales_all_time = stats.total_sales_all_time + 1
        total_sales_value = total_sales_value + transaction.sale_price
        
        if transaction.timestamp >= today_start then
            stats.total_sales_today = stats.total_sales_today + 1
        end
        
        -- Contar popularidade das espécies (seria necessário buscar o Pal)
        -- stats.species_popularity[pal.species] = (stats.species_popularity[pal.species] or 0) + 1
    end
    
    if stats.total_sales_all_time > 0 then
        stats.average_sale_price = math.floor(total_sales_value / stats.total_sales_all_time)
        stats.total_market_volume = total_sales_value
    end
    
    return stats
end

-- ================================================
-- EXPORTAR MÓDULO
-- ================================================
return PalMarketSystem