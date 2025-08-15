This directory contains patch-package patches to keep local fixes for node_modules applied after install.

To update a patch:
1. Make edits under node_modules for the package you need to patch.
2. Run: npx patch-package <package-name>
3. Commit the generated patch in this directory.

Current patches:
- expo-apple-authentication+6.3.0.patch : Adds @unknown default to AppleAuthenticationExceptions.swift to compile with newer iOS SDKs.
