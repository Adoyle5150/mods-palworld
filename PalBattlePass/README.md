# 🏆 PalBattlePass - Seasonal Battle Pass System

**Version:** 1.0.0  
**Compatible:** UE4SS 3.0.0+, Palworld Dedicated Servers  
**Dependencies:** PalCentralCore (recommended)

A comprehensive **server-side** Battle Pass system for Palworld that rewards players for winning ranked battles with NO UI required! Everything works through intuitive chat commands.

## 🌟 Key Features

### 📈 **Progressive Tier System**
- **50 tiers** with increasing win requirements  
- **Epic reward** at 100 wins (exclusive seasonal prize)
- Smart progression curve that keeps players engaged

### 🎁 **Rich Reward System**
- **Pal Souls** (Small/Medium/Large) for enhancing Pals
- **Gold/Currency** for purchasing items
- **Ancient Civilisation Parts** for crafting
- **Legendary Pals** with perfect passives
- **Player Titles** to show off achievements
- **Seasonal Exclusive Items** that can never be obtained again
- **Ultimate Rewards** for the most dedicated players

### 💬 **Chat-Driven Interface**
- No custom UI needed - everything works through chat!
- Intuitive commands: `/bp`, `/battlepass`, `/bp rewards`, etc.
- Rich, formatted responses with emojis and progress bars
- Real-time notifications for tier unlocks and achievements

### 🛡️ **Anti-Cheat Integration**
- Battle duration validation
- Rate limiting to prevent farming
- Integration with PalDefender security system
- Suspicious activity logging and reporting

### 📊 **Comprehensive Statistics**
- Win streaks and best streak tracking
- Season leaderboards with rankings
- Daily battle activity monitoring
- Server-wide statistics and analytics

## 🚀 Installation

### Prerequisites
1. **Palworld Dedicated Server** with UE4SS 3.0.0+
2. **PalCentralCore** (recommended for data management)
3. **PalColiseum** (for automatic ranked battle detection)

### Step 1: Extract Files
```
📁 Pal/
└── 📁 Binaries/Win64/Mods/
    └── 📁 PalBattlePass/
        ├── 📄 mod.lua (main entry point)
        ├── 📄 config.json
        ├── 📄 README.md
        └── 📁 Scripts/
            ├── 📄 main.lua
            ├── 📄 commands.lua
            ├── 📄 rewards.lua
            └── 📄 integration.lua
```

### Step 2: Configure Season
Edit `config.json` to customize your season:
```json
{
  "current_season": {
    "id": "Season_Winter_2025",
    "name": "❄️ Winter Conquest", 
    "duration_days": 90,
    "max_tiers": 50,
    "epic_reward_wins": 100,
    "description": "Prove your dominance in the frozen battlegrounds!"
  }
}
```

### Step 3: Start Server
The Battle Pass will automatically load when the server starts. Look for:
```
[PalBattlePass] 🏆 Battle Pass System loaded successfully!
[PalBattlePass] 💬 Players can use '/bp' or '/battlepass' to get started!
```

## 🎮 Player Commands

### Basic Commands
| Command | Description |
|---------|------------|
| `/bp` or `/battlepass` | Show your Battle Pass status |
| `/bp status` | Detailed progress information |
| `/bp rewards` | View available rewards |
| `/bp claim <tier>` | Claim reward from specific tier |
| `/bp leaderboard` | Season rankings |
| `/bp info` | Season information |
| `/bp help` | Command help |

### Example Usage
```
Player: /bp
🏆 BATTLE PASS STATUS - ❄️ Winter Conquest
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎖️  Current Tier: 15 / 50
⚔️  Ranked Wins: 79
📈  Progress to Tier 16: 72%
🌟  Epic Reward Progress: 79% (79/100 wins)
🎁  Unclaimed Rewards: 3 tiers
🔥  Current Win Streak: 5
📊  Best Win Streak: 12
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Commands: /bp rewards | /bp claim <tier> | /bp help
```

## 🔧 Configuration

