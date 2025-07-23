🌍 Palworld LATAM MMO: New Competitive and Economic Era

Welcome to the Ultimate Palworld Server in Latin America!

This project aims to transform the Palworld multiplayer experience, introducing innovative and complex systems for Pal management, player-to-player (P2P) economy, and a robust competitive scene, all designed to be the reference in Latin America. Inspired by mechanics from established MMO games like Pokémon, League of Legends, and Fortnite, our server offers strategic depth and unprecedented engagement.



🌟 Main Features

Our customized server implements a series of modules that integrate to create a rich MMO experience:

🧠 Central Data and Functions Mod (PalCentralCore)

The backbone of our ecosystem. This module centrally manages all customized server data, including detailed information about Pals (passives, customized individual stats), player profiles, market data, and ranking records. It ensures data persistence (saved in JSON) and provides essential functions for all other systems.

🧬 Advanced Breeding System (BreedingCore)

Revolutionizing Pal creation.



Guaranteed Passive Inheritance: Offspring inherit all the best passives from their parents, allowing the creation of genetically "perfect" Pals with ideal skill combinations.

Parent Consumption: To increase the rarity and market value of Pals with good passives, parents are consumed in the breeding process, making each breeding decision strategic and unique.

Generation Control and Cooldowns: Cooldown rules and attempt limits per Pal to balance the economy.



🛍️ Dynamic Pal Market (PalsShop)

A complete economic ecosystem for players.



Direct Sale: Trade Pals quickly at a fixed price.

Auction System: Auction rare or high-value Pals, with bids, instant buy price, and set duration, maximizing profit.

Trading System (Future): Ability to trade Pals and specific items through customized offers.

Secure Transactions: All transactions are automatically managed by the server, ensuring the transfer of Pals directly to the buyer's Pal Box and currency to the seller, with market fees for economic control.

Smart Search and Filters: Intuitive interface to find Pals by species, level, passives, price, and more.



🏆 Competitive Ranked Coliseum (PalColiseum)

Take your combat skills to the next level.



Battle Categories (Pokémon Style): Compete in different Pal "tiers" (Ubers, OU, UU, NU, LC), with species restrictions to promote strategic diversity, all with a level 50 cap.

Ranking System (League of Legends Style): Progress through visual ranks (Iron, Bronze, Silver, Gold, Platinum, Emerald, Diamond, Master, Grand Master, and the exclusive Paulzudo).

Paulzudo: The Server King: Only one player can hold the prestigious Paulzudo rank at a time, creating a constant and thrilling race to the top, with global server notification.

Dynamic Scoring Logic: Point gains and losses are adjusted based on rank differences and win/loss streaks to ensure a fair and motivating system.



🏅 Seasonal Battle Pass

Reward your time and dedication.



Progression via Ranked Victories: Unlock up to 50 reward levels by accumulating wins in ranked battles during the season.

Epic Final Reward: An exclusive and highly valuable prize awaits those who achieve 100 victories in the season.





🛠️ Technical Overview

This project is built on the Palworld Dedicated Server and uses UE4SS (Unreal Engine 4/5 Scripting System) to inject our custom logic.



Server-Side First Approach: The vast majority of logic (data management, calculations, economy, ranking) is executed on the server side. This ensures consistency, security, and minimizes the need for heavy client-side mods.

Lua Scripting: All modules are developed in Lua, leveraging the flexibility and performance of UE4SS.

Data Persistence: A robust JSON file saving system ensures that all custom data (bred Pals, market items, player ranks) persists between server restarts.

Minimal Client-Side UI (Future): For a user-friendly experience (e.g., market interface), a small UI download will be required on the client side. However, the complexity of the logic remains on the server.





🚀 Getting Started (Server Installation)

Prerequisites



A Palworld Dedicated Server configured and running.

UE4SS (Unreal Engine 4/5 Scripting System) installed in the Pal\\Binaries\\Win64 folder of your Palworld client.

Basic knowledge of navigating server files and Lua.



Mod Installation



Download UE4SS: Obtain the latest version compatible with Palworld (Unreal Engine 5) from GitHub do UE4SS or trusted community sources.



