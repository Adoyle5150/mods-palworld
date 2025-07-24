# 🌍 Palworld LATAM MMO: Nova Era Competitiva e Econômica

## Bem-vindo ao Servidor Definitivo de Palworld na América Latina!

Este projeto visa transformar a experiência multiplayer de Palworld, introduzindo sistemas inovadores e complexos de gerenciamento de Pals, economia de jogador para jogador (P2P) e uma cena competitiva robusta, tudo projetado para ser a referência na América Latina. Inspirado em mecânicas de jogos MMO consagradas como Pokémon, League of Legends e Fortnite, nosso servidor oferece uma profundidade estratégica e um engajamento sem precedentes.

---

## 🌟 Funcionalidades Principais

Nosso servidor customizado implementa uma série de módulos que se integram para criar uma experiência MMO rica:

### 🧠 **Mod Central de Dados e Funções (`PalCentralCore`)**
A espinha dorsal do nosso ecossistema. Este módulo gerencia de forma centralizada todos os dados customizados do servidor, incluindo informações detalhadas de Pals (passivas, stats individuais customizados), perfis de jogadores, dados de mercado e registros de ranqueamento. Ele garante a **persistência de dados** (salvos em JSON) e oferece funções essenciais para todos os outros sistemas.

### 🧬 **Sistema Avançado de Breeding (`BreedingCore`)**
Revolucionando a criação de Pals.
* **Herança Garantida de Passivas**: Filhotes herdam **todas as melhores passivas** de seus pais, permitindo a criação de Pals geneticamente "perfeitos" com combinações de habilidades ideais.
* **Consumo dos Pais**: Para aumentar a raridade e o valor de mercado de Pals com boas passivas, os pais são **consumidos no processo de breeding**, tornando cada decisão de criação estratégica e única.
* **Controle de Geração e Cooldowns**: Regras de cooldown e limite de tentativas por Pal para balancear a economia.

### 🛍️ **Mercado Dinâmico de Pals (`PalsShop`)**
Um ecossistema econômico completo para jogadores.
* **Venda Direta**: Negocie Pals rapidamente a um **preço fixo**.
* **Sistema de Leilão**: Leiloe Pals raros ou de alto valor, com lances, preço de compra imediata e duração definida, maximizando o lucro.
* **Sistema de Troca (Futuro)**: Capacidade de negociar Pals e itens específicos através de ofertas personalizadas.
* **Transfêrencia Segura**: Todas as transações são gerenciadas automaticamente pelo servidor, garantindo a transferência de Pals diretamente para a Pal Box do comprador e a moeda para o vendedor, com taxas de mercado para controle econômico.
* **Busca e Filtros Inteligentes**: Interface intuitiva para encontrar Pals por espécie, nível, passivas, preço e muito mais.

### 🏆 **Coliseu Ranqueado Competitivo (`PalColiseum`)**
Leve suas habilidades de combate ao próximo nível.
* **Categorias de Batalha (Estilo Pokémon)**: Compita em diferentes "tiers" de Pals (Ubers, OU, UU, NU, LC), com regras e restrições de espécies para promover a diversidade estratégica, todos com **limite de nível 50**.
* **Sistema de Ranqueamento (Estilo League of Legends)**: Progrida por ranques visuais (Ferro, Bronze, Prata, Ouro, Platina, Esmeralda, Diamante, Mestre, Grão Mestre, e o exclusivo **Paulzudo**).
* **Paulzudo: O Rei do Servidor**: Apenas **um jogador** pode deter o prestigioso ranque Paulzudo por vez, criando uma corrida constante e emocionante pelo topo, com notificação global no servidor.
* **Lógica de Pontuação Dinâmica**: Ganhos e perdas de pontos são ajustados pela diferença de ranque e sequências de vitórias/derrotas para garantir um sistema justo e motivador.

### 🏅 **Passe de Batalha Sazonal (`PalBattlePass`)**
Recompense seu tempo e dedicação.
* **Progressão por Vitórias Ranqueadas**: Desbloqueie até **50 níveis de recompensas** ao acumular vitórias nas batalhas ranqueadas da temporada.
* **Recompensa Final Épica**: Um prêmio exclusivo e altamente valioso aguarda aqueles que atingirem 100 vitórias na temporada.
* **Sistema Independente**: Funciona de forma autônoma, requerendo apenas o PalCentralCore como dependência.

---

## 🛠️ Visão Técnica

Este projeto é construído sobre a base do Palworld Dedicated Server e utiliza o **UE4SS (Unreal Engine 4/5 Scripting System)** para injetar nossa lógica customizada.

