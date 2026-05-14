# UniHub Mobile Design System

## Overview

This document defines the professional design standards for the UniHub mobile application. All UI components, screens, and layouts must adhere to these guidelines to ensure visual consistency, professional quality, and excellent user experience.

## Color Palette

### Primary Colors (Brand)

- **Primary Blue**: `#3b5bfd` (main interactive elements, buttons, links)
- **Primary Blue Variants**:
  - 50: `#f0f4ff` (very light background)
  - 100: `#e0e9ff`
  - 200: `#c7d9ff`
  - 300: `#a4c0ff`
  - 400: `#7aa5ff`
  - 500: `#5a84ff`
  - 600: `#3b5bfd` (main brand)
  - 700: `#2d47e8`
  - 800: `#2837d2`
  - 900: `#273190` (dark mode)

### Secondary Colors (Neutral/Grayscale)

- **Gray 50**: `#f8f9fa` (lightest backgrounds)
- **Gray 100**: `#f1f3f5`
- **Gray 200**: `#e9ecef`
- **Gray 300**: `#dee2e6`
- **Gray 400**: `#ced4da`
- **Gray 500**: `#adb5bd` (medium gray)
- **Gray 600**: `#6c757d`
- **Gray 700**: `#495057`
- **Gray 800**: `#343a40`
- **Gray 900**: `#212529` (darkest)

### Semantic Colors

- **Success**: `#22c55e` (green, confirmations)
- **Warning**: `#f59e0b` (yellow, cautions)
- **Error/Accent**: `#f04438` (red, destructive actions)
- **Info**: `#0ea5e9` (blue, informational)

## Typography

### Font Family

Use the system font stack:
- iOS: San Francisco (SF Pro Display, SF Pro Text)
- Android: Roboto
- Web: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto

### Font Sizes & Line Heights

| Style | Size | Line Height | Weight | Usage |
|-------|------|-------------|--------|-------|
| Display 3XL | 30px | 36px | 700 | Large headings |
| Display 2XL | 24px | 32px | 700 | Section titles |
| Heading XL | 20px | 28px | 600 | Screen titles |
| Heading Large | 18px | 28px | 600 | Card titles |
| Body Large | 16px | 24px | 400 | Main content |
| Body Base | 16px | 24px | 400 | Default text |
| Body Small | 14px | 20px | 400 | Secondary text |
| Label Small | 12px | 16px | 500 | Form labels, captions |

### Font Weights

- **Light (300)**: Rarely used
- **Normal (400)**: Body text, standard content
- **Medium (500)**: Form labels, secondary headings
- **Semibold (600)**: Section titles, emphasis
- **Bold (700)**: Main headings, CTAs

## Spacing Scale

Use the 8px base unit for consistent spacing:

```
4px   (xs)
8px   (sm)
16px  (md)
24px  (lg)
32px  (xl)
48px  (2xl)
64px  (3xl)
```

**Guidelines**:
- Padding inside components: 8px or 16px
- Margin between components: 16px or 24px
- Spacing between sections: 24px or 32px

## Border Radius

| Style | Value | Usage |
|-------|-------|-------|
| None | 0px | Rare, no rounding |
| Small | 4px | Small interactive elements |
| Medium | 8px | Standard buttons, cards |
| Large | 12px | Large cards, modals |
| XL | 16px | Prominent containers |
| 2XL | 20px | Large rounded containers |
| Full | 9999px | Circles, avatars, pills |

**Guidelines**:
- Buttons: 8px (medium)
- Cards: 12px (large)
- Inputs: 8px (medium)
- Avatars: 9999px (full circle)

## Shadows

Layered shadows for depth (iOS-style):

### Small Shadow
```
shadowColor: #000
shadowOffset: { width: 0, height: 1 }
shadowOpacity: 0.18
shadowRadius: 1.0
elevation: 1 (Android)
```
Use for: Hover states, subtle elements

### Medium Shadow
```
shadowColor: #000
shadowOffset: { width: 0, height: 2 }
shadowOpacity: 0.25
shadowRadius: 3.84
elevation: 5 (Android)
```
Use for: Default cards, modals

### Large Shadow
```
shadowColor: #000
shadowOffset: { width: 0, height: 4 }
shadowOpacity: 0.3
shadowRadius: 4.65
elevation: 8 (Android)
```
Use for: Floating buttons, prominent overlays

### Extra Large Shadow
```
shadowColor: #000
shadowOffset: { width: 0, height: 8 }
shadowOpacity: 0.35
shadowRadius: 6.27
elevation: 12 (Android)
```
Use for: Full-screen modals, overlays

## Component Standards

### Buttons

