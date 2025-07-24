# 🏆 PalBattlePass - Seasonal Battle Pass System

**Version:** 1.0.0  
**Status:** ⚠️ EXPERIMENTAL - Core functionality works, some features may need server-specific adjustments  
**Compatible:** UE4SS 3.0.0+, Palworld Dedicated Servers  
**Dependencies:** PalCentralCore (required for data storage)

A **server-side** Battle Pass system for Palworld that tracks player progress and manages rewards through chat commands. 

## ⚠️ Important Notes

**What Actually Works:**
- ✅ Chat command system with multiple formats
- ✅ Tier progression and data tracking
- ✅ Player statistics and leaderboards  
- ✅ Reward claiming system (stored in data)
- ✅ Basic battle validation

**Current Limitations:**
- 🔧 **Battle Detection**: Automatic PvP detection uses experimental UE4SS hooks that may not work on all servers
- 🔧 **Item Rewards**: Rewards are tracked in data but may not appear in player inventories (server-dependent)
- 🔧 **Player ID System**: Player identification may be inconsistent across server restarts
- 🔧 **Manual Setup**: Admins may need to manually register wins during development

## 🌟 Core Features

### 📈 **Tier System** 
- **50 progressive tiers** with increasing win requirements (2 → 700 wins)
- **Epic reward** at 100 wins for ultimate achievement
- Smart progression curve designed for long-term engagement

### 🎁 **Reward Types**
- **Pal Souls** (Small/Medium/Large) for stat enhancement
- **Gold/Currency** for in-game purchases
- **Ancient Civilisation Parts** for crafting systems
- **Legendary Pals** with enhanced stats and passives
- **Player Titles** for bragging rights
- **Seasonal Exclusive Items** that expire with the season

### 💬 **Multiple Command Formats**
Works around server security by supporting:
- Standard: `/bp`, `/battlepass`
- Alternative: `!bp`, `.bp` 
- Plain text: `bp`, `battlepass`
- Help: `bphelp`

### 📊 **Player Tracking**
- Win streaks and personal records
- Season leaderboards with rankings
- Battle history and statistics
- Progress notifications

## 🚀 Installation

### Prerequisites
1. **Palworld Dedicated Server** with UE4SS 3.0.0+
2. **PalCentralCore** (REQUIRED - handles all data storage)
3. **Server restart** after installation

### Step 1: File Placement
```
📁 Pal/Binaries/Win64/Mods/
└── 📁 PalBattlePass/
    ├── 📄 config.json
    ├── 📄 README.md
    └── 📁 Scripts/
        ├── 📄 main.lua (entry point)
        ├── 📄 commands.lua
        ├── 📄 rewards.lua
        └── 📄 integration.lua
```

### Step 2: Server Configuration
Edit `config.json` for your season:
```json
{
  "current_season": {
    "id": "Season_Winter_2025",
    "name": "❄️ Winter Conquest", 
    "duration_days": 90,
    "max_tiers": 50,
    "epic_reward_wins": 100
  }
}
```

### Step 3: Verification
After server start, check console for:
```
[PalBattlePass] 🏆 Battle Pass System loaded successfully!
[PalBattlePass] Global instance created and available!
```

**Test Commands:**
- Console: `TestBattlePass()` - System health check
- In-game: `bp` or `/bp` - Player status

## 🎮 Player Commands

| Command | Function | Example |
|---------|----------|---------|
| `bp` or `/bp` | Show battle pass status | Main command |
| `bp claim` | Claim available rewards | Collect tier rewards |
| `bp rewards` | View upcoming rewards | See next 5 tiers |
| `bp leaderboard` | Season rankings | Top 10 players |
| `bphelp` | Command help & formats | Troubleshooting |

### Example Output
```
🏆 ═══════ BATTLE PASS STATUS ═══════
🎯 Season: ❄️ Winter Conquest
⚔️  Ranked Wins: 15 victories
🏅 Current Tier: 5/50
🔥 Win Streak: 3 (Best: 8)
📈 Next tier in 3 wins (18 total needed)
🎁 UNCLAIMED REWARDS: 2 available!
💰 Use 'bp claim' to collect them!
```

