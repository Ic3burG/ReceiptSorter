# Liquid Glass Design Adoption Plan

**Receipt Sorter macOS**  
Created: 2026-01-23  
Status: **SUPERSEDED** by [ADR 001: Standard SwiftUI Adoption](/docs/adr/001-standard-swiftui-adoption.md)

## Executive Summary

This plan outlines the adoption of **Liquid Glass** design language for Receipt Sorter, a native macOS application. Liquid Glass is a modern design philosophy that combines translucency, depth, and fluidity to create interfaces that feel premium, responsive, and alive. This design system will elevate Receipt Sorter from its current functional interface to a state-of-the-art macOS application that rivals Apple's own design aesthetics.

### Design Philosophy: Liquid Glass

Liquid Glass design is characterized by:

- **Translucency & Depth**: Multi-layered glass-like surfaces with blur effects
- **Fluid Motion**: Smooth, physics-based animations and transitions
- **Dynamic Lighting**: Adaptive shadows, glows, and gradients that respond to content
- **Material Hierarchy**: Clear visual distinction between surface layers
- **Premium Feel**: Polished, high-fidelity visual details

---

## Current State Analysis

### Existing Design Elements

Receipt Sorter currently implements:

- ✅ **iOS 26-inspired Settings sidebar** (`ModernSettingsView.swift`)
- ✅ **NavigationSplitView** architecture
- ✅ **GroupBox** containers for content organization
- ✅ **System colors** with semantic meaning (blue, green, orange, purple)
- ✅ **Native SwiftUI components** (TextField, Toggle, Button)

### Design Gaps

Receipt Sorter lacks:

- ❌ **Visual depth** - Flat GroupBox containers without layering
- ❌ **Translucent materials** - No blur effects or glass morphism
- ❌ **Dynamic animations** - Limited micro-interactions
- ❌ **Premium visual polish** - Missing shadows, glows, and gradients
- ❌ **Cohesive design language** - Inconsistent visual hierarchy
- ❌ **Dark mode optimization** - Basic dark mode without enhanced visuals

---

## Design System Components

### 1. Material System

#### Glass Surfaces

Create reusable glass material modifiers for consistent application:

```swift
// Primary glass surface - Main content areas
.glassSurface(intensity: .standard)

// Secondary glass - Nested content, cards
.glassSurface(intensity: .subtle)

// Elevated glass - Popovers, modals, floating elements
.glassSurface(intensity: .prominent)
```

**Visual Properties:**

- **Background**: Semi-transparent with adaptive blur
- **Border**: 0.5pt hairline with gradient opacity
- **Shadow**: Multi-layer soft shadows for depth
- **Blur radius**: 20-40pt depending on intensity

#### Material Hierarchy

```text
Level 1: Base window (subtle blur)
  ├─ Level 2: Content containers (standard glass)
  │   ├─ Level 3: Cards/GroupBoxes (enhanced glass)
  │   │   └─ Level 4: Interactive elements (elevated glass)
```

### 2. Color & Gradient System

#### Adaptive Color Palette

```swift
// Base colors with glass-optimized opacity
struct LiquidGlassColors {
    // Accent colors with glow variants
    static let accentBlue = LinearGradient(
        colors: [Color(hex: "007AFF"), Color(hex: "5AC8FA")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGreen = LinearGradient(
        colors: [Color(hex: "34C759"), Color(hex: "30D158")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Glass tints for different states
    static let glassLight = Color.white.opacity(0.08)
    static let glassDark = Color.black.opacity(0.15)

    // Dynamic shadows
    static let shadowLight = Color.black.opacity(0.08)
    static let shadowDark = Color.black.opacity(0.25)
}
```

#### Gradient Applications

- **Backgrounds**: Subtle mesh gradients for depth
- **Buttons**: Animated gradient fills on hover/press
- **Icons**: Gradient overlays for premium feel
- **Borders**: Gradient strokes with varying opacity

### 3. Typography System

#### Font Hierarchy

```swift
struct LiquidGlassTypography {
    // Headings with subtle glow effect
    static let largeTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let title = Font.system(.title, design: .rounded, weight: .semibold)
    static let headline = Font.system(.headline, design: .rounded, weight: .medium)

    // Body with optimized readability on glass
    static let body = Font.system(.body, design: .default, weight: .regular)
    static let caption = Font.system(.caption, design: .default, weight: .regular)

    // Monospaced for data
    static let code = Font.system(.body, design: .monospaced, weight: .regular)
}
```

**Typography Enhancements:**