* **Abordagem Server-Side First**: A vasta maioria da lógica (gerenciamento de dados, cálculos, economia, ranking) é executada no **lado do servidor**. Isso garante consistência, segurança e minimiza a necessidade de mods pesados para os jogadores.
* **Lua Scripting**: Todos os módulos são desenvolvidos em Lua, aproveitando a flexibilidade e o desempenho do UE4SS.
* **Dependências Minimalistas**: Nosso sistema foi projetado para ser **altamente portável** - cada módulo requer apenas o **PalCentralCore** como dependência principal, tornando a instalação mais simples e confiável.
* **Persistência de Dados**: Um sistema robusto de salvamento em arquivo JSON garante que todos os dados customizados (Pals breedados, itens no mercado, ranks dos jogadores) persistam entre os restarts do servidor.
* **UI Minimalista Client-Side (Futuro)**: Para uma experiência de usuário amigável (como a interface do mercado), será necessário um **pequeno download de UI** no lado do cliente. No entanto, a complexidade da lógica permanece no servidor.

### 📋 **Dependências por Módulo**

| Módulo | Dependências Obrigatórias | Dependências Opcionais |
|--------|---------------------------|------------------------|
| `PalCentralCore` | UE4SS v3.0.0+ | - |
| `BreedingCore` | PalCentralCore | - |
| `PalsShop` | PalCentralCore | - |
| `PalColiseum` | PalCentralCore | - |
| `PalBattlePass` | PalCentralCore | PalDefender (para whitelist automática) |

**❌ Mods NÃO Necessários:**
* **PalSchema** - Usado apenas para validação avançada de dados de Pals (opcional para outros projetos)
* **PalDefender** - Sistema de segurança independente (recomendado, mas não obrigatório)

---

## 🚀 Como Começar (Instalação no Servidor)

### Pré-requisitos
* Um **Servidor Dedicado de Palworld** configurado e funcionando.
* **UE4SS (Unreal Engine 4/5 Scripting System) v3.0.0+** instalado na pasta `Pal\Binaries\Win64` do seu **servidor de Palworld**.
* Conhecimento básico de como navegar em arquivos de servidor e Lua.

### Instalação dos Mods

