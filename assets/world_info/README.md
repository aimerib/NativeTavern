# Built-in World Info Configuration

This directory contains NativeTavern's built-in World Info (Lorebook) configuration files.

## Available World Info

### 1. Spirit Realm Cultivation Chronicle (mortal_cultivation.json) 🇨🇳
**Original Chinese-language world setting**
**Content:** World setting for the original cultivation world *Spirit Realm Cultivation Chronicle*
- Cultivation realm system (from Spirit Gathering stage to True Spirit)
- Sect factions (Azure Cloud Sect, Alliance of Five Sects)
- Magic treasure and spirit pill system
- Cultivation techniques and resources
- Setting for the protagonist, Lin Chen

**Use Cases:**
- Cultivation-themed roleplay
- Eastern fantasy story creation
- Exploring the cultivation world setting

**Entry Count:** 7 core settings

---

### 2. Guardian Universe (marvel_universe.json) 🇬🇧
**English Original Content**
**Content:** Guardian Universe original world setting
- The Guardians team
- Cosmic Fragments and Universal Gauntlet
- GDI organization
- Quantum Realm and Dimensional Planes
- Nova City and Crystallium
- Void Lord and major events
- Multiverse and quantum magic

**Use Cases:**
- Superhero-themed roleplay
- Original superhero story creation
- Enhanced individual universe exploration

**Entry Count:** 8 core settings

---

### 3. Eldia Legend (zelda_legend.json) 🇯🇵
**Original Japanese-language content**
**Content:** World setting for the original fantasy work *Eldia Legend*
- Sacred Emblems (Power, Wisdom, Courage)
- The Kingdom of Eldia and its races
- The Eternal Blade and sacred weapons
- Ancient magic and crystal orbs
- The battle against the Dark Lord
- The Guardian Alto and Princess Serena

**Use Cases:**
- Fantasy-themed roleplay
- Original adventure story creation
- Exploring the world of Eldia

**Entry Count:** 8 core settings

---

## Original Content Notice

**Important Notice:**

All world info files in this directory are **entirely original creations** and do not involve any copyright issues.

While these worldbuildings are inspired by classic works, all settings, names, and background stories have been reimagined to create unique original content:

- **Spirit Realm Cultivation Chronicle** - Original cultivation world, not *A Record of a Mortal's Journey to Immortality*
- **Guardian Universe** - Original superhero universe, not the Marvel Universe
- **Eldia Legend** - Original fantasy world, not The Legend of Zelda

---

## Usage

### Auto-loading
These built-in world infos will be automatically loaded into the database when you first launch the app.

### Features
- ✅ Ready to use
- ✅ Smart deduplication
- ✅ Editable
- ✅ Loaded once
- ✅ Supports both global and character-specific binding

---

## How World Info Works

### Keyword Triggering
When specific keywords appear in conversation, related entries are automatically inserted into prompts:

- **Primary keywords (keys)**: The main terms that trigger an entry
- **Secondary keywords (secondaryKeys)**: Optional terms for secondary confirmation
- **Selective triggering (selective)**: Requires both primary and secondary keywords to appear together

### Insertion Position
- `beforeCharDefs`: Before the character definition
- `afterCharDefs`: After the character definition
- `atDepth`: At a specific depth position

### Priority Control
- `insertionOrder`: Insertion order (smaller numbers are inserted earlier)
- `constant`: Always-active entry (always inserted)
- `probability`: Trigger probability (0-100)

---

## Custom World Info

You can create your own world info based on these JSON files:

```json
{
  "id": "unique_world_info_id",
  "name": "World Info Name",
  "description": "Description",
  "enabled": true,
  "isGlobal": false,
  "characterId": null,
  "entries": [
    {
      "id": "entry_001",
      "worldInfoId": "unique_world_info_id",
      "keys": ["Keyword1", "Keyword2"],
      "secondaryKeys": [],
      "content": "Content inserted when the keyword appears",
      "comment": "Entry description",
      "enabled": true,
      "constant": false,
      "selective": false,
      "insertionOrder": 100,
      "position": 1,
      "depth": 4
    }
  ],
  "createdAt": "2026-01-10T00:00:00.000Z",
  "modifiedAt": "2026-01-10T00:00:00.000Z"
}
```

---

## Best Practices

1. **Keyword Selection**
   - Use core terms as primary keywords
   - Avoid words that are too common (e.g., function words like "the" or "is")
   - Consider synonyms and variants

2. **Content Writing**
   - Keep it concise and clear, including key information
   - Use third-person descriptions
   - Avoid lengthy narration

3. **Insertion Control**
   - Use a lower insertionOrder for frequently used information
   - Important settings can be set as constant
   - Adjust position as needed

4. **Performance**
   - Avoid creating too many entries (recommended: fewer than 100)
   - Use selective to reduce unnecessary insertions
   - Periodically clean up unused entries

---

## Multilingual Design

Each world info uses a specific language for the best experience:

- 🇨🇳 **Chinese** - Spirit Realm Cultivation Chronicle (original cultivation culture)
- 🇬🇧 **English** - Guardian Universe (original superhero culture)
- 🇯🇵 **Japanese** - Eldia Legend (original fantasy culture)

This design ensures:

1. Using the original language preserves authenticity
2. It matches the habits of the target user group
3. Technical terminology remains accurate

---

## Contributing

Welcome to contribute more quality world info configurations!

Please ensure:
- Correct JSON format
- Accurate and professional content
- Reasonable keywords
- Complete field information
- **Original content, no copyright infringement**