**Primary Button**:
- Background: Primary blue (`#3b5bfd`)
- Text: White
- Padding: 12px (vertical), 16px (horizontal)
- Border radius: 8px
- Font weight: 600
- Min width: 44px (touch target)

**Secondary Button**:
- Background: Gray 100 (`#f1f3f5`)
- Text: Gray 900 (`#212529`)
- Padding: 12px (vertical), 16px (horizontal)
- Border radius: 8px
- Font weight: 600

**Disabled State** (all buttons):
- Opacity: 0.5
- Cursor: Not allowed
- User interaction: None

### Input Fields

- Height: 44px (touch target)
- Padding: 10px (vertical), 12px (horizontal)
- Border: 1px solid `#dee2e6`
- Border radius: 8px
- Font size: 16px
- Focused border: 2px solid primary blue
- Placeholder color: `#adb5bd`

### Cards

- Background: White
- Border radius: 12px
- Padding: 16px
- Shadow: Medium shadow
- Border: None (unless elevated)

### Lists

- Item height: 48px minimum
- Padding: 12px (vertical), 16px (horizontal)
- Divider: 1px solid `#e9ecef`
- Hover state: Background light gray

### Modals

- Overlay: Black with 50% opacity
- Container: White, rounded 12px
- Padding: 24px
- Shadow: Extra large shadow
- Animation: Slide up (250ms)

## Spacing Rules

### Screen Layout
```
Padding: 16px (horizontal), 16-24px (vertical)
Max content width: 100% (mobile responsive)
Safe area: Respect notches, home indicators
```

### Component Spacing
```
Vertical spacing between sections: 24px
Vertical spacing between items: 12px
Horizontal spacing between elements: 8px
```

### Touch Targets
```
Minimum: 44x44px (iOS), 48x48px (Android)
Comfortable: 48x48px+
```

## Typography Hierarchy

```
Screen Title           → 2XL (24px), Bold
Section Header        → XL (20px), Semibold
Card Title            → Large (18px), Semibold
Body Text             → Base (16px), Normal
Secondary Text       → Small (14px), Normal
Labels & Captions    → Small (12px), Medium
```

## Interactive States

All interactive elements should have clear states:

- **Default**: Normal appearance
- **Hover/Focus**: Slight opacity change, subtle shadow
- **Pressed/Active**: Darker shade or lower shadow
- **Disabled**: 0.5 opacity, no interaction

## Accessibility

### Color Contrast

- **Text on Background**: Minimum WCAG AA (4.5:1 for normal, 3:1 for large)
- Primary text on white: ✅ Sufficient
- Secondary text on white: ✅ Sufficient

### Touch Areas

- Minimum 44x44px (iOS), 48x48px (Android)
- Space buttons 8px apart minimum

### Text

- Minimum font size: 12px (labels only, 14px preferred)
- Maximum line length: 70 characters for readability
- Line height: 1.5x minimum

## Animation & Motion

### Duration

- Quick interactions: 150ms
- Standard transitions: 250ms
- Slow/detailed: 400ms

### Easing

- Standard: `ease-in-out`
- Fast in/slow out: `ease-out`
- Slow in/fast out: `ease-in`

## Dark Mode (Future)

- Invert background colors
- Adjust text color for contrast
- Maintain semantic color meanings

## Professional Quality Checklist

Before any UI/UX PR submission:

- [ ] All text uses correct font sizes and weights
- [ ] Spacing follows the 8px grid
- [ ] All buttons are 44x44px minimum
- [ ] Cards use correct shadow depth
- [ ] Colors match the palette exactly
- [ ] Border radius follows guidelines
- [ ] Touch states are clear and consistent
- [ ] Color contrast meets WCAG AA
- [ ] No hardcoded colors (use theme constants)
- [ ] Consistent with other screens

## Code Examples

### Using Theme in Components

```tsx
import { colors, spacing, borderRadius } from "@theme";

const styles = {
  button: {
    backgroundColor: colors.primary[600],
    paddingVertical: spacing.md,
    paddingHorizontal: spacing.lg,
    borderRadius: borderRadius.md,
  },
};
```

### With NativeWind

```tsx
<TouchableOpacity className="bg-primary-600 px-6 py-3 rounded-lg">
  <Text className="text-white font-semibold text-base">Submit</Text>
</TouchableOpacity>
```

## Resources

- [Apple HIG](https://developer.apple.com/design/human-interface-guidelines/)
- [Material Design 3](https://m3.material.io/)
- [WCAG 2.1](https://www.w3.org/WAI/WCAG21/quickref/)

---

**Last Updated**: May 14, 2026  
**Version**: 1.0 (Initial)
