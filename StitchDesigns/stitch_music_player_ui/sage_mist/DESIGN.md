# Design System Document: The Ethereal Ground

## 1. Overview & Creative North Star
**The Creative North Star: "Atmospheric Precision"**

This design system rejects the clinical, rigid structures of traditional SaaS interfaces. Instead, it seeks to emulate the quiet, layered depth of a forest at dawn. It is an editorial-first approach where content isn't just "placed," it is curated within a misty, organic environment. 

We move beyond the "template" look by utilizing **Intentional Asymmetry** and **Tonal Depth**. By abandoning traditional lines and borders, we force the eye to recognize hierarchy through subtle shifts in value and generous, purposeful whitespace. The result is a high-end experience that feels both grounded (through warm neutrals) and weightless (through sage greens and glassmorphism).

---

## 2. Colors
Our palette is a sophisticated transition from the earth to the atmosphere.

### The "No-Line" Rule
**Strict Mandate:** Designers are prohibited from using 1px solid borders for sectioning or containment. 
Boundaries must be defined solely through background color shifts. For example, a card should not have an outline; it should be a `surface_container_low` (`#f3f4f0`) element sitting on a `background` (`#f9f9f6`) canvas. This creates a "soft edge" that feels integrated rather than boxed in.

### Surface Hierarchy & Nesting
Treat the UI as a series of physical layers—like stacked sheets of fine, heavy-stock paper. 
- **Base Level:** `background` (`#f9f9f6`) or `surface` (`#f9f9f6`).
- **Nesting:** To highlight a specific area, move to `surface_container_low` (`#f3f4f0`). To isolate a high-priority action or data point, use `surface_container_highest` (`#dee4de`). 
- **The Glass & Gradient Rule:** For floating navigation or modal overlays, use semi-transparent `surface` colors with a `backdrop-blur` of 12px-20px. 

### Signature Textures
CTAs should never be flat. Use subtle linear gradients for `primary` elements:
- **Primary Gradient:** Transition from `primary` (`#446557`) to `primary_dim` (`#38594c`) at a 135° angle. This adds "visual soul" and a tactile, premium finish.

---

## 3. Typography
We utilize **Plus Jakarta Sans** for its clean geometric foundations and modern, open apertures.

- **Display & Headlines:** Use high-contrast scaling. `display-lg` (3.5rem) should feel authoritative and editorial, with tight letter-spacing (-0.02em) to emphasize its "heavier" weight.
- **Body & Titles:** These are the workhorses of the system. `body-lg` (1rem) provides a comfortable reading experience, while `title-md` (1.125rem) acts as the bridge between narrative and navigation.
- **The Label Strategy:** `label-sm` (0.6875rem) should be used sparingly for metadata, always in `on_surface_variant` (`#5a615c`) to maintain a soft visual hierarchy.

---

## 4. Elevation & Depth
In a world without lines, depth is our only structural tool.

### The Layering Principle
Depth is achieved by "stacking" the surface-container tiers. Place a `surface_container_lowest` (#ffffff) card on a `surface_container` (#ecefea) section to create a soft, natural lift.

### Ambient Shadows
Shadows must mimic natural light. Use extra-diffused values:
- **Floating Shadow:** `0px 8px 32px rgba(46, 52, 48, 0.06)`. 
- **Shadow Color:** Use a tinted version of `on_surface` rather than pure black or grey to maintain the "Sage Mist" warmth.

### The "Ghost Border" Fallback
If accessibility requirements (WCAG 2.1) demand a container boundary, use a "Ghost Border": the `outline_variant` token (`#adb3ae`) at **15% opacity**. It should be felt, not seen.

### Glassmorphism
Apply `surface_bright` at 80% opacity with a blur effect to any element that "floats" above the content (e.g., sticky headers). This allows the colors of the content below to bleed through, softening the interface.

---

## 5. Components

### Buttons
- **Primary:** Gradient-filled (see Signature Textures), `xl` (1.5rem) rounded corners. Text is `on_primary` (`#dfffef`).
- **Secondary:** `secondary_container` (`#d5e6e0`) background. No border.
- **Tertiary:** Pure text with `primary` color. Interaction is shown by a subtle `surface_variant` background hover state.

### Input Fields
- **Styling:** Use `surface_container_low` as the background. 
- **States:** On focus, the background shifts to `surface_container_high` and the label moves to a `primary` color. **Never** use a stroke for focus; use a subtle outer glow or a shift in background saturation.

### Cards & Lists
- **Forbid Dividers:** Do not use line separators between list items. Use 16px-24px of vertical white space or alternating tonal shifts (e.g., even rows on `surface`, odd rows on `surface_container_low`).
- **Rounding:** All cards must follow the `lg` (1rem) or `xl` (1.5rem) roundedness scale to maintain the organic aesthetic.

### Additional Signature Component: The "Mist" Header
A hero component that utilizes a large-scale `display-lg` heading overlapping a container edge. The background of the header should use a soft radial gradient from `surface_container` to `background`.

---

## 6. Do's and Don'ts

### Do
- **Do** use asymmetrical margins (e.g., 80px left, 120px right) in editorial sections to break the "grid" feel.
- **Do** lean into `Plus Jakarta Sans`'s bolder weights for emphasis rather than using bright colors.
- **Do** ensure all interactive elements have a minimum touch target of 44px, despite the "soft" visual style.

### Don't
- **Don't** use pure black `#000000` or pure white `#FFFFFF` for any UI element (except `surface_container_lowest`). Use the neutral tokens provided.
- **Don't** ever use a 1px solid line to separate the header from the body.
- **Don't** use sharp corners. Every element must have a minimum of `sm` (0.25rem) rounding to remain consistent with the "organic" creative north star.