1.  **Baixe o UE4SS:** Obtenha a versão mais recente e compatível com Palworld (Unreal Engine 5) do [GitHub do UE4SS](https://github.com/UE4SS-RE/UE4SS/releases) ou de fontes confiáveis da comunidade.
2.  **Instale o UE4SS no Servidor:** Extraia o conteúdo do arquivo `.zip` do UE4SS diretamente para `Palworld\Pal\Binaries\Win64`.
3.  **Obtenha o `json.lua`:** Baixe o arquivo `json.lua` (ex: [JSON.lua by rxi](https://github.com/rxi/json.lua/blob/master/json.lua)).
4.  **Organize a Pasta `Mods`:**
    * Navegue até `Palworld\Pal\Binaries\Win64\Mods`.
    * Crie uma pasta chamada `shared` dentro de `Mods` (se não existir). Coloque o `json.lua` baixado dentro de `Mods\shared`.
    * Crie as seguintes pastas de módulos para o seu projeto:
        * `PalCentralCore\Scripts\`
        * `BreedingCore\Scripts\`
        * `PalsShop\Scripts\`
        * `PalColiseum\Scripts\`
        * `PalBattlePass\Scripts\`
    * Coloque os arquivos `.lua` correspondentes em suas respectivas pastas `Scripts`. (Ex: `main.lua` do Mod Central vai em `PalCentralCore\Scripts\main.lua`).
        * **Renomeie** os arquivos `main(breeding).lua` para `main.lua` (em `BreedingCore\Scripts`), `main(loja).lua` para `main.lua` (em `PalsShop\Scripts`), e `main(coliseum).lua` para `main.lua` (em `PalColiseum\Scripts`).

5.  **Configure o `mods.txt`:**
    * Abra o arquivo `mods.txt` (em `Palworld\Pal\Binaries\Win64\Mods`).
    * **Garanta a ordem de carregamento exata (CRÍTICO para dependências!):**

        ```
        ConsoleCommandsMod = 1
        ConsoleEnablerMod = 1
        
        ; === CORE OBRIGATÓRIO ===
        PalCentralCore = 1    ; O Core DEVE ser o primeiro dos seus mods customizados
        
        ; === MÓDULOS OPCIONAIS (ordem flexível) ===
        BreedingCore = 1       ; Sistema de breeding avançado
        PalsShop = 1           ; Mercado de Pals
        PalColiseum = 1        ; Sistema ranqueado competitivo  
        PalBattlePass = 1      ; Passe de batalha sazonal
        
        ; === MODS DE INFRAESTRUTURA (opcionais) ===
        BPModLoaderMod = 1
        BPML_GenericFunctions = 1
        PalSchema = 0          ; NÃO NECESSÁRIO - apenas para validação avançada
        PalDefender = 0        ; OPCIONAL - recomendado para segurança

        ; === MODS PADRÃO UE4SS (desabilitados para performance) ===
        ActorDumperMod = 0
        SplitScreenMod = 0
        LineTraceMod = 0
        jsbLuaProfilerMod = 0
        Keybinds = 0
        ```
6.  **Verifique `UE4SS-settings.ini`:**
    * Abra `Palworld\Pal\Binaries\Win64\UE4SS-settings.ini`.
    * Na seção `[Lua]`:
        * `EnableLua = 1`
        * `LoadScripts = 1` (Isso é importante para que os `main.lua` das subpastas sejam encontrados automaticamente)
        * `LuaConsole = 1`
    * Na seção `[Debug]`:
        * `ConsoleEnabled = 1`
        * `GuiConsoleEnabled = 1`
        * `GuiConsoleVisible = 1` (Para ver o console de depuração do UE4SS)
7.  **Remova `enabled.txt`:** Certifique-se de que **NÃO EXISTE** nenhum arquivo `enabled.txt` dentro das suas pastas de módulos personalizadas (`PalCentralCore`, `BreedingCore`, `PalsShop`, `PalColiseum`, `PalBattlePass`). Eles podem anular a ordem do `mods.txt`.

### Configuração no Servidor Dedicado
* As mesmas pastas (`Mods`, `UE4SS-settings.ini`, `mods.txt`, `shared`, etc.) devem ser replicadas na instalação do seu **Palworld Dedicated Server** na sua host. Isso garante que a lógica do mod execute no servidor.

---

## 🎮 Como Usar (Interação no Jogo)

### **Comandos do Passe de Batalha:**
* **`bp`** - Mostra status atual do jogador
* **`bp rewards`** - Lista recompensas disponíveis  
* **`bp claim`** - Reivindica recompensas desbloqueadas
* **`bp leaderboard`** - Ranking dos melhores jogadores
* **`bphelp`** - Lista todos os comandos disponíveis

**💡 Formatos Suportados:** `/bp`, `!bp`, `.bp` ou simplesmente `bp` (compatível com PalDefender)

### **Monitoramento:**
* **Logs do Servidor/UE4SS Console**: Monitore as mensagens do seu mod no console de depuração do UE4SS (a janela preta) para ver a inicialização e o comportamento da lógica.
* **Comandos de Console**: Para testar as funcionalidades, use `BattlePassCommand(playerID, 'bp')` no console do UE4SS.
* **Interfaces de Usuário (Futuro)**: As interfaces visuais (Mercado, Ranqueamento) serão acessadas através de NPCs ou estruturas no jogo, que serão desenvolvidas na fase de UI Manager.

---

## 🗺️ Roadmap e Planos Futuros

Estamos atualmente na **Fase 1: Fundação e Ferramentas**, com foco em garantir que todos os módulos sejam carregados e se comuniquem corretamente.

**✅ Concluído:**
1. **PalCentralCore** - Sistema de dados centralizado funcionando
2. **PalBattlePass** - Sistema de progressão sazonal completo e testado
3. **Arquitetura Modular** - Dependências minimalistas e alta portabilidade

**🚧 Próximos Passos:**
1. **Validação Completa dos Módulos**: Confirmar que todos os seus módulos (`BreedingCore`, `PalsShop`, `PalColiseum`) são carregados sem erros no console.
2. **Desenvolvimento do `BattleManager`**: Interceptar eventos de batalha do jogo para processar resultados no sistema de ranqueamento.
3. **Desenvolvimento do `UIManager`**: Criar as interfaces visuais para o Mercado, Ranqueamento e Passe de Batalha.
4. **Integração In-Game**: Conectar a lógica dos mods com a funcionalidade real do jogo (obter Pals do jogador, spawnar Pals, transferir itens/moeda).

---

## 🤝 Contribuições

Contribuições são bem-vindas! Se você é um desenvolvedor Lua ou tem experiência com modding de Unreal Engine, por favor, entre em contato.

---

## 🙏 Agradecimentos

Agradecimentos especiais à comunidade de modding de Palworld e aos desenvolvedores do UE4SS por fornecerem as ferramentas que tornam este projeto possível.