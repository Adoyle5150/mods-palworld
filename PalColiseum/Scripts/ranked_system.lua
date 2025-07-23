-- ranked_system.lua - Sistema de classificação para o Coliseu Ranqueado

local RankedSystem = {}

-- ================================================
-- ENUMS E CONSTANTES DE RANKING
-- ================================================
RankedSystem.Ranks = {
    FERRO = {id = 0, name = "Ferro", points_min = 0, points_max = 100},
    BRONZE = {id = 1, name = "Bronze", points_min = 101, points_max = 200},
    PRATA = {id = 2, name = "Prata", points_min = 201, points_max = 300},
    OURO = {id = 3, name = "Ouro", points_min = 301, points_max = 400},
    PLATINA = {id = 4, name = "Platina", points_min = 401, points_max = 500},
    ESMERALDA = {id = 5, name = "Esmeralda", points_min = 501, points_max = 600},
    DIAMANTE = {id = 6, name = "Diamante", points_min = 601, points_max = 700},
    MESTRE = {id = 7, name = "Mestre", points_min = 701, points_max = 800},
    GRAO_MESTRE = {id = 8, name = "Grão Mestre", points_min = 801, points_max = 900},
    PAULZUDO = {id = 9, name = "Paulzudo", points_min = 901, points_max = 9999} -- Pontos_max é um limite teórico, o rank é único
}

RankedSystem.Categories = {"Ubers", "OU", "UU", "NU", "LC"}

-- ================================================
-- DADOS DO JOGADOR (Armazenamento em memória local do RankedSystem)
-- ================================================
local players_data = {}
local current_paulzudo = nil -- ID do jogador que é Paulzudo no momento

-- Referência à instância do PalCentralCore
local PalCentralCoreRef = nil

-- ================================================
-- INICIALIZAÇÃO DO SISTEMA DE RANKING
-- ================================================
function RankedSystem.Initialize(palCentralCore)
    PalCentralCoreRef = palCentralCore -- Armazena a referência ao core
    if not PalCentralCoreRef then
        print("[Ranked System][ERRO FATAL] PalCentralCore não disponível na inicialização do RankedSystem.")
        return
    end

    PalCentralCoreRef:Log("[Ranked System] Sistema inicializado.", "INFO")
    RankedSystem.LoadPlayerData()
    
    -- Definir um timer para salvar dados periodicamente (para persistência mais frequente)
    -- O PalCentralCore deve ter a CONFIG.BACKUP_INTERVAL
    -- Adicionada verificação para PalCentralCoreRef.CONFIG
    if PalCentralCoreRef.CONFIG and PalCentralCoreRef.CONFIG.BACKUP_INTERVAL then
        Timer.SetInterval(function()
            RankedSystem.SavePlayerData()
        end, PalCentralCoreRef.CONFIG.BACKUP_INTERVAL * 1000) -- Salva a cada X segundos (convertendo para milissegundos)
        PalCentralCoreRef:Log(string.format("[Ranked System] Agendado salvamento automático a cada %d segundos.", PalCentralCoreRef.CONFIG.BACKUP_INTERVAL), "DEBUG")
    else
        PalCentralCoreRef:Log("[Ranked System] Intervalo de backup não definido no PalCentralCore. Salvamento automático desabilitado.", "WARN")
    end
end

-- ================================================
-- REGISTRO E ATUALIZAÇÃO DE JOGADORES
-- ================================================
function RankedSystem.RegisterPlayer(player_character, palCentralCore)
    local core = palCentralCore or PalCentralCoreRef
    if not core then
        print("[Ranked System][ERRO] Core indisponível para registrar jogador.")
        return
    end

    -- Obter o Player ID e Nome de forma segura
    local player_id_obj = player_character:GetPlayerID()
    local player_id = tostring(player_id_obj)
    local player_name = player_character:GetPlayerName()

    if not players_data[player_id] then
        players_data[player_id] = {
            id = player_id,
            name = player_name,
            points = 0,
            rank = RankedSystem.Ranks.FERRO, -- Começa no Ferro
            wins = 0,
            losses = 0,
            win_streak = 0,
            season_wins = 0, -- Para o Battle Pass
            category_points = { -- Pontos separados por categoria
                Ubers = 0, OU = 0, UU = 0, NU = 0, LC = 0
            },
            battle_pass_rewards = {} -- Recompensas do Battle Pass já obtidas
        }
        core:Log(string.format("[Ranked System] Jogador '%s' (ID: %s) registrado.", player_name, player_id), "INFO")
        RankedSystem.SavePlayerData() -- Salva após registrar novo jogador
    else
        -- Atualizar nome do jogador se tiver mudado (ou outros dados que não sejam de rank)
        if players_data[player_id].name ~= player_name then
            players_data[player_id].name = player_name
            core:Log(string.format("[Ranked System] Nome do jogador '%s' (ID: %s) atualizado para '%s'.", players_data[player_id].name, player_id, player_name), "INFO")
            RankedSystem.SavePlayerData()
        end
    end
