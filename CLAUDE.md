# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Build Release (main scheme is "QLMardown" - note the typo)
xcodebuild -scheme "QLMardown" -configuration Release -derivedDataPath build build

# Install to Applications
rm -rf /Applications/QLMarkdown.app && cp -R build/Build/Products/Release/QLMarkdown.app /Applications/

# Build and Install (combined)
xcodebuild -scheme "QLMardown" -configuration Release -derivedDataPath build build && \
rm -rf /Applications/QLMarkdown.app && cp -R build/Build/Products/Release/QLMarkdown.app /Applications/

# Open app after install
open /Applications/QLMarkdown.app

# Quit app before rebuild
osascript -e 'quit app "QLMarkdown"'
```

**Note:** The Xcode scheme is named "QLMardown" (missing 'k') - this is intentional and must be used exactly as shown.

## Project Architecture

### Overview
QLMarkdown is a macOS Quick Look extension for previewing Markdown files. It consists of:

1. **Main App** (`QLMarkdown/`) - Settings UI and file viewer
2. **Quick Look Extension** (`QLExtension/`) - System Quick Look preview
3. **CLI Tool** (`qlmarkdown_cli/`) - Command-line batch conversion

### Key Files

| File | Purpose |
|------|---------|
| `QLMarkdown/ViewController.swift` | Main app UI, file handling, editor/preview split view |
| `QLMarkdown/Settings+render.swift` | Markdown rendering, HTML generation, Mermaid/Math support |
| `QLMarkdown/Settings.swift` | App settings and preferences |
| `QLExtension/PreviewViewController.swift` | Quick Look extension entry point |
| `QLExtension/Info.plist` | Supported UTIs for Quick Look |
| `QLMarkdown/Base.lproj/Main.storyboard` | UI layout, toolbar, menus |

### Rendering Pipeline

1. Markdown text → `cmark-gfm` parser (with extensions)
2. AST → HTML via `Settings+render.swift`
3. HTML wrapped with CSS/JS → `getCompleteHTML()`
4. Loaded into WKWebView for display

### Extensions System

Extensions are handled via `cmark-gfm` with custom additions:
- **Mermaid**: Transforms ` ```mermaid ` blocks to `<div class="mermaid">`, injects bundled mermaid.min.js
- **Math**: Uses MathJax (loaded from CDN)
- **Syntax Highlighting**: Uses embedded Highlight library (`highlight-wrapper/`)
- **Emoji**: Converts shortcodes, supports image/font rendering

### Dependencies (Submodules)

- `cmark-gfm/` - GitHub's Markdown parser
- `highlight-wrapper/highlight/` - Syntax highlighting
- `dependencies/pcre2/` - Regex library for heads extension

Initialize with: `git submodule update --init`

### Build Dependencies

Required via Homebrew:
```bash
brew install autoconf  # For libpcre2
brew install go        # For Enry language detection
brew install cmake     # For cmark-gfm
```

## Custom Features (This Fork)

### Viewer Mode
- Editor hidden by default (preview-only)
- Toggle with **⌘E** or toolbar button
- State persisted in UserDefaults (`qlmarkdown-editor-shown`)

### Mermaid Fullscreen Viewer
- Click diagram to open fullscreen overlay
- Zoom: pinch-to-zoom, ⌘+scroll, double-click toggle
- Pan: drag when zoomed > 1x
- Close: Escape or click outside

### Search in Preview
- **⌘F** opens search bar in WebView
- Highlights matches, navigation with Enter/Shift+Enter

### Window Title
- Shows filename and folder path
- `representedURL` set for standard macOS path menu

## Git Remotes

| Remote | URL | Purpose |
|--------|-----|---------|
| origin | sbarex/QLMarkdown | Original upstream |
| private | Alfahad/QLMarkdown-Private | Private development |
| fork | Alfahad/QLMarkdown | Public fork |

Push changes to `private` remote:
```bash
git push private main
```

## Development Workflow (Automated by Claude)

When the user asks to add a feature or fix a bug, Claude should handle the entire workflow automatically:

### 1. Before Starting Work
```bash
# Ensure on main branch and up to date
git checkout main
git pull private main
```

### 2. Implement the Feature
- Make code changes
- Build and test: `osascript -e 'quit app "QLMarkdown"' && xcodebuild -scheme "QLMardown" -configuration Release -derivedDataPath build build`
- Install and verify: `rm -rf /Applications/QLMarkdown.app && cp -R build/Build/Products/Release/QLMarkdown.app /Applications/ && open /Applications/QLMarkdown.app`

### 3. Commit and Push
```bash
git add -A
git commit -m "Feature/fix description

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
git push private main
```

### 4. Update Documentation (if significant feature)
- **CHANGELOG.md**: Add entry under current version section at top
- **TODO.md**: Mark items as completed or add new items
- **README.md**: Update if user-facing feature documentation needed

### Commit Message Format
```
<type>: <short description>

<optional body with details>

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
```

Types: `Add`, `Fix`, `Update`, `Remove`, `Refactor`, `Docs`

### Key Principles
- Work directly on `main` branch (no feature branches needed for this private fork)
- Always push to `private` remote (not `origin`)
- Build and test before committing
- Update CHANGELOG.md for any user-visible changes
- Commit frequently with descriptive messages