## 🔧 Manual Win Registration

Since automatic battle detection is experimental, admins can manually register wins:

### Console Commands
```lua
-- Give a player battle pass wins
BattlePassCommand("player123", "admin", "give", "5")

-- Check player status  
BattlePassCommand("player123", "bp")

-- Register single win
_G.PalBattlePassInstance:RegisterRankedWin("player123", true)
```

### For Other Mods
```lua
-- Integration with custom PvP systems
if _G.PalBattlePassInstance then
    _G.PalBattlePassInstance:RegisterRankedWin(winnerPlayerID, true)
end
```

## 🛠️ Server Administration

### Data Management
All data stored in **PalCentralCore**:
- Player progress: `PalCentralCore.data.players[playerID].battle_pass`
- Season stats: `PalCentralCore.data.battle_pass.season_stats`
- Reward history: `PalCentralCore.data.reward_history`

### Troubleshooting

**Battle Pass not responding:**
```
1. Check: _G.PalBattlePassInstance exists
2. Verify: PalCentralCore loaded first
3. Test: TestBattlePass() in console
```

**Players can't use commands:**
```
1. Try different formats: bp, /bp, !bp, .bp
2. Check server chat permissions
3. Use bphelp for format options
```

**Rewards not working:**
```
1. Check: PalCentralCore.data.players[playerID].inventory
2. Rewards stored in data, may need custom item-giving
3. Enable debug_mode in config.json for detailed logs
```

## ⚙️ Configuration Options

### Season Management
```json
{
  "current_season": {
    "id": "unique_season_id",
    "name": "Season Display Name",
    "max_tiers": 50,
    "epic_reward_wins": 100
  },
  "anti_cheat": {
    "min_battle_duration": 30,
    "min_time_between_battles": 60,
    "enable_validation": true
  },
  "debug_mode": true
}
```

## 🔄 Integration Examples

### Custom PvP System
```lua
-- After a PvP match ends
local function OnPvPMatchEnd(winnerID, loserID, matchData)
    if _G.PalBattlePassInstance then
        -- Register the win
        local success = _G.PalBattlePassInstance:RegisterRankedWin(winnerID, true)
        if success then
            print("Battle Pass win registered for " .. winnerID)
        end
    end
end
```

### Tournament Integration
```lua
-- After tournament victory
local function OnTournamentWin(playerID, tournamentType)
    if _G.PalBattlePassInstance then
        -- Give bonus wins for tournament victory
        for i = 1, 3 do
            _G.PalBattlePassInstance:RegisterRankedWin(playerID, true)
        end
    end
end
```

## 📋 Development Status

### ✅ Working Features
- Chat command system with multiple formats
- Tier progression calculations  
- Data persistence via PalCentralCore
- Player statistics and leaderboards
- Reward tracking and claiming
- Season management

### 🔧 Experimental Features
- Automatic battle detection (UE4SS hooks)
- Direct inventory item giving
- Real-time chat notifications
- PalDefender security integration

### 🚧 Future Development
- **Improved Battle Detection**: More reliable PvP detection methods
- **Enhanced Rewards**: Better integration with Palworld inventory systems
- **Guild Integration**: Team-based battle pass progression
- **Web Dashboard**: External progress tracking and management

## 🐛 Known Issues

1. **Player ID Inconsistency**: Player IDs may change between server restarts
2. **Item Delivery**: Physical items may not appear in inventory (data tracking works)
3. **Battle Detection**: Automatic detection depends on fragile UE4SS hooks
4. **Chat Limitations**: Some servers may block certain command formats

## 📞 Support & Development

**For Server Admins:**
- Enable `debug_mode: true` for detailed logging
- Use console commands for testing and manual wins
- Check PalCentralCore data for player progress

**For Developers:**
- Use `_G.PalBattlePassInstance` API for integration
- Battle pass data available in PalCentralCore.data structure
- Extend reward system through rewards.lua modifications

## 📝 License

Provided as-is for Palworld dedicated servers. Distribute freely with attribution.

---

**🎮 Happy Gaming!**  
*Build your legend, one victory at a time.* 