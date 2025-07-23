-- battle_manager.lua - Gerencia eventos de batalha e integração com o sistema ranqueado
local BattleManager = {}

-- Dependências injetadas na inicialização
local PalCentralCore
local RankedSystem

function BattleManager.Initialize(core, ranked)
    PalCentralCore = core
    RankedSystem = ranked
    if PalCentralCore then
        PalCentralCore:Log("[Battle Manager] Sistema inicializado.", "INFO")
    else
        print("[Battle Manager][ERRO] PalCentralCore não disponível na inicialização do BattleManager.")
    end
end

function BattleManager.OnBattleStart(context)
    if PalCentralCore then
        PalCentralCore:Log("[Battle Manager] Evento OnBattleStart acionado. Contexto: " .. tostring(context), "DEBUG")
        -- Aqui você precisaria extrair informações do 'context'
        -- como IDs dos jogadores, Pals envolvidos, tipo de batalha (PvP vs PvE)
        -- Por enquanto, apenas logamos.
    end
end

function BattleManager.OnBattleEnd(result)
    if PalCentralCore then
        PalCentralCore:Log("[Battle Manager] Evento OnBattleEnd acionado. Resultado: " .. tostring(result), "DEBUG")
        -- Aqui você precisaria extrair winner_id, loser_id e category do 'result'
        -- Exemplo hipotético:
        -- local winner_id = result.WinnerPlayerID -- PALPITE
        -- local loser_id = result.LoserPlayerID   -- PALPITE
        -- local category = "OU" -- Categoria padrão para teste

        -- if winner_id and loser_id and RankedSystem then
        --     RankedSystem.ProcessBattleResult(winner_id, loser_id, category)
        --     PalCentralCore:Log(string.format("[Battle Manager] Batalha processada: Vencedor %s, Perdedor %s", winner_id, loser_id), "INFO")
        -- else
        --     PalCentralCore:Log("[Battle Manager] Dados de batalha insuficientes ou RankedSystem não disponível para processar.", "WARN")
        -- end
    end
end

return BattleManager