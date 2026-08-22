# Golden baselines

These images are exact, visually reviewed baselines for Flutter 3.47.1.
Windows and Linux use separate directories because their text and icon
rasterizers produce different edge antialiasing even when the same bundled OTF
files are loaded. Layout, colors, content, and component geometry remain the
same.

Do not copy one platform's images over another platform or add a percentage
tolerance. To update a baseline, render it on the matching host, inspect the
test image and all generated diff images for tofu, overflow, clipping, layout
movement, and unintended color changes, then run the scoped Golden tests again
without `--update-goldens`.