### Season Management
Easily manage seasons through `config.json`:
- **Season names** and descriptions
- **Tier requirements** and progression
- **Reward templates** for different items
- **Anti-cheat settings**
- **Notification preferences**

### Reward Customization
Create custom rewards using templates:
```json
"legendary_shadowbeak": {
  "type": "legendary_pal",
  "species": "Shadowbeak",
  "passives": ["Swift"],
  "name": "🦅 Legendary Shadowbeak"
}
```

### Anti-Cheat Settings
Configure battle validation:
```json
"anti_cheat": {
  "min_battle_duration": 15,
  "min_time_between_battles": 30,
  "max_daily_wins": 50,
  "enable_validation": true
}
```

## 🛠️ Integration

### With PalColiseum
Automatically detects ranked battle wins and updates progress:
```lua
-- Automatic integration - no setup required!
-- Players earn progress by winning ranked battles
```

### With PalCentralCore
Stores all data in your central database:
```lua
-- Access player data
local status = PalBattlePassInstance:GetPlayerStatus("player123")
```

### Manual Win Registration
For custom battle systems:
```lua
-- Register a win manually
PalBattlePassInstance:RegisterRankedWin("player123", true)
```

## 📊 Season Management

### Starting New Season
1. Update `config.json` with new season details
2. Restart server
3. Previous season data is preserved for analytics

### Mid-Season Updates
- Modify reward values without affecting claimed rewards
- Adjust anti-cheat settings in real-time
- Add new milestone notifications

## 🎯 Reward Types

| Type | Description | Example |
|------|-------------|---------|
| **pal_souls** | Small/Medium/Large Pal Souls | Enhancement materials |
| **gold** | In-game currency | 5,000 - 25,000 gold |
| **ancient_parts** | Crafting materials | 2-10 Ancient Parts |
| **legendary_pal** | Rare Pals with passives | Shadowbeak with Swift |
| **title** | Player titles | "Battle Veteran" |
| **seasonal_exclusive** | Limited-time items | Winter Crown |
| **ultimate_reward** | Unique seasonal Pal | Never obtainable again |

## 🔒 Security Features

### Battle Validation
- **Duration checks**: Prevents ultra-quick fake battles
- **Rate limiting**: Stops battle farming
- **Pattern detection**: Identifies suspicious behavior

### Data Integrity
- **Atomic operations**: Prevents data corruption
- **Backup system**: Regular data snapshots
- **Rollback capability**: Recover from issues

## 🌍 Server Administration

### Monitoring Commands
```lua
-- Check player progress
/admin bp player <playerID>

-- View season statistics
/admin bp stats

-- Force tier unlock (admin only)
/admin bp unlock <playerID> <tier>
```

### Analytics Dashboard
Access comprehensive statistics:
- **Daily active users**
- **Battle completion rates**
- **Reward claim patterns**
- **Anti-cheat incident reports**

## 🐛 Troubleshooting

### Common Issues

**Battle Pass not loading:**
```
Solution: Check UE4SS version (3.0.0+ required)
Verify PalCentralCore is loaded first
```

**Commands not working:**
```
Solution: Ensure chat hook is registered
Check server logs for hook registration errors
```

**Rewards not given:**
```
Solution: Verify reward system integration
Check player inventory permissions
```

### Debug Mode
Enable detailed logging in `config.json`:
```json
{
  "debug_mode": true
}
```

## 🚀 Future Features

- **Guild Battle Pass**: Shared progression for guilds
- **Weekly Challenges**: Additional ways to earn progress  
- **Cosmetic Rewards**: Visual customization items
- **Cross-Season Rewards**: Special items for veteran players
- **API Expansion**: More integration options for developers

## 📞 Support

- **Issues**: Report bugs with detailed server logs
- **Feature Requests**: Describe desired functionality
- **Integration Help**: Provide your mod setup details

## 📝 License

This mod is provided as-is for Palworld dedicated servers. Distribute freely but maintain attribution.

---

**Happy Gaming! 🎮**  
*May your battles be epic and your rewards legendary!* 