end

-- ================================================
-- PROCESSAMENTO DE RESULTADOS DE BATALHA
-- ================================================
function RankedSystem.ProcessBattleResult(winner_id, loser_id, category)
    local core = PalCentralCoreRef
    if not core then
        print("[Ranked System][ERRO] Core indisponível para processar batalha.")
        return
    end

    local winner = players_data[winner_id]
    local loser = players_data[loser_id]
    
    if not winner or not loser then
        core:Log(string.format("[Ranked System] Erro: Vencedor (%s) ou Perdedor (%s) não encontrado para processar batalha.", winner_id, loser_id), "WARN")
        return
    end
    
    -- Calcular pontos
    local points_gained = RankedSystem.CalculatePointsGained(winner, loser)
    local points_lost = RankedSystem.CalculatePointsLost(winner, loser)
    
    -- Atualizar vencedor
    winner.points = winner.points + points_gained
    winner.wins = winner.wins + 1
    winner.win_streak = winner.win_streak + 1
    winner.season_wins = winner.season_wins + 1
    winner.category_points[category] = (winner.category_points[category] or 0) + points_gained
    
    -- Atualizar perdedor
    loser.points = math.max(0, loser.points - points_lost)
    loser.losses = loser.losses + 1
    loser.win_streak = 0 -- Reseta a sequência de vitórias
    loser.category_points[category] = math.max(0, (loser.category_points[category] or 0) - points_lost)
    
    -- Verificar mudanças de rank
    RankedSystem.UpdatePlayerRank(winner)
    RankedSystem.UpdatePlayerRank(loser)
    
    RankedSystem.SavePlayerData()
    
    core:Log(string.format("[Ranked System] Batalha processada: %s (+%d) vs %s (-%d) na categoria %s", 
        winner.name, points_gained, loser.name, points_lost, category), "INFO")
end

-- ================================================
-- CÁLCULO DE PONTOS
-- ================================================
function RankedSystem.CalculatePointsGained(winner, loser)
    local base_points = 25
    local rank_diff = loser.rank.id - winner.rank.id
    
    -- Bônus por enfrentar oponente mais forte
    if rank_diff > 0 then
        base_points = base_points + (rank_diff * 5)
    end
    
    -- Bônus por win streak
    if winner.win_streak >= 3 then
        base_points = base_points + 5
    end
    
    return math.max(20, math.min(30, base_points)) -- Pontos ganhos entre 20 e 30
end

function RankedSystem.CalculatePointsLost(winner, loser)
    local base_points = 15
    local rank_diff = winner.rank.id - loser.rank.id
    
    -- Penalidade por perder para oponente mais fraco
    if rank_diff > 0 then
        base_points = base_points + (rank_diff * 5)
    end
    
    return math.max(10, math.min(20, base_points)) -- Pontos perdidos entre 10 e 20
end

-- ================================================
-- ATUALIZAÇÃO DE RANK
-- ================================================
function RankedSystem.UpdatePlayerRank(player)
    local core = PalCentralCoreRef
    if not core then return end -- Log já foi feito na ProcessBattleResult
    
    local old_rank = player.rank
    local new_rank = RankedSystem.GetRankByPoints(player.points)
    
    if new_rank.id ~= old_rank.id then
        player.rank = new_rank
        
        -- Verificar promoção para Paulzudo
        if new_rank.id == RankedSystem.Ranks.PAULZUDO.id and old_rank.id ~= RankedSystem.Ranks.PAULZUDO.id then
            RankedSystem.HandlePaulzudoPromotion(player)
        end
        
        core:Log(string.format("[Ranked System] %s (%s) promovido para %s!", player.name, player.id, new_rank.name), "INFO")
        -- Se for a primeira vez que um jogador atingiu esse rank, talvez dar uma recompensa aqui
    end
end

function RankedSystem.GetRankByPoints(points)
    for _, rank in pairs(RankedSystem.Ranks) do
        if points >= rank.points_min and points <= rank.points_max then
            return rank
        end
    end
    return RankedSystem.Ranks.FERRO -- Retorna Ferro se os pontos forem abaixo do mínimo
end