- Text shadows for depth on translucent backgrounds
- Increased letter spacing for readability
- Dynamic weight adjustment based on background luminosity

### 4. Animation & Motion System

#### Core Principles

1. **Spring Physics**: All animations use spring curves for natural motion
2. **Stagger Effects**: Sequential animations for lists and grids
3. **Hover States**: Smooth scale and glow transitions
4. **Loading States**: Shimmer effects on glass surfaces

#### Animation Presets

```swift
struct LiquidGlassAnimations {
    // Quick interactions
    static let quickSpring = Animation.spring(response: 0.3, dampingFraction: 0.7)

    // Standard UI transitions
    static let standardSpring = Animation.spring(response: 0.5, dampingFraction: 0.75)

    // Smooth, luxurious transitions
    static let smoothSpring = Animation.spring(response: 0.7, dampingFraction: 0.8)

    // Floating elements
    static let floatingAnimation = Animation
        .easeInOut(duration: 2.0)
        .repeatForever(autoreverses: true)
}
```

### 5. Interactive Components

#### Buttons

##### Standard Button

- Glass background with subtle gradient
- Scale animation on press (0.96x)
- Glow effect on hover
- Haptic feedback on press

##### Primary Button

- Vibrant gradient fill
- Pulsing glow animation
- Icon animation on hover
- Elevated shadow

##### Icon Button

- Circular glass background
- Rotation animation on press
- Color transition on hover

#### Input Fields

- Glass container with inner shadow
- Animated border on focus
- Floating label animation
- Shimmer loading state

#### Cards & Containers

- Multi-layer shadow system
- Hover elevation effect
- Edge lighting on hover
- Corner radius: 16-20pt for premium feel

---

## Implementation Roadmap

### Phase 1: Foundation (Week 1-2)

#### 1.1 Design System Architecture

**Files to Create:**

- `DesignSystem/LiquidGlass/Materials.swift` - Glass surface modifiers
- `DesignSystem/LiquidGlass/Colors.swift` - Color and gradient system
- `DesignSystem/LiquidGlass/Typography.swift` - Font system
- `DesignSystem/LiquidGlass/Animations.swift` - Animation presets
- `DesignSystem/LiquidGlass/Shadows.swift` - Shadow system

**Implementation:**

1. Create `DesignSystem` folder in `ReceiptSorterApp`
2. Define core view modifiers for glass surfaces
3. Implement adaptive color system with light/dark mode
4. Create typography scale with text shadow support
5. Build reusable animation functions

#### 1.2 Component Library

**Files to Create:**

- `DesignSystem/Components/LGButton.swift` - Liquid Glass buttons
- `DesignSystem/Components/LGCard.swift` - Glass cards
- `DesignSystem/Components/LGTextField.swift` - Glass input fields
- `DesignSystem/Components/LGGroupBox.swift` - Enhanced GroupBox
- `DesignSystem/Components/LGSidebar.swift` - Glass sidebar

**Implementation:**

1. Create reusable component library
2. Implement hover states and animations
3. Add accessibility support (VoiceOver, Dynamic Type)
4. Create component playground for testing

### Phase 2: Settings Redesign (Week 3-4)

#### 2.1 Settings Window Enhancement

**Files to Modify:**

- `ModernSettingsView.swift` - Apply glass materials
- `GeneralSettingsDetailView` - Enhanced with glass components
- `ExportSettingsDetailView` - Redesigned with premium feel
- `OrganizationSettingsDetailView` - Glass card layout
- `CloudSyncSettingsDetailView` - Animated setup guide

**Visual Enhancements:**

1. **Sidebar:**
   - Glass background with subtle blur
   - Animated selection indicator with gradient
   - Hover glow effects on items
   - Icon animations on selection

2. **Detail Views:**
   - Replace GroupBox with LGCard components
   - Add floating header with glass background
   - Implement smooth scroll animations
   - Add loading shimmer states

3. **Interactive Elements:**
   - Replace standard buttons with LGButton
   - Glass TextField components
   - Animated toggles with gradient track
   - Premium progress indicators

#### 2.2 Micro-Interactions

**Animations to Add:**

1. **Page Transitions**: Smooth fade + slide when switching sections
2. **Button Presses**: Scale + glow animation
3. **Toggle Switches**: Smooth slide with gradient trail
4. **Text Field Focus**: Border glow animation
5. **File Picker**: Animated checkmark on selection

### Phase 3: Main Window Redesign (Week 5-6)

#### 3.1 ContentView Enhancement

**Files to Modify:**

