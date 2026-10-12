# Icon artwork

The active icons were replaced with user-supplied corgi artwork from `tmp/App Icon.png` and `tmp/Menu Bar Icon.png`. Both source images are 1254x1254 with alpha. The prompts below document the previous blue-arrow artwork only; the generation model and exact prompts for the user-supplied artwork were not verified.

Generated with the built-in image_gen tool. The tool does not expose model selection; image 2.5 was not verified.

## App icon prompt

Use case: logo-brand. Asset type: production macOS application icon for BrowserSwitcher, a tiny utility for switching the default web browser. Create ONE standalone square 1024x1024 icon asset, not a mockup or presentation. A refined native macOS rounded-square tile, rich cobalt blue, subtle luminous depth and carefully restrained bevel. At its center a bold crisp white symbol: two horizontal arrows stacked, top arrow points right, bottom arrow points left, subtly contained inside the minimal outline of a browser window with two tiny toolbar dots. The browser frame should be simple and the switching arrows dominate, unmistakably legible at small sizes. Beautiful balanced geometry, generous internal negative space, frontal orthographic view, no perspective. Transparent background OUTSIDE the rounded-square tile, actual alpha transparency, with the tile occupying about 88 percent of canvas width centered. No lettering, no words, no numbers, no watermark, no extra elements. Deliver the finished icon only.

## Menu bar icon prompt

Use case: logo-brand. Asset type: production macOS menu bar template icon, companion to the provided BrowserSwitcher application icon. Reference image is the app icon; preserve its conceptual identity of a browser window containing rightward and leftward switching arrows. Generate ONE standalone pure solid BLACK symbol on a genuinely transparent background, 1024x1024 square. No blue tile, no background, no white pixels, no shadows, no gradient, no bevel, no mockup. Simplify aggressively for an 18 point macOS menu bar icon: strong clean rounded browser-window outline, a single thin toolbar divider near the top, two tiny round toolbar dots, two short horizontal arrows inside the lower content area, upper arrow pointing right and lower arrow pointing left. Balanced optical spacing, thick enough strokes and clear empty gaps so everything remains legible when reduced to 18x18 pixels. Keep the overall symbol centered within about 88 percent of the canvas, generous arrow separation. Exact monochrome black RGB 0,0,0 plus alpha only. Deliver the finished transparent glyph asset only.

The app icon was supplied as the reference for the menu bar icon. Source PNG alpha is preserved during resizing. Menu bar assets are loaded as an AppKit template image so macOS controls tint.
