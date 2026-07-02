# Flutter Mobile Hot-Update Technical Analysis

## Requirement Background

- **Target platforms**: iOS + Android mobile
- **Key constraint**: Must be published on the App Store
- **Use case**: Bug fixes and small feature updates

---

## ⚠️ Core Conclusion (Bottom Line Up Front)

### Flutter does not natively support hot updates for business code

This is determined by two combined factors: **technical architecture** and **platform policy**:

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter Compilation Modes                │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Development Mode (Debug)   Release Mode (Release)          │
│  ┌─────────────────┐      ┌─────────────────┐              │
│  │   Dart VM       │      │   AOT Compile   │              │
│  │   JIT Compile   │      │   Machine Code  │              │
│  │   ↓             │      │   ↓             │              │
│  │   Supports Hot  │      │   Not Replace-  │              │
│  │   Reload        │      │   able (Frozen) │              │
│  └─────────────────┘      └─────────────────┘              │
│                                                             │
│  Used only for dev/debug   The App Store ships this version │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Technical reasons**:
- Flutter Release mode uses **AOT (Ahead-of-Time) compilation**
- Dart code is compiled into **native machine code** (`libapp.so` / `App.framework`)
- There is no Dart VM at runtime, so new code cannot be interpreted/executed
- This is a deliberate Flutter design choice in pursuit of performance

**Policy reasons**:
- Apple App Store Review Guideline 2.5.2 **explicitly prohibits** downloading executable code
- Even if technically feasible, such an app risks rejection or removal from the store

### Comparison with other technologies

| Tech Stack | Hot-Update Capability | Reason |
|--------|-----------|------|
| **Flutter** | ❌ Not supported | AOT-compiled to machine code |
| **React Native** | ⚠️ Limited | JavaScript can be loaded dynamically, but the App Store restricts this |
| **Native iOS** | ❌ Not supported | Compiled language |
| **Mini Programs** | ✅ Supported | Runs inside the host app's container |
| **Web App** | ✅ Supported | Interpreted execution |

### Why does React Native's hot-update mechanism (CodePush) also carry risk?

Although React Native uses JavaScript (an interpreted language) and can theoretically load code dynamically:
- Microsoft CodePush was widely used in the past
- But Apple has tightened its review process in recent years
- Multiple apps have been rejected or removed for using CodePush
- Policy enforcement remains uncertain

---

## Core Issue: App Store Policy Restrictions

### Apple App Store Review Guideline 2.5.2

> "Apps must be self-contained in their bundles, and may not read or execute code that is not shipped in the approved bundle."

**Key restrictions**:
1. ❌ Downloading executable code is prohibited (including Dart AOT-compiled libapp.so)
2. ❌ Dynamically executing code is prohibited (e.g., JavaScript for core business logic)
3. ⚠️ Exception: JavaScript in a WebView / JavaScriptCore (with restrictions)

### Google Play Policy

Relatively more relaxed, but still has restrictions:
- Loading executable code from outside Google Play is allowed
- But it must comply with the malware policy
- Dynamically loaded code must comply with the developer policy

---

## Technical Options Evaluation

### Option 1: Shorebird (Officially Recommended)

**Principle**: Delta updates of Dart AOT code

```
┌─────────────────┐     ┌─────────────────┐
│   Original App  │     │   Patch Server  │
│  (App Store)    │     │   (Shorebird)   │
└────────┬────────┘     └────────┬────────┘
         │                       │
         │   Check for patches   │
         ├──────────────────────►│
         │                       │
         │   Download diff patch │
         │◄──────────────────────┤
         │                       │
         │   Apply patch at      │
         │   runtime             │
         └───────────────────────┘
```

**Pros**:
- ✅ Official Flutter partner
- ✅ Can update Dart code without resubmitting to the store
- ✅ Supports both iOS and Android
- ✅ Delta updates, small patch size

**Cons**:
- ⚠️ Subscription-based pricing (free tier has limitations)
- ⚠️ Sits in a gray area of iOS App Store policy
- ❌ Cannot update native code (Swift/Kotlin)
- ❌ Cannot add new native dependencies

**App Store compliance**: ⚠️ **Carries risk**
- Shorebird claims to work around the policy by "interpreting" rather than "executing" new code
- But Apple could change its interpretation or tighten review at any time
- There are already cases of apps being rejected for using similar techniques

### Option 2: Dynamic/Remote Configuration

**Principle**: Control app behavior via server-delivered configuration

