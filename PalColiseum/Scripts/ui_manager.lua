-- ui_manager.lua - Gerencia a interface do usuário para os sistemas do mod
local UIManager = {}

-- Dependências injetadas na inicialização
local PalCentralCore
local RankedSystem

function UIManager.Initialize(core, ranked)
    PalCentralCore = core
    RankedSystem = ranked
    if PalCentralCore then
        PalCentralCore:Log("[UI Manager] Sistema inicializado. Interface em desenvolvimento.", "INFO")
    else
        print("[UI Manager][ERRO] PalCentralCore não disponível na inicialização do UIManager.")
    end
end

-- Futuras funções para abrir interfaces, atualizar elementos, etc.
-- Exemplo:
-- function UIManager.OpenMarketUI()
--     if PalCentralCore then
--         PalCentralCore:Log("[UI Manager] Abrindo interface do mercado...", "INFO")
--         -- Lógica para criar e exibir a UI
--     end
-- end

return UIManager