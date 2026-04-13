# Design System Document: The Ethereal Rhythm

## 1. Overview & Creative North Star
This design system is built to transform the digital music experience from a utility into a curated, sensory journey. Our Creative North Star is **"The Ethereal Gallery."** 

Unlike traditional music players that rely on dense grids and heavy dividers, this system treats sound as a premium artifact. We break the "template" look by utilizing expansive negative space, intentional asymmetry in layout transitions, and an editorial typographic hierarchy. Every element should feel as though it is floating in a pressurized, clean environment—weightless yet grounded by soft physics.

## 2. Colors
Our palette is derived from the soft intersection of twilight lavenders and misty grays. It is designed to be felt rather than just seen.

*   **The "No-Line" Rule:** To maintain a high-end editorial feel, **1px solid borders are strictly prohibited** for sectioning or containment. Boundaries must be defined solely through background color shifts. For example, a content block using `surface_container_low` (#f1f3fb) should sit directly on a `background` (#f8f9ff) to create a soft, edge-less transition.
*   **Surface Hierarchy & Nesting:** Use surface-container tiers to create biological depth. An album card should use `surface_container_lowest` (#ffffff) to appear closest to the user, nested within a `surface_container` (#eaeef7) view.
*   **The "Glass & Gradient" Rule:** For floating play-bars or navigation overlays, use Glassmorphism. Apply `surface_bright` (#f8f9ff) at 70% opacity with a 20px backdrop-blur. 
*   **Signature Textures:** For primary call-to-actions or the background of the "Now Playing" screen, use a subtle linear gradient from `primary` (#525b96) to `primary_container` (#aab2f4). This provides a "soul" to the UI that flat hex codes cannot replicate.

## 3. Typography
We use a dual-typeface system to balance modern authority with effortless readability.

*   **The Voice (Plus Jakarta Sans):** Used for `display`, `headline`, and `title` scales. Its geometric precision and open counters provide a contemporary, "designed" feel. Use `display-lg` (3.5rem) for track titles to dominate the space with an editorial confidence.
*   **The Detail (Manrope):** Used for `body` and `label` scales. Manrope’s functional elegance ensures that even at `label-sm` (0.6875rem), metadata like bitrates or timestamps remain perfectly legible without feeling "techy."
*   **Editorial Spacing:** Always increase the tracking (letter-spacing) on `label-md` by 3–5% to give small text a premium, "spaced out" appearance.

## 4. Elevation & Depth
In this design system, depth is a product of light and layering, not artificial lines.

*   **The Layering Principle:** Depth is achieved by "stacking" the surface-container tiers. For the music library, use `surface` as the base, `surface_container_low` for the sidebar, and `surface_container_highest` for active selection states.
*   **Ambient Shadows:** When a floating effect is required (e.g., a "Play" FAB), shadows must be extra-diffused. Use a blur of 30px–40px and an opacity of 6%. The shadow color should not be black; use `primary_dim` (#464e89) at 8% opacity to mimic natural, color-tinted ambient light.
*   **The "Ghost Border" Fallback:** If a container requires more definition for accessibility (like an input field), use a "Ghost Border." Apply `outline_variant` (#acb2bd) at a maximum of 15% opacity. Never use a 100% opaque border.
*   **Glassmorphism & Depth:** To make the layout feel integrated, utilize semi-transparent containers for player controls. This allows the album art colors to softly bleed through the UI, making the app feel alive and responsive to the music.

## 5. Components

### Buttons
*   **Primary:** Use a pill-shape (`full` rounding). Background: `primary` (#525b96); Text: `on_primary` (#faf8ff).
*   **Secondary/Play Controls:** Use `surface_container_highest` (#dde3ee) with a soft `on_surface` icon.
*   **Tertiary:** Transparent background with `primary` text. Use only for low-emphasis actions like "View All."

### Cards (Album & Artist)
*   **Style:** No borders. Use `surface_container_lowest` (#ffffff) for the card body. 
*   **Radius:** Always use `lg` (2rem) for album art and `md` (1.5rem) for the card container itself to create a "nested" radius look.
*   **Interaction:** On hover/active, transition the shadow from 4% to 8% opacity and scale the card by 1.02.

### Lists (Tracklists)
*   **Rule:** Forbid the use of divider lines. 
*   **Separation:** Use vertical white space (1.5rem between items) and subtle background shifts. An active track should use a `surface_container_high` (#e4e8f2) background with `DEFAULT` (1rem) rounded corners.

### Player Progress Bar
*   **Track:** `secondary_container` (#e0e2ee).
*   **Progress:** `primary` (#525b96).
*   **Thumb:** A floating `surface_container_lowest` circle with a subtle ambient shadow.

### Input Fields (Search)
*   **Style:** `surface_container_low` (#f1f3fb) background, `full` rounding, and a "Ghost Border" of `outline_variant` at 10%.

## 6. Do's and Don'ts

### Do:
*   **Do** use extreme white space. If you think there is enough room between elements, add 8px more.
*   **Do** use asymmetrical layouts for artist profiles—place the artist's name overlapping the edge of their header image for a custom feel.
*   **Do** use `primary_fixed_dim` (#9ca4e5) for icons to give them a soft, intentional tint.

### Don't:
*   **Don't** use pure black (#000000) for text. Always use `on_surface` (#2d333b) to keep the contrast soft and readable.
*   **Don't** use standard 4px or 8px corners. Our brand is defined by the `md` (1.5rem) and `lg` (2rem) scales.
*   **Don't** use "Drop Shadows" that have a visible offset (X:0, Y:0 is preferred with high blur) to ensure the light source feels top-down and natural.
*   **Don't** crowd the "Now Playing" screen. If a piece of metadata isn't essential, hide it behind a "More Info" tap.