# ADR-001: Standard SwiftUI Adoption

**Status**: Accepted  
**Date**: 2026-01-31  
**Decision Makers**: Development Team  
**Outcome**: Complete migration to standard SwiftUI completed, all Liquid Glass components removed

## Context and Problem Statements:\*\* [RFC: Liquid Glass Design Adoption](/docs/rfc/liquid-glass-design-adoption.md)

## Context and Problem Statement

The project initially implemented a custom design system called "Liquid Glass." While visually distinct, this system introduced custom components (`LGButton`, `LGTextField`, etc.) and visual modifiers that deviate from the standard macOS design language.

We want to ensure the application feels like a native, "first-party" Apple application. Maintaining a custom design system also increases the maintenance burden and risks breaking with future macOS updates.

## Decision Drivers

1.  **Native Experience:** The app should feel indistinguishable from standard Apple apps (Mail, Notes, Settings).
2.  **Maintenance:** Reducing custom UI code simplifies the codebase and leverages Apple's ongoing improvements to SwiftUI.
3.  **Accessibility:** Standard SwiftUI components have built-in support for system-wide accessibility features (VoiceOver, High Contrast, Reduce Transparency).
4.  **Future-Proofing:** Standard components automatically adapt to new macOS design iterations.

## Considered Options

1.  **Keep Liquid Glass:** Maintain the premium, custom aesthetic.
2.  **Hybrid Approach:** Use standard components for logic but keep custom glass blurs.
3.  **Standard SwiftUI (Chosen):** Replace all custom components with native SwiftUI equivalents.

## Decision Outcome

**Chosen Option: Standard SwiftUI**

We will refactor the entire application to use native SwiftUI components and patterns. This involves:

- Replacing `LGButton` with `Button` using `.buttonStyle(.borderedProminent)` or `.buttonStyle(.bordered)`.
- Replacing `LGTextField` with `TextField` using `.textFieldStyle(.roundedBorder)`.
- Replacing `LGGroupBox` and `LGCard` with standard `GroupBox` or `Section` elements.
- Removing the `DesignSystem` directory.

### Positive Consequences

- Immediate "native" feel on macOS.
- Automatic support for user system preferences (Dark Mode, Accessibility).
- Significant reduction in UI-specific code complexity.
- Better performance by relying on optimized system-level rendering.

### Negative Consequences

- Loss of the unique "Liquid Glass" visual identity.
- Refactoring effort required across all UI-facing files.

## Implementation Plan

1.  **Cleanup:** Remove custom design system references.
2.  **View Refactoring:** Iterate through `ContentView`, `ModernSettingsView`, `OnboardingView`, and `DuplicateReviewView`.
3.  **Verification:** Ensure all layouts adapt correctly to window resizing and system settings.
4.  **Removal:** Delete `macos/Sources/ReceiptSorterApp/DesignSystem/`.
