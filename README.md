# CC Rotation Helper

A World of Warcraft addon converted from a WeakAuras string that helps coordinate crowd control abilities in Mythic+ dungeons.

## Features

- **Automatic CC Rotation Tracking**: Monitors group members' crowd control cooldowns
- **Smart NPC Detection**: Only shows relevant CC abilities based on nearby enemies
- **Priority System**: Prioritizes certain players in the rotation order
- **Visual Display**: Shows upcoming CC abilities with cooldown timers
- **Configurable Interface**: Customizable display options and positioning

## Installation

1. Extract the addon folder to your `Interface/AddOns/` directory
2. Restart World of Warcraft or reload your UI (`/reload`)
3. The addon will be automatically enabled when you join a group

## Dependencies

- **LibStub**: Standard library framework (included)
- **LibOpenRaid-1.0**: Required for tracking group cooldowns (placeholder included)

*Note: For full functionality, you'll need to replace the placeholder LibOpenRaid with the actual library.*

## Commands

- `/ccr` or `/ccrotation` - Show available commands
- `/ccr config` - Open configuration window
- `/ccr toggle` - Enable/disable the addon
- `/ccr reset` - Reset position to default

## Configuration

The addon can be configured through the in-game interface:

1. Use `/ccr config` to open the configuration window
2. Adjust display options, icon size, and priority players
3. Move the display by holding Shift and dragging

## Supported Dungeons

The addon includes crowd control effectiveness data for:

- **The Rookery** (ROOK)
- **Operation: Mechagon - Workshop** (WORK)  
- **Theater of Pain** (TOP)
- **The Motherlode** (ML)
- **Fungal Folly** (FL)
- **Darkflame Cleft** (DFC)
- **Cinderbrew Meadery** (CBM)
- **Priory of the Sacred Flame** (PRIO)

## Tracked Abilities

The addon monitors these crowd control abilities:

### Stuns
- Demon Hunter: Chaos Nova
- Monk: Leg Sweep  
- Shaman: Capacitor Totem
- Warrior: Shockwave
- Warlock: Shadowfury

### Disorients  
- Death Knight: Blinding Sleet
- Mage: Dragon's Breath
- Paladin: Blinding Light
- Rogue: Blind

### Fears
- Demon Hunter: Sigil of Misery
- Priest: Psychic Scream
- Warrior: Intimidating Shout

### Knockbacks
- Druid: Typhoon
- Evoker: Tail Swipe, Wing Buffet
- Hunter: Explosive Shot, Bursting Shot
- Mage: Blast Wave, Supernova, Gravity Lapse
- Monk: Ring of Peace
- Shaman: Thunderstorm
- Demon Hunter: Sigil of Chains

### Incapacitates
- Druid: Incapacitating Roar

## Priority Players

You can designate certain players as priority in the rotation:

1. Open config with `/ccr config`
2. Add player names in the Priority Players section
3. These players will be prioritized when their abilities are ready

## Technical Notes

This addon was converted from a WeakAuras configuration and maintains the same core functionality:

- Uses LibOpenRaid to track group cooldowns
- Scans nameplates to detect active enemies
- Filters abilities based on enemy crowd control immunities
- Sorts rotation based on readiness, priority, and player status

## Troubleshooting

**Addon not showing:**
- Make sure you're in a group (unless "Show when not in group" is enabled)
- Check that the addon is enabled with `/ccr toggle`
- Verify LibOpenRaid is properly installed for full functionality

**Missing abilities:**
- The addon only shows abilities that are effective against nearby enemies
- Make sure the player has the ability available and trained

**Position issues:**
- Use `/ccr reset` to restore default position
- Hold Shift and drag to reposition manually

## Credits

Converted from original WeakAuras configuration. Special thanks to the LibOpenRaid authors for the cooldown tracking framework.