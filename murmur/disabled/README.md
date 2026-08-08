# Temporarily disabled

`MurmurShortcuts.swift.disabled` holds the Siri / App Intents integration
(“Summarize my last recording”, “Draft a follow-up email”).

It was moved out of the app target because Xcode's `AppIntentsSSUTraining`
build phase (which trains the Siri/Spotlight phrase model) was failing the
build. The rest of the app is unaffected — App Intents are an optional extra.

## To re-enable later
1. Move it back into the target and restore the extension:
   ```bash
   mv murmur/disabled/MurmurShortcuts.swift.disabled \
      murmur/Murmur/Intents/MurmurShortcuts.swift
   ```
2. Rebuild. If `AppIntentsSSUTraining` fails again, clean the build folder
   (⇧⌘K) and delete DerivedData; if it still fails, it's usually an Xcode/OS
   toolchain issue with that phase rather than the code.
