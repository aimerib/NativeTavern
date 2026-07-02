# Built-in Characters

This directory contains NativeTavern's built-in assistant character configuration files.

## Available Characters

### 1. AI Image Generation Assistant (image_generation_assistant.json) 🇯🇵
**Japanese Language Support**
**Features:** A professional assistant for creating AI image generation prompts
- Converts user ideas into detailed Stable Diffusion/Midjourney prompts
- Provides structured prompts (positive/negative)
- Recommends parameter settings and model selection
- Supports a variety of art styles

**Use Cases:**
- When you need AI image generation prompts
- Learning prompt engineering
- Exploring different art styles

---

### 2. Xiaohongshu Copywriter (xiaohongshu_copywriter.json) 🇨🇳
**Chinese Language Support**
**Features:** A professional content creation assistant for Xiaohongshu
- Writes eye-catching titles
- Generates copy that matches the platform's style
- Suggests topic hashtags
- Optimizes content structure and formatting

**Use Cases:**
- Xiaohongshu content creation
- Social media marketing
- Product recommendation / sharing content

---

### 3. Coding Assistant (coding_assistant.json) 🇬🇧
**English Support**
**Features:** Professional programming assistant
- Write and optimize code
- Debug and fix bugs
- Explain technical concepts
- Code review and refactoring suggestions
- Performance optimization

**Use Cases:**
- Daily programming tasks
- Learning new technologies
- Troubleshooting code issues
- Technical solution design

---

### 4. Spirit Vein Survival Simulator (cultivation_survival_game.json) 🇨🇳
**Original Chinese Cultivation World**
**Features:** A survival simulation game set in an original cultivation (xianxia) world
- Resource management and decision-making system
- Cultivation realm advancement mechanics
- Random event triggers
- Multiple ending exploration

**Use Cases:**
- Cultivation-themed role-play
- Strategic survival games
- Resource management simulation

---

### 5. Eldia Adventure Quest (hyrule_adventure_quest.json) 🇯🇵
**Original Japanese Fantasy**
**Features:** A text adventure set in an original fantasy world
- Puzzle-solving, combat, and exploration elements
- Turn-based combat system
- Item collection and status management
- Branching story paths through multiple choices

**Use Cases:**
- Fantasy adventure RPG
- Interactive story experience
- Puzzle-solving games

---

### 6. Guardian Protocol Manager (marvel_crisis_manager.json) 🇬🇧
**English Original Superhero Universe**
**Features:** Strategic crisis management in an original superhero setting
- Manage enhanced individual teams
- Resource allocation and decision-making
- Multiple simultaneous threats
- Consequence-based gameplay

**Use Cases:**
- Superhero strategy simulation
- Crisis management scenarios
- Team coordination games

---

## Usage

### Auto-loading
These built-in characters will be automatically loaded into the character list when you first launch the app.

### Features
- ✅ Ready to use, no manual import needed
- ✅ Smart deduplication, prevents duplicates
- ✅ Freely editable or deletable
- ✅ Loaded only once on first launch

---

## Custom Characters

You can create your own character configurations based on these JSON file formats:

```json
{
  "id": "unique_character_id",
  "name": "Character Name",
  "description": "Description",
  "personality": "Personality",
  "scenario": "Scenario",
  "firstMessage": "First Message",
  "alternateGreetings": ["Alternate Greetings"],
  "exampleMessages": "Example Dialogues",
  "systemPrompt": "System Prompt",
  "postHistoryInstructions": "Post Instructions",
  "tags": ["Tags"],
  "creator": "Creator",
  "version": "1.0",
  "createdAt": "2026-01-10T00:00:00.000Z",
  "modifiedAt": "2026-01-10T00:00:00.000Z",
  "isFavorite": false,
  "extensions": {
    "builtin": true,
    "category": "assistant"
  }
}
```

---

## Multilingual Support

Each character is designed in a specific language for the best user experience:

- 🇯🇵 **Japanese** - AI Image Generation Assistant (specialized in image generation), Eldia Adventure Quest (original fantasy)
- 🇨🇳 **Chinese** - Xiaohongshu Copywriter (specialized in Chinese social media), Spirit Vein Survival Simulator (original cultivation world)
- 🇬🇧 **English** - Coding Assistant (specialized in programming), Guardian Protocol Manager (original superhero)

This design ensures:

1. Most natural conversation experience
2. Use community-specific terminology
3. Match target user preferences

---

## Original Content Notice

**Important Notice:**

The game characters in this directory (Spirit Vein Survival Simulator, Eldia Adventure Quest, Guardian Protocol Manager) are **entirely original creations** and do not involve any copyright issues.

While these characters are inspired by classic works (cultivation novels, fantasy games, superhero comics), all worldbuilding, character names, and setting details have been reimagined to create unique original content.

---

## Best Practices

1. **systemPrompt**: Clearly define character capabilities, limitations, and behavior guidelines
2. **exampleMessages**: Provide high-quality conversation examples
3. **firstMessage**: Concisely introduce character features
4. **tags**: Use accurate tags for easy search and categorization

---

## Contributing

We welcome contributions of additional high-quality character configurations!

Please ensure:
- Correct JSON format
- Professional and valuable content
- Follow the existing structure and style
- Include complete field information
- **Original content, no copyright infringement**