- `ContentView.swift` - Main app interface

**Visual Redesign:**

1. **Drop Zone:**
   - Large glass panel with animated gradient border
   - Floating icon animations
   - Smooth scale animation on drag hover
   - Ripple effect on drop

2. **Preview Area:**
   - Glass container for PDF/image preview
   - Floating toolbar with glass background
   - Smooth zoom animations
   - Loading shimmer for OCR processing

3. **Status Display:**
   - Glass toast notifications
   - Animated progress bars with gradient
   - Success/error states with spring animations
   - Floating badges for receipt count

#### 3.2 Processing Animations

**Enhancements:**

1. **OCR Processing**: Scanning line animation over preview
2. **AI Extraction**: Pulsing glow effect
3. **Export Progress**: Smooth progress bar with gradient
4. **Success State**: Confetti animation + checkmark

### Phase 4: Advanced Features (Week 7-8)

#### 4.1 Menu Bar & Toolbar

**Implementation:**

- Glass menu bar items
- Animated dropdown menus
- Icon hover effects
- Keyboard shortcut overlays

#### 4.2 Onboarding Flow

**Enhancement:**

- Full-screen glass onboarding
- Step-by-step animations
- Progress indicator with gradient
- Smooth transitions between steps

#### 4.3 Receipt Preview

**Features:**

- Glass overlay UI on preview
- Annotation tools with glow
- Zoom lens effect
- Smooth page transitions for multi-page PDFs

### Phase 5: Polish & Optimization (Week 9-10)

#### 5.1 Performance Optimization

**Focus Areas:**

1. **Blur Performance**: Optimize glass material rendering
2. **Animation Efficiency**: Reduce GPU usage
3. **Memory Management**: Cache gradient resources
4. **Accessibility**: Respect reduced motion settings

#### 5.2 Dark Mode Refinement

**Enhancements:**

1. Enhanced glow effects in dark mode
2. Deeper shadows for better depth
3. Increased contrast for readability
4. Vibrant accent colors

#### 5.3 Accessibility

**Compliance:**

1. VoiceOver optimization for glass UI
2. Dynamic Type support
3. Reduced motion alternative animations
4. High contrast mode support
5. Keyboard navigation enhancements

---

## Technical Specifications

### SwiftUI Custom Modifiers

#### Glass Surface Modifier

```swift
struct GlassSurfaceModifier: ViewModifier {
    enum Intensity {
        case subtle, standard, prominent

        var blurRadius: CGFloat {
            switch self {
            case .subtle: return 20
            case .standard: return 30
            case .prominent: return 40
            }
        }

        var opacity: Double {
            switch self {
            case .subtle: return 0.6
            case .standard: return 0.7
            case .prominent: return 0.85
            }
        }
    }

    let intensity: Intensity
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    // Base glass layer
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .opacity(intensity.opacity)

                    // Gradient overlay
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.1 : 0.3),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // Border
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 10, x: 0, y: 4)
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.2 : 0.05), radius: 4, x: 0, y: 2)
    }
}

extension View {
    func glassSurface(intensity: GlassSurfaceModifier.Intensity = .standard) -> some View {
        modifier(GlassSurfaceModifier(intensity: intensity))
    }
}
```

### Performance Considerations

1. **Layer Management**: Limit blur layers to 3-4 maximum per view
2. **Shadow Optimization**: Use `drawingGroup()` for complex shadows
3. **Animation Performance**: Prefer `withAnimation` over implicit animations
4. **Gradient Caching**: Pre-render complex gradients
5. **Conditional Rendering**: Disable effects when window is inactive

### Platform Requirements

- **macOS**: 13.0 (Ventura) or later
- **Xcode**: 15.0 or later
- **SwiftUI**: Latest APIs for materials and blur effects

---

## Design Assets

### Icons & Graphics

**To Create:**

1. Glass-styled app icon with depth
2. Gradient category icons
3. Animated status icons
4. Premium onboarding illustrations

### Color Export

**Format:** Export color palette as:

- `.xcassets` color set
- SwiftUI `Color` extensions
- Design tokens JSON for future platforms

### Typography Export

**Font Configuration:**

- SF Pro Rounded for headings
- SF Pro for body text
- SF Mono for technical data
- Dynamic Type support table

---

## Verification & Testing Plan

### Visual QA Checklist

**Per Screen:**

- [ ] Glass materials render correctly
- [ ] Animations are smooth (60fps)
- [ ] Colors adapt in light/dark mode
- [ ] Shadows provide clear depth
- [ ] Hover states work properly
- [ ] Keyboard navigation works
- [ ] VoiceOver describes elements accurately