-- ================================================
-- LÓGICA DO PAULZUDO (RANK ÚNICO)
-- ================================================
function RankedSystem.HandlePaulzudoPromotion(new_paulzudo)
    local core = PalCentralCoreRef
    if not core then return end

    -- Rebaixar Paulzudo anterior, se houver e não for o mesmo
    if current_paulzudo and current_paulzudo ~= new_paulzudo.id then
        local old_paulzudo = players_data[current_paulzudo]
        if old_paulzudo then
            -- Rebaixa para Grão Mestre
            old_paulzudo.rank = RankedSystem.Ranks.GRAO_MESTRE
            old_paulzudo.points = RankedSystem.Ranks.GRAO_MESTRE.points_max -- Garante que os pontos se encaixem no rank
            core:Log(string.format("[Ranked System] Paulzudo anterior %s rebaixado para Grão Mestre.", old_paulzudo.name), "INFO")
        end
    end
    
    current_paulzudo = new_paulzudo.id
    
    -- Broadcast para servidor
    RankedSystem.BroadcastPaulzudoNotification(new_paulzudo.name)
    RankedSystem.SavePlayerData() -- Salva para persistir o novo Paulzudo
end

function RankedSystem.BroadcastPaulzudoNotification(player_name)
    local core = PalCentralCoreRef
    if not core then return end

    local message = string.format("🏆 %s conquistou o ranque PAULZUDO e é o MESTRE SUPREMO do Coliseu de Palworld! 🏆", player_name)
    
    core:Log("[BROADCAST] " .. message, "INFO")
    
    -- Tentar enviar mensagem no chat do jogo
    -- Esta é uma funcionalidade que depende da API do UE4SS para o chat.
    -- O PalCentralCore precisaria expor uma função para isso, ou você precisaria
    -- encontrar um PlayerController válido para executar o comando 'say'.
    -- Por enquanto, estamos apenas logando, mas o ideal é a mensagem no chat global.
    -- Exemplo: core:SendGlobalChatMessage(message) (se o core tiver essa função)
    local anyPlayerController = GetWorld():GetFirstPlayerController() -- Tenta pegar qualquer player controller
    if anyPlayerController and anyPlayerController.ExecuteConsoleCommand then
        anyPlayerController:ExecuteConsoleCommand("say " .. message)
    else
        core:Log("[BROADCAST ERROR] Não foi possível enviar mensagem para o chat do jogo (PlayerController/API indisponível).", "WARN")
    end
end

-- ================================================
-- PERSISTÊNCIA DE DADOS
-- ================================================
function RankedSystem.SavePlayerData()
    local core = PalCentralCoreRef
    if not core then 
        print("[Ranked System][ERRO] Core indisponível para salvar dados do rank.")
        return
    end

    -- Atualiza a seção de players na base de dados global do core
    -- Garante que 'data.players_data' exista na estrutura global do core
    if not core.data.players_data then
        core.data.players_data = {}
    end
    core.data.players_data = players_data -- Salva a tabela de players
    core.data.current_paulzudo = current_paulzudo -- Salva quem é o Paulzudo

    core:SaveData(core.data) -- Salva a base de dados completa do core no arquivo JSON
    core:Log("[Ranked System] Dados de rank salvos no PalCentralCore.", "INFO")
end

function RankedSystem.LoadPlayerData()
    local core = PalCentralCoreRef
    if not core then 
        print("[Ranked System][ERRO] Core indisponível para carregar dados do rank.")
        return
    end

    -- Carrega os dados de players da base de dados global do core
    -- Se core.data.players_data existir, usa-o, senão inicializa uma tabela vazia
    players_data = core.data.players_data or {}
    current_paulzudo = core.data.current_paulzudo or nil
    
    core:Log("[Ranked System] Dados de rank carregados do PalCentralCore.", "INFO")

    -- Se o Paulzudo existe e não está no rank certo (por exemplo, após um crash ou rebaixamento manual)
    if current_paulzudo and players_data[current_paulzudo] and players_data[current_paulzudo].rank.id ~= RankedSystem.Ranks.PAULZUDO.id then
        local old_paulzudo_player = players_data[current_paulzudo]
        -- Isso corrige o rank do Paulzudo se ele foi rebaixado indevidamente por um bug/restart
        old_paulzudo_player.rank = RankedSystem.Ranks.PAULZUDO 
        old_paulzudo_player.points = RankedSystem.Ranks.PAULZUDO.points_min -- Ajusta pontos
        core:Log(string.format("[Ranked System] Paulzudo (%s) revalidado após carregamento.", old_paulzudo_player.name), "WARN")
    end
end

-- ================================================
-- FUNÇÕES DE CONSULTA
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
    
    -- Ordenar por pontos (decrescente), depois por vitórias (decrescente)
    table.sort(sorted_players, function(a, b)
        if a.points == b.points then
            return a.wins > b.wins
        end
        return a.points > b.points
    end)
    
    local result = {}
    -- Correção: estava inserindo o resultado em vez do player.
    -- Agora insere os jogadores ordenados no array 'result'.
    for i = 1, math.min(limit, #sorted_players) do
        table.insert(result, sorted_players[i]) 
    end
    
    return result
end

-- ================================================
-- EXPORTAR MÓDULO
-- ================================================
return RankedSystem