```dart
// Example: remote config controlling a feature toggle
class RemoteConfig {
  static Future<Map<String, dynamic>> fetchConfig() async {
    final response = await dio.get('https://api.example.com/config');
    return response.data;
  }
}

// Use config to control UI display
Widget build(BuildContext context) {
  final config = ref.watch(remoteConfigProvider);
  
  if (config['enable_new_feature'] == true) {
    return NewFeatureWidget();
  }
  return OldFeatureWidget();
}
```

**Applicable scenarios**:
- ✅ Feature flags
- ✅ A/B testing
- ✅ Copy/image/config updates
- ✅ API endpoint switching
- ✅ Business rule parameter tuning

**Pros**:
- ✅ Fully compliant with App Store policy
- ✅ No additional cost (self-hosted or via Firebase)
- ✅ Takes effect in real time

**Cons**:
- ❌ Cannot fix code bugs
- ❌ Cannot add new feature logic
- ❌ Requires instrumentation to be added in advance in the code

**Recommended tools**:
- Firebase Remote Config
- LaunchDarkly
- ConfigCat
- A self-hosted configuration service

### Option 3: WebView Hybrid Architecture

**Principle**: Put part of the business logic in a WebView so it can be hot-updated via H5

```
┌─────────────────────────────────────────┐
│            Flutter App Shell            │
│  ┌───────────────────────────────────┐  │
│  │         Native Features           │  │
│  │  (Camera, Storage, etc.)          │  │
│  └───────────────────────────────────┘  │
│  ┌───────────────────────────────────┐  │
│  │           WebView Area            │  │
│  │  ┌─────────────────────────────┐  │  │
│  │  │    H5 Business Logic       │  │  │
│  │  │    (Hot Updatable)         │  │  │
│  │  └─────────────────────────────┘  │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

**Applicable scenarios**:
- ✅ Campaign/event pages
- ✅ Operations configuration pages
- ✅ Frequently changing business modules

**Pros**:
- ✅ Fully compliant with App Store policy
- ✅ True code hot-updating
- ✅ Can fix bugs and add features

**Cons**:
- ❌ Performance is worse than native
- ❌ Requires maintaining two separate tech stacks
- ❌ Interaction experience may be inconsistent
- ❌ Not suitable for core functionality

### Option 4: Modularization + Dynamic Plugin Download (Android Only)

**Principle**: Use Android Dynamic Feature Modules

```kotlin
// Android Dynamic Feature
val request = SplitInstallRequest.newBuilder()
    .addModule("feature_chat")
    .build()

splitInstallManager.startInstall(request)
```

**Pros**:
- ✅ Officially supported by Google Play
- ✅ Modules can be downloaded dynamically

**Cons**:
- ❌ Android only
- ❌ Not supported on iOS
- ❌ Complex to integrate with Flutter

### Option 5: Server-Driven UI

**Principle**: The UI structure is delivered by the server as a JSON description

```json
{
  "type": "column",
  "children": [
    {
      "type": "text",
      "value": "Welcome",
      "style": {"fontSize": 24, "fontWeight": "bold"}
    },
    {
      "type": "button",
      "label": "Click Me",
      "action": {"type": "navigate", "route": "/home"}
    }
  ]
}
```

```dart
// Flutter side parses and renders the JSON
Widget buildFromJson(Map<String, dynamic> json) {
  switch (json['type']) {
    case 'column':
      return Column(
        children: (json['children'] as List)
            .map((c) => buildFromJson(c))
            .toList(),
      );
    case 'text':
      return Text(json['value'], style: parseStyle(json['style']));
    case 'button':
      return ElevatedButton(
        onPressed: () => handleAction(json['action']),
        child: Text(json['label']),
      );
    // ... more components
  }
}
```

**Pros**:
- ✅ Compliant with App Store policy
- ✅ UI layout can be adjusted dynamically
- ✅ New pages can go live without a release

**Cons**:
- ⚠️ High implementation complexity
- ⚠️ Requires defining a complete component library
- ❌ Cannot add new native interactions
- ❌ Difficult to debug

**Mature implementations**:
- Airbnb's Lona
- Shopify's Hydrogen

---

## Recommendation for NativeTavern

Based on the project's characteristics (an AI chat app whose core functionality is relatively stable), a **combined strategy** is recommended:

### Tier 1: Remote Configuration (solves 80% of the problem)

```dart
// lib/core/services/remote_config_service.dart
class RemoteConfigService {
  static const String _configUrl = 'https://api.nativetavern.app/config';
  
  Future<AppConfig> fetchConfig() async {
    final response = await dio.get(_configUrl);
    return AppConfig.fromJson(response.data);
  }
}