Install UE4SS on the Client: Extract the contents of the UE4SS .zip file directly into Palworld\\Pal\\Binaries\\Win64.



Obtain json.lua: Download the json.lua file (e.g., JSON.lua by rxi).



Organize the Mods Folder:



Navigate to Palworld\\Pal\\Binaries\\Win64\\Mods.

Create a folder named shared inside Mods (if it doesn’t exist). Place the downloaded json.lua in Mods\\shared.

Create the following module folders for your project:

PalCentralCore\\scripts\\

BreedingCore\\scripts\\

PalsShop\\scripts\\

PalColiseum\\scripts\\





Place the corresponding .lua files in their respective scripts folders. (E.g., main.lua for the Central Mod goes in PalCentralCore\\scripts\\main.lua).

Rename the files main(breeding).lua to main.lua (in BreedingCore\\scripts), main(loja).lua to main.lua (in PalsShop\\scripts), and main(coliseum).lua to main.lua (in PalColiseum\\scripts).









Configure mods.txt:



Open the mods.txt file (in Palworld\\Pal\\Binaries\\Win64\\Mods).



Ensure the exact load order (CRITICAL for dependencies!):

ConsoleCommandsMod = 1

ConsoleEnablerMod = 1

BPModLoaderMod = 1

BPML\_GenericFunctions = 1

Keybinds = 1



PalCentralCore = 1    ; The Core MUST be the first of your custom mods

BreedingCore = 1       ; Breeding depends on the Core

PalsShop = 1           ; Shop depends on the Core and Breeding

PalColiseum = 1        ; Coliseum depends on the Core and other modules



; Disable other default UE4SS mods if you’re not using them,

; to avoid conflicts or unnecessary logs.

ActorDumperMod = 0

SplitScreenMod = 0

LineTraceMod = 0

jsbLuaProfilerMod = 0









Verify UE4SS-settings.ini:



Open Palworld\\Pal\\Binaries\\Win64\\UE4SS-settings.ini.

In the \[Lua] section:

EnableLua = 1

LoadScripts = 1 (This is important for main.lua files in subfolders to be found automatically)

LuaConsole = 1





In the \[Debug] section:

ConsoleEnabled = 1

GuiConsoleEnabled = 1

GuiConsoleVisible = 1 (To view the UE4SS debug console)









Remove enabled.txt: Ensure there is NO enabled.txt file inside your custom module folders (PalCentralCore, BreedingCore, PalsShop, PalColiseum). They can override the mods.txt order.





Dedicated Server Configuration



The same folders (Mods, UE4SS-settings.ini, mods.txt, shared, etc.) must be replicated in your Palworld Dedicated Server installation on your host. This ensures the mod logic runs on the server.





🎮 How to Use (In-Game Interaction)



Server Logs/UE4SS Console: Monitor your mod’s messages in the UE4SS debug console (the black window) to see initialization and logic behavior.

Console Commands (Future): To test functionalities, you’ll be able to use custom commands in the game console (~ or F10), for example, to create test Pals, inspect data, or trigger battle events.

User Interfaces (Future): Visual interfaces (Market, Ranking) will be accessed through NPCs or in-game structures, to be developed in the UI Manager phase.





🗺️ Roadmap and Future Plans

We are currently in Phase 1: Foundation and Tools, focusing on ensuring all modules load and communicate correctly.

Next Steps:



Full Module Validation: Confirm that all your modules (PalCentralCore, BreedingCore, PalsShop, PalColiseum, RankedSystem, BattleManager, UIManager) load without errors in the console.

Development of BattleManager: Intercept in-game battle events to process results in the ranking system.

Development of UIManager: Create visual interfaces for the Market, Ranking, and Battle Pass.

In-Game Integration: Connect mod logic with actual game functionality (fetching player Pals, spawning Pals, transferring items/currency).





🤝 Contributions

Contributions are welcome! If you’re a Lua developer or have experience with Unreal Engine modding, please get in touch.



🙏 Acknowledgments

Special thanks to the Palworld modding community and the UE4SS developers for providing the tools that make this project possible.