### Performance Benchmarks

**Targets:**

- Window launch: < 0.3s
- Animation frame rate: 60fps sustained
- Memory usage: < 200MB baseline
- CPU usage: < 15% idle with effects

### Accessibility Testing

**Test Matrix:**

- [ ] VoiceOver navigation complete
- [ ] Dynamic Type scales properly
- [ ] Reduced motion respected
- [ ] High contrast mode functional
- [ ] Keyboard shortcuts work
- [ ] Color blind friendly

### Device Testing

**Test on:**

- MacBook Pro (M-series) - Primary target
- MacBook Air (M-series) - Performance check
- Intel Mac (if supporting) - Compatibility
- External displays - Multi-monitor support

---

## Migration Strategy

### Gradual Rollout

**Phase 1**: Settings window only (low risk, high visibility)  
**Phase 2**: Main window enhancement (core functionality)  
**Phase 3**: All dialogs and auxiliary windows  
**Phase 4**: Menu items and system integration

### Fallback Strategy

- Keep original components in separate files
- Use feature flags for gradual rollout
- A/B test with user feedback
- Easy rollback if performance issues arise

### User Communication

**Changelog Entry:**

```markdown
## New: Liquid Glass Design 🌊✨

Receipt Sorter now features a stunning new design language with:

- Beautiful glass-like translucent surfaces
- Smooth, fluid animations throughout
- Enhanced dark mode with deeper depth
- Premium visual polish and micro-interactions

Experience a macOS app that feels as good as it looks.
```

---

## Success Metrics

### Qualitative Goals

- [ ] App feels more premium and professional
- [ ] Design is cohesive and intentional
- [ ] Animations feel natural and delightful
- [ ] Dark mode is beautiful and functional
- [ ] UI responds smoothly to all interactions

### Quantitative Targets

- **User Feedback**: >90% positive on design
- **Performance**: Maintain 60fps in all animations
- **Accessibility**: 100% VoiceOver coverage
- **Adoption**: Ship with Phase 4 (Distribution)

---

## Resources & References

### Design Inspiration

1. **macOS Ventura+**: System Settings app
2. **iOS 15+**: Translucent materials in Control Center
3. **Apple Music**: Glass player UI
4. **Arc Browser**: Premium glass aesthetics
5. **Linear**: Fluid animations and depth

### Technical References

- [Apple HIG - Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
- [SwiftUI Materials Documentation](https://developer.apple.com/documentation/swiftui/material)
- [Apple Design Resources](https://developer.apple.com/design/resources/)
- [SF Symbols](https://developer.apple.com/sf-symbols/)

### Community Resources

- [Hacking with Swift - SwiftUI by Example](https://www.hackingwithswift.com/quick-start/swiftui)
- [SwiftUI Lab - Advanced Techniques](https://swiftui-lab.com/)
- [Kavsoft - Animation Tutorials](https://www.youtube.com/@Kavsoft)

---

## Timeline Summary

| Phase                | Duration     | Deliverable                        |
| -------------------- | ------------ | ---------------------------------- |
| Phase 1: Foundation  | 2 weeks      | Design system & component library  |
| Phase 2: Settings    | 2 weeks      | Redesigned settings interface      |
| Phase 3: Main Window | 2 weeks      | Enhanced main app UI               |
| Phase 4: Advanced    | 2 weeks      | Menu, onboarding, preview          |
| Phase 5: Polish      | 2 weeks      | Optimization & accessibility       |
| **Total**            | **10 weeks** | **Complete Liquid Glass adoption** |

---

## Next Steps

1. **Review & Approval**: Get stakeholder buy-in on design direction
2. **Design Mockups**: Create high-fidelity mockups in Figma/Sketch
3. **Prototype**: Build quick prototype with core glass components
4. **User Testing**: Gather feedback on design direction
5. **Implementation**: Begin Phase 1 development

---

## Appendix

### Glossary

- **Liquid Glass**: Design philosophy combining translucency, depth, and fluidity
- **Material**: SwiftUI's blur-based background system
- **Glass Surface**: Custom translucent container with blur and shadows
- **Micro-interaction**: Small, delightful animations on user interaction

### Version History

| Version | Date       | Changes              |
| ------- | ---------- | -------------------- |
| 1.0     | 2026-01-23 | Initial plan created |

---

**Document Owner**: Receipt Sorter Development Team  
**Status**: Planning  
**Next Review**: Upon completion of Phase 1