@freezed
class AppConfig with _$AppConfig {
  const factory AppConfig({
    @Default(true) bool enableStreaming,
    @Default([]) List<String> supportedModels,
    @Default({}) Map<String, dynamic> featureFlags,
    @Default('') String minSupportedVersion,
    @Default('') String latestVersion,
    @Default('') String updateMessage,
    @Default(false) bool forceUpdate,
  }) = _AppConfig;
}
```

**Content that can be hot-updated**:
- List of supported LLM models
- API endpoint configuration
- Feature flags
- Error message copy
- Default parameter values

### Tier 2: Dynamic Resource Updates

```dart
// Dynamically download and cache resources
class DynamicResourceService {
  Future<void> updateResources() async {
    // Download new prompt templates
    await downloadPromptTemplates();
    // Download new character presets
    await downloadCharacterPresets();
    // Download new theme configurations
    await downloadThemeConfigs();
  }
}
```

**Resources that can be hot-updated**:
- Preset character cards
- Prompt templates
- Theme configurations
- Regex scripts
- World Info templates

### Tier 3: Forced Update Prompt

```dart
// When a major bug needs fixing
class UpdateCheckService {
  Future<void> checkForUpdates() async {
    final config = await remoteConfig.fetchConfig();
    final currentVersion = await PackageInfo.fromPlatform();
    
    if (config.forceUpdate && 
        isVersionLower(currentVersion.version, config.minSupportedVersion)) {
      showForceUpdateDialog(config.updateMessage);
    } else if (isVersionLower(currentVersion.version, config.latestVersion)) {
      showOptionalUpdateDialog();
    }
  }
}
```

### Tier 4: Consider Shorebird (Optional)

If the business genuinely needs frequent Dart code bug fixes, Shorebird can be evaluated:

```bash
# Install Shorebird
curl --proto '=https' --tlsv1.2 https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh -sSf | bash

# Initialize the project
shorebird init

# Publish a patch
shorebird patch --platform ios
shorebird patch --platform android
```

**Risk assessment**:
- Currently used by a large number of apps, with no large-scale removal reports so far
- But policy risk always exists
- Recommended only as a supplementary measure — do not over-rely on it

---

## Implementation Recommendations

### Phase 1: Infrastructure Setup

1. **Build the configuration service**
   - Use Firebase Remote Config or a self-hosted service
   - Design the configuration data structure
   - Implement client-side fetching and caching logic

2. **Implement version checking**
   - Forced-update logic
   - Optional-update prompt
   - App Store/Google Play redirect

3. **Dynamic resource system**
   - Resource version management
   - Incremental downloads
   - Local caching

### Phase 2: Instrument the Code in Advance

1. **Feature flag instrumentation**
   ```dart
   if (remoteConfig.isFeatureEnabled('new_chat_ui')) {
     return NewChatScreen();
   }
   return ChatScreen();
   ```

2. **Externalize parameters**
   ```dart
   final defaultTemperature = remoteConfig.getDouble('default_temperature', 0.8);
   ```

3. **Make error handling configurable**
   ```dart
   final errorMessage = remoteConfig.getString('api_error_message', 'An error occurred');
   ```

### Phase 3: Evaluate Shorebird (Optional)

1. Small-scale testing
2. Monitor review outcomes
3. Establish a rollback mechanism

---

## Technical Comparison Summary

| Option | App Store Compliant | Bug Fixes | New Features | Implementation Difficulty | Cost |
|------|---------------|----------|--------|----------|------|
| Shorebird | ⚠️ Gray area | ✅ | ⚠️ Limited | Low | Paid |
| Remote Config | ✅ | ❌ | ⚠️ Toggle only | Low | Low/Free |
| WebView Hybrid | ✅ | ✅ Partial | ✅ Partial | High | Medium |
| Server-Driven UI | ✅ | ⚠️ UI layer only | ⚠️ UI layer only | Very high | High |
| Forced Update | ✅ | ✅ | ✅ | Low | Low |

---

## Final Recommendation

For the NativeTavern project, the following strategy is recommended:

1. **Short term (can be done immediately)**:
   - Implement the remote configuration system
   - Implement version checking and update prompts
   - Externalize configurable items

2. **Medium term (1-2 months)**:
   - Build the dynamic resource update system
   - Instrument feature flags in the code
   - Evaluate whether to introduce Shorebird

3. **Long term (as needed)**:
   - If frequent business logic updates are genuinely required, consider implementing specific modules with a WebView
   - Continuously monitor policy changes for Flutter/Shorebird

**Core principle**: Prioritize App Store compliance, and maximize flexibility on top of that foundation.
