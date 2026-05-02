# Design System Strategy: The Analog Horizon

## 1. Overview & Creative North Star
The Creative North Star for this design system is **"The Analog Horizon."** 

This system moves away from the sterile, cold precision of modern SaaS interfaces, opting instead for a "High-End Editorial" experience that feels tactile and resonant. Inspired by the warm glow of vacuum tubes and the soft gradients of a desert dusk, the system prioritizes tonal depth over structural rigidity. We break the "template" look by utilizing intentional asymmetry, expansive negative space, and a typographic scale that values rhythm over density. The result is a digital environment that feels curated, premium, and inherently human.

---

## 2. Colors & The Tonal Philosophy

The palette is rooted in earth tones and thermal warmth. We do not use "gray" in this system; even our neutrals are infused with amber and ochre.

### The "No-Line" Rule
**Strict Mandate:** Designers are prohibited from using 1px solid borders for sectioning or containment. 
Boundaries must be defined solely through background color shifts or subtle tonal transitions. A layout should feel like a series of interlocking shapes rather than a wireframe. 
*   *Implementation:* To separate a sidebar from a main feed, use `surface-container-low` (#f7f3ee) against a `background` (#fdf9f4) canvas.

### Surface Hierarchy & Nesting
Treat the UI as a physical stack of fine paper. 
*   **Base:** `surface` (#fdf9f4)
*   **Nesting:** Place `surface-container-lowest` (#ffffff) cards on a `surface-container` (#f1ede8) section to create a soft, natural "lift."
*   **Depth:** Use the higher tiers (`surface-container-high` and `highest`) sparingly for interactive overlays or high-priority floating elements.

### Signature Textures & Glass
To provide "soul" that flat hex codes cannot:
*   **The Glow Gradient:** For hero areas or primary CTAs, use a linear gradient from `primary` (#944122) to `primary-container` (#b35938) at a 135-degree angle.
*   **The Tube-Amp Blur:** For floating navigation or context menus, use `surface-container-lowest` at 85% opacity with a `20px` backdrop-blur. This "frosted glass" effect allows the warm background colors to bleed through, softening the interface.

---

## 3. Typography: Editorial Authority

We use **Plus Jakarta Sans** across the entire system, but we manipulate its weight and scale to create an editorial feel.

*   **Display (lg/md/sm):** These are the "hero" moments. Use tight letter-spacing (-0.02em) and Bold weights. These should feel like magazine headlines.
*   **Headlines & Titles:** Use Medium weights. Ensure these have significant breathing room above them to signal the start of a new "chapter" in the content.
*   **Body (lg/md/sm):** Kept at Regular weight for maximum legibility. Line heights for `body-lg` should be generous (1.6) to maintain an airy, premium feel.
*   **Labels:** Small, all-caps, and often paired with increased letter-spacing (+0.05em) to differentiate them from functional text.

---

## 4. Elevation & Depth: Tonal Layering

Traditional shadows and borders are replaced by **Ambient Light** and **Material Stacks.**

*   **Layering Principle:** High-end design is achieved by stacking. If a container needs to stand out, change its background token rather than adding a shadow.
*   **Ambient Shadows:** If a "floating" state is required (e.g., a modal), use a shadow that is extra-diffused.
    *   *Shadow Setting:* `0px 12px 32px` with a 6% opacity of `on-surface` (#1c1c19). This mimics soft, overhead gallery lighting.
*   **The "Ghost Border" Fallback:** If a border is required for accessibility in complex forms, use `outline-variant` (#dbc1b9) at **15% opacity**. It should be felt, not seen.
*   **Roundedness Scale:**
    *   **Default:** `0.5rem` (Used for most containers/cards).
    *   **XL:** `1.5rem` (Used for large, hero-style image containers to emphasize softness).
    *   **Full:** `9999px` (Exclusively for Pill-style Chips and Action Buttons).

---

## 5. Components

### Buttons
*   **Primary:** A high-contrast pill (Rounded: Full) using the `primary` to `primary-container` gradient. Text is `on-primary` (#ffffff).
*   **Secondary:** Solid `secondary-container` (#f5ded0) with `on-secondary-container` (#726156) text. No border.
*   **Tertiary:** Text-only in `primary` (#944122) with a background-shift to `surface-container-high` on hover.

### Cards & Lists
*   **Cards:** Never use a divider line. Separate content using `body-sm` labels and 24px–32px of vertical padding. 
*   **Lists:** Individual list items are separated by a subtle toggle between `surface` and `surface-container-low` backgrounds on hover.

### Input Fields
*   **Styling:** Use a soft `surface-container-highest` (#e6e2dd) background with a `0.5rem` radius. 
*   **Focus State:** The background remains the same, but the `primary` (#944122) color appears as a 2px "inner glow" or a high-contrast label shift.

### Signature Component: The "Glow Switch"
Inspired by tube amplifiers, toggles should use the `primary` color as a soft outer glow when in the "on" position, suggesting a light being powered up.

---

## 6. Do's and Don'ts

### Do
*   **Do** use asymmetrical layouts. A card that is slightly offset from the grid feels custom and artisanal.
*   **Do** use the `on-primary-fixed-variant` for long-form reading on light surfaces to reduce eye strain while maintaining the "amber" tone.
*   **Do** embrace negative space. If a layout feels crowded, remove a container entirely rather than adding lines.

### Don't
*   **Don't** use pure black (#000000) or pure white (#FFFFFF) unless it is for the `surface-container-lowest` background.
*   **Don't** use 1px dividers to separate menu items. Use vertical spacing or a change in typography weight.
*   **Don't** use "Standard" Material shadows. If it looks like a default shadow, it's too heavy.
*   **Don't** use sharp corners. Everything in the Analog Horizon is softened by the heat of the "Dawn."