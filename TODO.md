#  TODO

## Pending (from upstream)
- [ ] Bugfix: footnote option and super/sub script extension are incompatible.
- [ ] Bugfix: on dark style, there is a flashing white rectangle before show the preview on Monterey.
- [ ] Investigate if export syntax highlighting colors scheme style as CSS var overriding the default style
- [ ] Check inline images on network / mounted disk
- [ ] Localization support

## Completed (Private Fork - 1.1.0-Mermaid)
- [x] Mermaid diagram rendering with fullscreen viewer
- [x] Natural macOS zoom controls (pinch, double-click, ⌘+scroll)
- [x] Pan/drag functionality when zoomed
- [x] Multi-format file viewer (50+ languages)
- [x] Search in preview (⌘F)
- [x] Viewer mode (editor hidden by default)
- [x] Show in Finder toolbar button
- [x] Filename in window title bar
- [x] Fix syntax highlighting visibility (custom CSS theme)
- [x] Remove "Buy me a coffee" references

## Completed (upstream)
- [x] Check code signature and app group access (bypassed using an XPC process)
- [x] Syntax highlighting color scheme editor
- [x] Optimize the inline image extension for raw html code: process and embed the data only for fragments and not processing all the formatted html code.
- [x] Embed inline image for `<img>` raw tag without using javascript/callbacks.
- [x] Emoji extension: better code that parse the single placeholder and generate nodes inside the AST (this would avoid the CMARK_OPT_UNSAFE option for emojis as images)
- [x] Investigate CMARK_OPT_UNSAFE for inline images
- [x] Application screenshot in the docs
- [x] Extension to generate anchor link for heads
- [x] Sparkle update engine
- [x] Insert the `highlight` library on the build process
- [x] @rpath libwrapper
