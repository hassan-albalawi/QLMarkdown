//
//  Settings+render.swift
//  QLMarkdown
//
//  Created by Sbarex on 06/05/25.
//

import Foundation
import OSLog
import SwiftSoup
import Yams

extension Settings {
    /// File extensions that should be rendered as markdown
    private static let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkd", "mkdn", "rmd", "qmd", "textbundle", "apib"]

    /// File extensions that should be rendered as HTML directly
    private static let htmlExtensions: Set<String> = ["html", "htm", "xhtml"]

    /// Map of file extensions to highlight language names
    private static let codeExtensionMap: [String: String] = [
        "js": "js", "mjs": "js", "cjs": "js",
        "jsx": "js", "tsx": "tsx", "ts": "ts",
        "py": "py", "pyw": "py", "pyi": "py",
        "swift": "swift",
        "c": "c", "h": "c",
        "cpp": "cpp", "cc": "cpp", "cxx": "cpp", "hpp": "cpp", "hxx": "cpp",
        "m": "objc", "mm": "objc",
        "java": "java",
        "go": "go",
        "rs": "rust",
        "rb": "rb", "rake": "rb",
        "php": "php",
        "pl": "pl", "pm": "pl",
        "sh": "sh", "bash": "sh", "zsh": "sh",
        "css": "css", "scss": "scss", "sass": "sass", "less": "less",
        "json": "json",
        "xml": "xml", "svg": "xml", "plist": "xml",
        "yaml": "yaml", "yml": "yaml",
        "sql": "sql",
        "r": "r",
        "lua": "lua",
        "hs": "hs",
        "ex": "elixir", "exs": "elixir",
        "erl": "erlang",
        "clj": "clj",
        "scala": "scala",
        "kt": "kotlin", "kts": "kotlin",
        "groovy": "groovy",
        "dart": "dart",
        "vue": "vue",
        "toml": "toml",
        "ini": "ini", "cfg": "ini",
        "dockerfile": "dockerfile",
        "makefile": "makefile", "mk": "makefile",
        "cmake": "cmake",
        "gradle": "gradle",
        "tf": "terraform",
        "proto": "protobuf",
        "graphql": "graphql", "gql": "graphql",
        "txt": "txt"
    ]

    /// Check if a file should be treated as markdown based on its extension
    private func isMarkdownFile(_ filename: String) -> Bool {
        let ext = (filename as NSString).pathExtension.lowercased()
        return Self.markdownExtensions.contains(ext) || ext.isEmpty
    }

    /// Check if a file should be rendered as HTML directly
    private func isHTMLFile(_ filename: String) -> Bool {
        let ext = (filename as NSString).pathExtension.lowercased()
        return Self.htmlExtensions.contains(ext)
    }

    /// Get the highlight language for a file extension
    private func getHighlightLanguage(for filename: String) -> String? {
        let ext = (filename as NSString).pathExtension.lowercased()
        return Self.codeExtensionMap[ext]
    }

    /// Render source code with syntax highlighting
    func renderSourceCode(text: String, language: String, forAppearance appearance: Appearance) -> String {
        if let path = getHighlightSupportPath() {
            cmark_syntax_highlight_init("\(path)/".cString(using: .utf8))
        }

        let theme = Self.isLightAppearance ? "acid" : "zenburn"

        highlight_init_generator()
        highlight_set_print_line_numbers(self.syntaxLineNumbersOption ? 1 : 0)
        highlight_set_formatting_mode(Int32(self.syntaxWordWrapOption), Int32(self.syntaxTabsOption))

        if !self.syntaxFontFamily.isEmpty {
            highlight_set_current_font(self.syntaxFontFamily, self.syntaxFontSize > 0 ? String(format: "%.02f", self.syntaxFontSize) : "1rem")
        } else {
            highlight_set_current_font("ui-monospace, -apple-system, BlinkMacSystemFont, sans-serif", "10")
        }

        // Generate complete CSS for syntax highlighting
        // Bypass highlight_format_style2 and use theme colors directly
        let isDark = !Self.isLightAppearance

        // Zenburn (dark) vs Acid (light) theme colors
        let bgColor = isDark ? "#1f1f1f" : "#eeeeee"
        let fgColor = isDark ? "#dcdccc" : "#000000"
        let numColor = isDark ? "#dca3a3" : "#800080"
        let strColor = isDark ? "#cc9393" : "#a68500"
        let comColor = isDark ? "#7f9f7f" : "#ff8000"
        let ppcColor = isDark ? "#ffcfaf" : "#0080c0"
        let kw1Color = isDark ? "#e3ceab" : "#bb7977"
        let kw2Color = isDark ? "#dfdfbf" : "#8080c0"
        let kw3Color = isDark ? "#aae3b2" : "#0080c0"
        let kw4Color = isDark ? "#aabfe3" : "#004466"
        let optColor = isDark ? "#dcdccc" : "#ff0080"
        let escColor = isDark ? "#dca3a3" : "#ff00ff"

        let preCSS = """
        <style type="text/css">
        pre.hl {
            white-space: pre;
            overflow-x: auto;
            margin: 0;
            padding: 1em;
            font-family: ui-monospace, Menlo, Monaco, "Courier New", monospace;
            font-size: 12px;
            line-height: 1.4;
            background-color: \(bgColor);
            color: \(fgColor);
        }
        .hl.num { color: \(numColor); }
        .hl.esc { color: \(escColor); }
        .hl.str { color: \(strColor); }
        .hl.pps { color: \(strColor); }
        .hl.slc { color: \(comColor); font-style: italic; }
        .hl.com { color: \(comColor); font-style: italic; }
        .hl.ppc { color: \(ppcColor); }
        .hl.opt { color: \(optColor); }
        .hl.ipl { color: \(escColor); }
        .hl.kwa { color: \(kw1Color); font-weight: bold; }
        .hl.kwb { color: \(kw2Color); font-weight: bold; }
        .hl.kwc { color: \(kw3Color); font-weight: bold; }
        .hl.kwd { color: \(kw4Color); font-weight: bold; }
        </style>
        """

        // colorizeCode with export_fragment=true doesn't add <pre> tags, so we must wrap it
        if let s = colorizeCode(text, language, theme, true, self.syntaxLineNumbersOption) {
            defer { s.deallocate() }
            let highlighted = String(cString: s)
            return preCSS + "<pre class='hl'>" + highlighted + "</pre>"
        }

        // Fallback: escape HTML and wrap in pre
        let escaped = text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        return preCSS + "<pre class='hl'><code>\(escaped)</code></pre>"
    }

    func render(text: String, filename: String, forAppearance appearance: Appearance, baseDir: String) throws -> String {
        // Check if file should be rendered as HTML directly
        if isHTMLFile(filename) {
            return text
        }

        // Check if file is source code (not markdown)
        if !isMarkdownFile(filename), let lang = getHighlightLanguage(for: filename) {
            return renderSourceCode(text: text, language: lang, forAppearance: appearance)
        }

        if self.renderAsCode, let code = self.renderCode(text: text, forAppearance: appearance, baseDir: baseDir) {
            return code
        }

        cmark_gfm_core_extensions_ensure_registered()
        cmark_gfm_extra_extensions_ensure_registered()
        
        var options = CMARK_OPT_DEFAULT
        if self.unsafeHTMLOption {
            options |= CMARK_OPT_UNSAFE
        }
        
        if self.hardBreakOption {
            options |= CMARK_OPT_HARDBREAKS
        }
        if self.noSoftBreakOption {
            options |= CMARK_OPT_NOBREAKS
        }
        if self.validateUTFOption {
            options |= CMARK_OPT_VALIDATE_UTF8
        }
        if self.smartQuotesOption {
            options |= CMARK_OPT_SMART
        }
        if self.footnotesOption {
            options |= CMARK_OPT_FOOTNOTES
        }
        
        if self.strikethroughExtension && self.strikethroughDoubleTildeOption {
            options |= CMARK_OPT_STRIKETHROUGH_DOUBLE_TILDE
        }
        
        os_log("cmark_gfm options: %{public}d.", log: OSLog.rendering, type: .debug, options)
        
        guard let parser = cmark_parser_new(options) else {
            os_log("Unable to create new cmark_parser!", log: OSLog.rendering, type: .error, options)
            throw CMARK_Error.parser_create
        }
        defer {
            cmark_parser_free(parser)
        }
        
        /*
        var extensions: UnsafeMutablePointer<cmark_llist>? = nil
        defer {
            cmark_llist_free(cmark_get_default_mem_allocator(), extensions)
        }
        */
        
        if self.tableExtension {
            if let ext = cmark_find_syntax_extension("table") {
                cmark_parser_attach_syntax_extension(parser, ext)
                os_log("Enabled markdown markdown `table` extension.", log: OSLog.rendering, type: .debug)
                // extensions = cmark_llist_append(cmark_get_default_mem_allocator(), nil, &ext)
            } else {
                os_log("Could not enable markdown `table` extension!", log: OSLog.rendering, type: .error)
            }
        }
        
        if self.autoLinkExtension {
            if let ext = cmark_find_syntax_extension("autolink") {
                cmark_parser_attach_syntax_extension(parser, ext)
                os_log("Enabled markdown `autolink` extension.", log: OSLog.rendering, type: .debug)
            } else {
                os_log("Could not enable markdown `autolink` extension!", log: OSLog.rendering, type: .error)
            }
        }
        
        if self.tagFilterExtension {
            if let ext = cmark_find_syntax_extension("tagfilter") {
                cmark_parser_attach_syntax_extension(parser, ext)
                os_log("Enabled markdown `tagfilter` extension.", log: OSLog.rendering, type: .debug)
            } else {
                os_log("Could not enable markdown `tagfilter` extension!", log: OSLog.rendering, type: .error)
            }
        }
        
        if self.taskListExtension {
            if let ext = cmark_find_syntax_extension("tasklist") {
                cmark_parser_attach_syntax_extension(parser, ext)
                os_log("Enabled markdown `tasklist` extension.",  log: OSLog.rendering, type: .debug)
            } else {
                os_log("Could not enable markdown `tasklist` extension!", log: OSLog.rendering, type: .error)
            }
        }
        
        var md_text = text
        
        var header = ""
        
        if self.yamlExtension && (self.yamlExtensionAll || filename.lowercased().hasSuffix("rmd") || filename.lowercased().hasSuffix("qmd")) && md_text.hasPrefix("---") {
            /*
             (?s): Turn on "dot matches newline" for the remainder of the regular expression. For “single line mode” makes the dot match all characters, including line breaks.
             (?<=---\n): Positive lookbehind. Matches at a position if the pattern inside the lookbehind can be matched ending at that position. Find expression .* where expression `---\n` precedes.
             (?>\n(?:---|\.\.\.):
             (?:---|\.\.\.): not capturing group
             */
            let pattern = "(?s)((?<=---\n).*?(?>\n(?:---|\\.\\.\\.)\n))"
            if let range = md_text.range(of: pattern, options: .regularExpression) {
                let yaml = String(md_text[range.lowerBound ..< md_text.index(range.upperBound, offsetBy: -4)])
                var isHTML = false
                header = self.renderYamlHeader(yaml, isHTML: &isHTML)
                if isHTML {
                    md_text = String(md_text[range.upperBound ..< md_text.endIndex])
                } else {
                    md_text = header + md_text[range.upperBound ..< md_text.endIndex]
                    header = ""
                }
            }
        }
        
        if self.strikethroughExtension {
            if let ext = cmark_find_syntax_extension("strikethrough") {
                cmark_parser_attach_syntax_extension(parser, ext)
                os_log("Enabled markdown `strikethrough` extension.", log: OSLog.rendering, type: .debug)
            } else {
                os_log("Could not enable markdown `strikethrough` extension!", log: OSLog.rendering, type: .error)
            }
        }
        
        if self.mentionExtension {
            if let ext = cmark_find_syntax_extension("mention") {
                cmark_parser_attach_syntax_extension(parser, ext)
                os_log("Enabled markdown `mention` extension.", log: OSLog.rendering, type: .debug)
            } else {
                os_log("Could not enable markdown `mention` extension!", log: OSLog.rendering, type: .error)
            }
        }
        
        if self.headsExtension {
            if let ext = cmark_find_syntax_extension("heads") {
                cmark_parser_attach_syntax_extension(parser, ext)
                os_log("Enabled markdown `heads` extension.", log: OSLog.rendering, type: .debug)
            } else {
                os_log("Could not enable markdown `heads` extension!", log: OSLog.rendering, type: .error)
            }
        }
        
        if self.highlightExtension {
            if let ext = cmark_find_syntax_extension("highlight") {
                cmark_parser_attach_syntax_extension(parser, ext)
                
                os_log(
                    "Enabled markdown `highlight` extension.",
                    log: OSLog.rendering,
                    type: .debug)
            } else {
                os_log("Could not enable markdown `highlight` extension!", log: OSLog.rendering, type: .error)
            }
        }
        
        
        if self.subExtension {
            if let ext = cmark_find_syntax_extension("sub") {
                cmark_parser_attach_syntax_extension(parser, ext)
                
                os_log(
                    "Enabled markdown `sub` extension.",
                    log: OSLog.rendering,
                    type: .debug)
            } else {
                os_log("Could not enable markdown `sub` extension!", log: OSLog.rendering, type: .error)
            }
        }
        
        if self.supExtension {
            if let ext = cmark_find_syntax_extension("sup") {
                cmark_parser_attach_syntax_extension(parser, ext)
                
                os_log(
                    "Enabled markdown `sup` extension.",
                    log: OSLog.rendering,
                    type: .debug)
            } else {
                os_log("Could not enable markdown `sup` extension!", log: OSLog.rendering, type: .error)
            }
        }
        
        if self.inlineImageExtension {
            if let ext = cmark_find_syntax_extension("inlineimage") {
                cmark_parser_attach_syntax_extension(parser, ext)
                cmark_syntax_extension_inlineimage_set_wd(ext, baseDir.cString(using: .utf8))
                cmark_syntax_extension_inlineimage_set_mime_callback(ext, { (path, context) in
                    let magic_file = Settings.getResourceBundle().path(forResource: "magic", ofType: "mgc")?.cString(using: .utf8)
                    let r = magic_get_mime_by_file(path, magic_file)
                    return r
                }, nil)
                /*
                cmark_syntax_extension_inlineimage_set_remote_data_callback(ext, { (url, context) -> UnsafeMutablePointer<Int8>? in
                    guard let uu = url, let u = URL(string: String(cString: uu)) else {
                        return nil
                    }
                    do {
                        let data = try Data(contentsOf: u)
                    } catch {
                        os_log("Error fetch data from %{public}@: %{public}@", log: OSLog.rendering, type: .error, String(cString: uu), error.localizedDescription)
                        return nil
                    }
                    return nil
                }, nil)
                */
                
                os_log("Enabled markdown `local inline image` extension with working path set to `%{public}s`.", log: OSLog.rendering, type: .debug, baseDir)
                
                if self.unsafeHTMLOption {
                    cmark_syntax_extension_inlineimage_set_unsafe_html_processor_callback(ext, { (ext, fragment, workingDir, context, code) in
                        guard let fragment = fragment else {
                            return
                        }
                        
                        let baseDir: URL
                        if let s = workingDir {
                            let b = String(cString: s)
                            baseDir = URL(fileURLWithPath: b)
                        } else {
                            baseDir = URL(fileURLWithPath: "")
                        }
                        let html = String(cString: fragment)
                        var changed = false
                        do {
                            let doc = try SwiftSoup.parseBodyFragment(html, baseDir.path)
                            for img in try doc.select("img") {
                                let src = try img.attr("src")
                                
                                guard !src.isEmpty, !src.hasPrefix("http"), !src.hasPrefix("HTTP") else {
                                    // Do not handle external image.
                                    continue
                                }
                                guard !src.hasPrefix("data:") else {
                                    // Do not reprocess data: image.
                                    continue
                                }
                                
                                let file = baseDir.appendingPathComponent(src).path
                                guard FileManager.default.fileExists(atPath: file) else {
                                    os_log("Image %{private}@ not found!", log: OSLog.rendering, type: .error)
                                    continue // File not found.
                                }
                                guard let data = get_base64_image(
                                    file.cString(using: .utf8),
                                    { (path: UnsafePointer<Int8>?, context: UnsafeMutableRawPointer?) -> UnsafeMutablePointer<Int8>? in
                                        let magic_file = Settings.getResourceBundle().path(forResource: "magic", ofType: "mgc")?.cString(using: .utf8)
                                        
                                        let r = magic_get_mime_by_file(path, magic_file)
                                        return r
                                    },
                                    nil,
                                    /*{ (url, _ )->UnsafeMutablePointer<Int8>? in
                                        guard let s = url else {
                                            return nil
                                        }
                                        let u = URL(fileURLWithPath: String(cString: s))
                                        guard let data = try? Data(contentsOf: u) else {
                                            return nil
                                        }
                                        return nil
                                    }*/ nil,
                                    nil
                                ) else {
                                    continue
                                }
                                defer {
                                    data.deallocate()
                                }
                                let img_data = String(cString: data)
                                try img.attr("src", img_data)
                                changed = true
                            }
                            if changed, let html = try doc.body()?.html(), let s = strdup(html) {
                                code?.pointee = UnsafePointer(s)
                            }
                        } catch Exception.Error(_, let message) {
                            os_log("Error processing html: %{public}@!", log: OSLog.rendering, type: .error, message)
                        } catch {
                            os_log("Error parsing html: %{public}@!", log: OSLog.rendering, type: .error, error.localizedDescription)
                        }
                    }, nil)
                }
            } else {
                os_log("Could not enable markdown `local inline image` extension!", log: OSLog.rendering, type: .error)
            }
        }
        
        if self.emojiExtension {
            if let ext = cmark_find_syntax_extension("emoji") {
                cmark_syntax_extension_emoji_set_use_characters(ext, !self.emojiImageOption)
                cmark_parser_attach_syntax_extension(parser, ext)
                os_log("Enabled markdown `emoji` extension using %{public}s.", log: OSLog.rendering, type: .debug, self.emojiImageOption ? "images" : "glyphs")
            } else {
                os_log("Could not enable markdown `emoji` extension!", log: OSLog.rendering, type: .error)
            }
        }
        
        if self.mathExtension {
            if let ext = cmark_find_syntax_extension("math") {
                cmark_parser_attach_syntax_extension(parser, ext)
                
                os_log(
                    "Enabled markdown `math` extension.",
                    log: OSLog.rendering,
                    type: .debug)
            } else {
                os_log("Could not enable markdown `math` extension!", log: OSLog.rendering, type: .error)
            }
        }
        
        if self.syntaxHighlightExtension {
            if let ext = cmark_find_syntax_extension("syntaxhighlight") {
                if let path = getHighlightSupportPath() {
                    cmark_syntax_highlight_init("\(path)/".cString(using: .utf8))
                } else {
                    os_log("Unable to found the `highlight` support dir!", log: OSLog.rendering, type: .error)
                }
                
                cmark_syntax_extension_highlight_set_theme_name(ext, "")
                cmark_syntax_extension_highlight_set_background_color(ext, nil /* "var(--hl_Background)" */)
                cmark_syntax_extension_highlight_set_line_number(ext, self.syntaxLineNumbersOption ? 1 : 0)
                cmark_syntax_extension_highlight_set_tab_spaces(ext, Int32(self.syntaxTabsOption))
                cmark_syntax_extension_highlight_set_wrap_limit(ext, Int32(self.syntaxWordWrapOption))
                cmark_syntax_extension_highlight_set_guess_language(ext, guess_type(UInt32(self.guessEngine.rawValue)))
                if self.guessEngine == .simple, let f = self.resourceBundle.path(forResource: "magic", ofType: "mgc") {
                    cmark_syntax_extension_highlight_set_magic_file(ext, f)
                }
                
                if !self.syntaxFontFamily.isEmpty {
                    cmark_syntax_extension_highlight_set_font_family(ext, self.syntaxFontFamily, Float(self.syntaxFontSize))
                } else {
                    // cmark_syntax_extension_highlight_set_font_family(ext, "-apple-system, BlinkMacSystemFont, sans-serif", 0.0)
                    // Pass a fake value, so will be used the font defined inside the main css file.
                    cmark_syntax_extension_highlight_set_font_family(ext, "-", 0.0)
                }
                
                cmark_parser_attach_syntax_extension(parser, ext)
                
                os_log(
                    "Enabled markdown `syntax highlight` extension.",
                    log: OSLog.rendering,
                    type: .debug)
            } else {
                os_log("Could not enable markdown `syntax highlight` extension!", log: OSLog.rendering, type: .error)
            }
        }
        
        // Extract mermaid blocks BEFORE cmark processing to preserve newlines
        // The syntaxhighlight extension can corrupt mermaid content
        var mermaidBlocks: [String: String] = [:]
        var processedText = md_text
        if self.mermaidExtension {
            (processedText, mermaidBlocks) = extractMermaidBlocks(md_text)
        }

        cmark_parser_feed(parser, processedText, strlen(processedText))
        guard let doc = cmark_parser_finish(parser) else {
            throw CMARK_Error.parser_parse
        }
        defer {
            cmark_node_free(doc)
        }

        // Footer removed - preview should only show file content
        let about = ""

        let html_debug = self.renderDebugInfo(forAppearance: appearance, baseDir: baseDir)
        // Render
        if let html2 = cmark_render_html(doc, options, cmark_parser_get_syntax_extensions(parser)) {
            defer {
                free(html2)
            }

            var renderedHtml = String(cString: html2)

            // Restore mermaid blocks with original content (preserving newlines)
            if self.mermaidExtension && !mermaidBlocks.isEmpty {
                renderedHtml = restoreMermaidBlocks(renderedHtml, blocks: mermaidBlocks)
            }

            return html_debug + header + renderedHtml + about
        } else {
            return html_debug + "<p>RENDER FAILED!</p>"
        }
    }
    
    internal func renderDebugInfo(forAppearance appearance: Appearance, baseDir: String) -> String
    {
        guard debug else {
            return ""
        }
        var html_debug = ""
        html_debug += """
<style type="text/css">
table.debug td {
    vertical-align: top;
    font-size: .8rem;
}
</style>
"""
        html_debug += "<table class='debug'>\n<caption>Debug info</caption>"
        var html_options = ""
        if self.unsafeHTMLOption || (self.emojiExtension && self.emojiImageOption) {
            html_options += "CMARK_OPT_UNSAFE "
        }
        
        if self.hardBreakOption {
            html_options += "CMARK_OPT_HARDBREAKS "
        }
        if self.noSoftBreakOption {
            html_options += "CMARK_OPT_NOBREAKS "
        }
        if self.validateUTFOption {
            html_options += "CMARK_OPT_VALIDATE_UTF8 "
        }
        if self.smartQuotesOption {
            html_options += "CMARK_OPT_SMART "
        }
        if self.footnotesOption {
            html_options += "CMARK_OPT_FOOTNOTES "
        }
        
        if self.strikethroughExtension && self.strikethroughDoubleTildeOption {
            html_options += "CMARK_OPT_STRIKETHROUGH_DOUBLE_TILDE "
        }

        html_debug += "<tr><td>options</td><td>\(html_options)</td></tr>\n"
        
        html_debug += "<tr><td>autolink extension</td><td>"
        if self.autoLinkExtension {
            html_debug += "on " + (cmark_find_syntax_extension("autolink") == nil ? " (NOT AVAILABLE" : "")
        } else {
            html_debug += "off"
        }
        html_debug += "</td></tr>\n"
        
        html_debug += "<tr><td>emoji extension</td><td>"
        if self.emojiExtension {
            html_debug += "on" + (cmark_find_syntax_extension("emoji") == nil ? " (NOT AVAILABLE" : "")
            html_debug += " / \(self.emojiImageOption ? "using images" : "using emoji")"
        } else {
            html_debug += "off"
        }
        html_debug += "</td></tr>\n"
        
        html_debug += "<tr><td>heads extension</td><td>" + (self.headsExtension ?  "on" : "off") + "</td></tr>\n"
        
        html_debug += "<tr><td>highlight extension</td><td>"
        if self.highlightExtension {
            html_debug += "on " + (cmark_find_syntax_extension("highlight") == nil ? " (NOT AVAILABLE" : "")
        } else {
            html_debug += "off"
        }
        html_debug += "</td></tr>\n"
        
        html_debug += "<tr><td>inlineimage extension</td><td>"
        if self.inlineImageExtension {
            html_debug += "on" + (cmark_find_syntax_extension("inlineimage") == nil ? " (NOT AVAILABLE" : "")
            html_debug += "<br />basedir: \(baseDir)"
        } else {
            html_debug += "off"
        }
        html_debug += "</td></tr>\n"
        
        html_debug += "<tr><td>math extension</td><td>"
        if self.mathExtension {
            html_debug += "on " + (cmark_find_syntax_extension("math") == nil ? " (NOT AVAILABLE" : "")
        } else {
            html_debug += "off"
        }
        html_debug += "</td></tr>\n"

        html_debug += "<tr><td>mermaid extension</td><td>"
        if self.mermaidExtension {
            html_debug += "on"
            if self.resourceBundle.path(forResource: "mermaid.min", ofType: "js") == nil {
                html_debug += " (mermaid.min.js NOT FOUND)"
            }
        } else {
            html_debug += "off"
        }
        html_debug += "</td></tr>\n"

        html_debug += "<tr><td>mention extension</td><td>"
        if self.mentionExtension {
            html_debug += "on " + (cmark_find_syntax_extension("mention") == nil ? " (NOT AVAILABLE" : "")
        } else {
            html_debug += "off"
        }
        html_debug += "</td></tr>\n"
        
        html_debug += "<tr><td>strikethrough extension</td><td>"
        if self.strikethroughExtension {
            html_debug += "on " + (cmark_find_syntax_extension("strikethrough") == nil ? " (NOT AVAILABLE" : "")
        } else {
            html_debug += "off"
        }
        html_debug += "</td></tr>\n"
        
        html_debug += "<tr><td>syntax highlighting extension</td><td>"
        if self.syntaxHighlightExtension {
            html_debug += "on " + (cmark_find_syntax_extension("syntaxhighlight") == nil ? " (NOT AVAILABLE" : "")
            
            html_debug += "<table>\n"
            html_debug += "<tr><td>datadir</td><td>\(getHighlightSupportPath() ?? "missing")</td></tr>\n"
            html_debug += "<tr><td>line numbers</td><td>\(self.syntaxLineNumbersOption ? "on" : "off")</td></tr>\n"
            html_debug += "<tr><td>spaces for a tab</td><td>\(self.syntaxTabsOption)</td></tr>\n"
            html_debug += "<tr><td>wrap</td><td> \(self.syntaxWordWrapOption > 0 ? "after \(self.syntaxWordWrapOption) characters" : "disabled")</td></tr>\n"
            html_debug += "<tr><td>spaces for a tab</td><td>\(self.syntaxTabsOption)</td></tr>\n"
            html_debug += "<tr><td>guess language</td><td>"
            switch self.guessEngine {
            case .none:
                html_debug += "off"
            case .simple:
                html_debug += "simple<br />"
                html_debug += "magic db: \(self.resourceBundle.path(forResource: "magic", ofType: "mgc") ?? "missing")"
            case .accurate:
                html_debug += "accurate"
            }
            html_debug += "</td></tr>\n"
            html_debug += "<tr><td>font family</td><td>\(self.syntaxFontFamily.isEmpty ? "not set" : self.syntaxFontFamily)</td></tr>\n"
            html_debug += "<tr><td>font size</td><td>\(self.syntaxFontSize > 0 ? "\(self.syntaxFontSize)" : "not set")</td></tr>\n"
            html_debug += "</table>\n"
        } else {
            html_debug += "off"
        }
        html_debug += "</td></tr>\n"
        
        html_debug += "<tr><td>sub extension</td><td>"
        if self.subExtension {
            html_debug += "on " + (cmark_find_syntax_extension("sub") == nil ? " (NOT AVAILABLE" : "")
        } else {
            html_debug += "off"
        }
        html_debug += "</td></tr>\n"
        html_debug += "<tr><td>sup extension</td><td>"
        if self.supExtension {
            html_debug += "on " + (cmark_find_syntax_extension("sup") == nil ? " (NOT AVAILABLE" : "")
        } else {
            html_debug += "off"
        }
        html_debug += "</td></tr>\n"
        
        html_debug += "<tr><td>table extension</td><td>"
        if self.tableExtension {
            html_debug += "on " + (cmark_find_syntax_extension("table") == nil ? " (NOT AVAILABLE" : "")
        } else {
            html_debug += "off"
        }
        html_debug += "</td></tr>\n"
        
        html_debug += "<tr><td>tagfilter extension</td><td>"
        if self.tagFilterExtension {
            html_debug += "on " + (cmark_find_syntax_extension("tagfilter") == nil ? " (NOT AVAILABLE" : "")
        } else {
            html_debug += "off"
        }
        html_debug += "</td></tr>\n"

        html_debug += "<tr><td>tasklist extension</td><td>"
        if self.taskListExtension {
            html_debug += "on " + (cmark_find_syntax_extension("tasklist") == nil ? " (NOT AVAILABLE" : "")
        } else {
            html_debug += "off"
        }
        html_debug += "</td></tr>\n"
        
        html_debug += "<tr><td>YAML extension</td><td>"
        if self.yamlExtension {
            html_debug += "on "+(self.yamlExtensionAll ? "for all files" : "only for .rmd and .qmd files")
        } else {
            html_debug += "off"
        }
        html_debug += "</td></tr>\n"
        
        html_debug += "<tr><td>link</td><td>" + (self.openInlineLink ? "open inline" : "open in standard browser") + "</td></tr>\n"
        
        html_debug += "</table>\n"
        
        return html_debug
    }
    
    func renderCode(text: String, forAppearance appearance: Appearance, baseDir: String) -> String? {
        if let path = getHighlightSupportPath() {
            cmark_syntax_highlight_init("\(path)/".cString(using: .utf8))
        } else {
            os_log("Unable to found the `highlight` support dir!", log: OSLog.rendering, type: .error)
        }
        
        let theme = Self.isLightAppearance ? "acid" : "zenburn"
        
        // Initialize a new generator and clear previous settings.
        highlight_init_generator()
        
        highlight_set_print_line_numbers(self.syntaxLineNumbersOption ? 1 : 0)
        highlight_set_formatting_mode(Int32(self.syntaxWordWrapOption), Int32(self.syntaxTabsOption))
        
        if !self.syntaxFontFamily.isEmpty {
            highlight_set_current_font(self.syntaxFontFamily, self.syntaxFontSize > 0 ? String(format: "%.02f", self.syntaxFontSize) : "1rem") // 1rem is rendered as 1rempt, so it is ignored.
        } else {
            highlight_set_current_font("ui-monospace, -apple-system, BlinkMacSystemFont, sans-serif", "10");
        }
        
        if let s = colorizeCode(text, "md", theme, true, self.syntaxLineNumbersOption) {
            defer {
                s.deallocate()
            }
            let code = String(cString: s)
            return code
        } else {
            return nil
        }
    }
    
    func render(file url: URL, forAppearance appearance: Appearance, baseDir: String?) throws -> String {
        guard let data = FileManager.default.contents(atPath: url.path) else {
            os_log("Unable to read the file %{private}@", log: OSLog.rendering, type: .error, url.path)
            return ""
        }
        
        return try self.render(data: data, forAppearance: appearance, filename: url.lastPathComponent, baseDir: baseDir ?? url.deletingLastPathComponent().path)
    }
    
    func render(data: Data, forAppearance appearance: Appearance, filename: String = "file.md", baseDir: String) throws -> String {
        guard let markdown_string = String(data: data, encoding: .utf8) else {
            os_log("Unable to read the data %{private}@", log: OSLog.rendering, type: .error, data.base64EncodedString())
            return ""
        }
        
        return try self.render(text: markdown_string, filename: filename, forAppearance: appearance, baseDir: baseDir)
    }
    
    func getCompleteHTML(title: String, body: String, header: String = "", footer: String = "", basedir: URL, forAppearance appearance: Appearance) -> String {
        
        let css_doc: String
        let css_doc_extended: String
        
        var s_header = header
        var s_footer = footer
        
        let formatCSS = { (code: String?) -> String in
            guard let css = code, !css.isEmpty else {
                return ""
            }
            return "<style type='text/css'>\(css)\n</style>\n"
        }
            
        if !self.renderAsCode {
            let css = (self.customCSSFetched ? self.customCSSCode : self.getCustomCSSCode()) ?? ""
            if !css.isEmpty {
                css_doc_extended = formatCSS(css)
                if !self.customCSSOverride {
                    css_doc = formatCSS(getBundleContents(forResource: "default", ofType: "css"))
                } else {
                    css_doc = ""
                }
            } else {
                css_doc_extended = ""
                css_doc = formatCSS(getBundleContents(forResource: "default", ofType: "css"))
            }
            // css_doc = "<style type=\"text/css\">\n\(css_doc)\n</style>\n"
        } else {
            css_doc_extended = ""
            css_doc = ""
        }
            
        var css_highlight: String = ""
        if self.renderAsCode {
            var exit_code: Int32 = 0
            
            exit_code = 0
            let p = highlight_format_style2(&exit_code, nil)
            defer {
                p?.deallocate()
            }
            css_highlight += "pre.hl { white-space: pre; }\n"
            if exit_code == EXIT_SUCCESS, let p = p {
                css_highlight = String(cString: p) + "\n"
            }
        } else if self.syntaxHighlightExtension, let ext = cmark_find_syntax_extension("syntaxhighlight"), cmark_syntax_extension_highlight_get_rendered_count(ext) > 0 {
            let theme = ""
            if !theme.isEmpty, let p = cmark_syntax_extension_get_style(ext) {
                // Embed the theme style.
                css_highlight = String(cString: p)
                p.deallocate()
            } else {
                if let s = cmark_syntax_extension_highlight_get_background_color(ext) {
                    let background_color = String(cString: s)
                    if background_color != "ignore" && !background_color.isEmpty {
                        css_highlight += "body.hl, pre.hl { background-color: \(background_color); }\n"
                    }
                }
            }
            if let s = cmark_syntax_extension_highlight_get_font_family(ext) {
                let font_name = String(cString: s)
                if !font_name.isEmpty && font_name != "-" {
                    let font = "\"\(font_name)\", ui-monospace, -apple-system, Menlo, monospace"
                    css_highlight += "body.hl, pre.hl, pre.hl code { font-family: \(font); }\n"
                }
            }
            let size = cmark_syntax_extension_highlight_get_font_size(ext)
            if size > 0 {
                css_highlight += "body.hl, pre.hl, pre.hl code { font-size: \(size)pt; }\n"
            }
        }
        css_highlight = formatCSS(css_highlight)
        
        if !self.renderAsCode, self.mathExtension, let ext = cmark_find_syntax_extension("math"), cmark_syntax_extension_math_get_rendered_count(ext) > 0 || body.contains("$") {
            s_header += """
<script type="text/javascript">
MathJax = {
  options: {
    enableMenu: \(self.debug ? "true" : "false"),
  },
  tex: {
    // packages: ['base'],        // extensions to use
    inlineMath: [              // start/end delimiter pairs for in-line math
      ['$', '$']
      // , ['\\(', '\\)']
    ],
    displayMath: [             // start/end delimiter pairs for display math
      ['$$', '$$']
      //, ['\\[', '\\]']
    ],
    processEscapes: true,       // use \\$ to produce a literal dollar sign
    processEnvironments: false
  }
};
</script>
"""
            s_footer += """
<script type="text/javascript" id="MathJax-script" async
  src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js">
</script>
"""
        }

        // Mermaid diagrams support
        // Mermaid blocks are now pre-processed in render() to preserve newlines
        // Check for pre.mermaid elements (from pre-processing) or language-mermaid (legacy)
        var processedBody = body
        let hasMermaid = body.contains("class=\"mermaid\"") || body.contains("language-mermaid")
        if !self.renderAsCode, self.mermaidExtension, hasMermaid {
            // If there are still language-mermaid blocks (shouldn't happen with new flow),
            // transform them as fallback
            if body.contains("language-mermaid") {
                processedBody = transformMermaidBlocks(body)
            }

            // Inject mermaid.min.js from bundle
            if let mermaidPath = self.resourceBundle.path(forResource: "mermaid.min", ofType: "js"),
               let mermaidJS = try? String(contentsOfFile: mermaidPath, encoding: .utf8) {
                // Embed mermaid.js inline
                s_footer += "<script type=\"text/javascript\">\n\(mermaidJS)\n</script>\n"
                s_footer += """
<style type="text/css">
/* Reset pre styling for mermaid elements - they render as SVG */
pre.mermaid {
  background: transparent;
  border: none;
  padding: 0;
  margin: 0;
  font-family: inherit;
  white-space: pre;
  overflow: visible;
}
.mermaid { cursor: zoom-in; transition: opacity 0.2s; }
.mermaid:hover { opacity: 0.85; }
.mermaid-overlay {
  display: none;
  position: fixed;
  top: 0; left: 0; right: 0; bottom: 0;
  background: rgba(0,0,0,0.92);
  z-index: 9999;
  overflow: auto;
  justify-content: center;
  align-items: center;
}
.mermaid-overlay.active { display: flex; }
.mermaid-svg-container {
  display: flex;
  justify-content: center;
  align-items: center;
  width: 100%;
  height: 100%;
  overflow: hidden;
}
.mermaid-svg-container svg {
  max-width: 95vw;
  max-height: 90vh;
  transform-origin: center center;
}
/* Enable text selection in zoomed SVG */
.mermaid-svg-container svg text,
.mermaid-svg-container svg tspan,
.mermaid-svg-container svg foreignObject {
  cursor: text !important;
  user-select: text !important;
  -webkit-user-select: text !important;
  pointer-events: auto !important;
}
.mermaid-svg-container.selecting {
  cursor: text !important;
}
.mermaid-svg-container.selecting svg {
  cursor: text !important;
}
.mermaid-zoom-controls {
  position: fixed;
  bottom: 20px;
  left: 50%;
  transform: translateX(-50%);
  display: flex;
  gap: 12px;
  z-index: 10000;
  background: rgba(255,255,255,0.1);
  padding: 8px 16px;
  border-radius: 24px;
  backdrop-filter: blur(10px);
}
.mermaid-zoom-btn {
  width: 36px; height: 36px;
  border-radius: 50%;
  background: rgba(255,255,255,0.9);
  border: none;
  font-size: 18px;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: transform 0.1s, background 0.1s;
}
.mermaid-zoom-btn:hover { background: #fff; transform: scale(1.1); }
.mermaid-zoom-btn:active { transform: scale(0.95); }
.mermaid-close-hint {
  position: fixed;
  top: 20px;
  left: 50%;
  transform: translateX(-50%);
  color: rgba(255,255,255,0.6);
  font-size: 13px;
  font-family: -apple-system, sans-serif;
}
</style>
<script type="text/javascript">
console.log('Mermaid version:', mermaid.version);
console.log('Mermaid diagrams:', Object.keys(mermaid.diagrams || {}));

mermaid.initialize({
  startOnLoad: true,
  theme: window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'default',
  securityLevel: 'loose',
  logLevel: 'debug'
});

// Debug: log mermaid div contents with full detail
document.querySelectorAll('.mermaid').forEach((el, i) => {
  console.log('Mermaid block ' + i + ' innerHTML:', el.innerHTML.substring(0, 300));
  console.log('Mermaid block ' + i + ' textContent:', el.textContent.substring(0, 300));
  // Check for newlines
  console.log('Has newlines:', el.textContent.includes('\\n'), 'Has actual newlines:', /[\\r\\n]/.test(el.textContent));
});

// Mermaid fullscreen and zoom functionality
(function() {
  // Create overlay
  const overlay = document.createElement('div');
  overlay.className = 'mermaid-overlay';
  overlay.innerHTML = `
    <div class="mermaid-close-hint">Select text to copy • Double-click to zoom • Hold Space+drag to pan • Esc to close</div>
    <div class="mermaid-svg-container" id="mermaid-svg-container"></div>
    <div class="mermaid-zoom-controls">
      <button class="mermaid-zoom-btn" id="mermaid-zoom-out" title="Zoom out (⌘-)">−</button>
      <button class="mermaid-zoom-btn" id="mermaid-zoom-reset" title="Reset zoom (⌘0)">⟲</button>
      <button class="mermaid-zoom-btn" id="mermaid-zoom-in" title="Zoom in (⌘+)">+</button>
    </div>
  `;
  document.body.appendChild(overlay);

  const svgContainer = document.getElementById('mermaid-svg-container');
  let currentZoom = 1;
  let currentSvg = null;
  let originalViewBox = null;
  let panX = 0, panY = 0;
  let isDragging = false;
  let dragStartX = 0, dragStartY = 0;
  let dragStartPanX = 0, dragStartPanY = 0;
  let spaceHeld = false; // Track spacebar for pan mode

  // Wait for mermaid to render, then add click handlers
  setTimeout(function() {
    document.querySelectorAll('.mermaid').forEach(function(el) {
      el.addEventListener('click', function() {
        const svg = el.querySelector('svg');
        if (svg) {
          currentSvg = svg.cloneNode(true);
          // Store original viewBox for proper zoom
          originalViewBox = currentSvg.getAttribute('viewBox');
          if (!originalViewBox) {
            // Create viewBox from dimensions if not present
            const w = currentSvg.getAttribute('width') || currentSvg.getBoundingClientRect().width;
            const h = currentSvg.getAttribute('height') || currentSvg.getBoundingClientRect().height;
            originalViewBox = '0 0 ' + parseFloat(w) + ' ' + parseFloat(h);
          }
          currentZoom = 1;
          panX = 0; panY = 0;
          svgContainer.innerHTML = '';
          svgContainer.appendChild(currentSvg);
          // Make SVG fill container and be responsive
          currentSvg.style.width = '100%';
          currentSvg.style.height = 'auto';
          currentSvg.style.maxWidth = '95vw';
          currentSvg.style.maxHeight = '90vh';
          applyViewBoxZoom();
          overlay.classList.add('active');
          document.body.style.overflow = 'hidden';
          svgContainer.classList.add('selecting');
        }
      });
    });
  }, 500);

  // Click overlay background to close (but not when dragging)
  overlay.addEventListener('click', function(e) {
    if (e.target === overlay && !isDragging) {
      closeOverlay();
    }
  });

  function closeOverlay() {
    overlay.classList.remove('active');
    document.body.style.overflow = '';
    svgContainer.innerHTML = '';
    svgContainer.classList.remove('selecting');
    currentSvg = null;
    originalViewBox = null;
    currentZoom = 1;
    panX = 0; panY = 0;
  }

  function zoomBy(factor) {
    const newZoom = Math.min(Math.max(currentZoom * factor, 0.25), 8);
    currentZoom = newZoom;
    // Reset pan if zooming out to 1x or less
    if (currentZoom <= 1) { panX = 0; panY = 0; }
    applyViewBoxZoom();
  }

  function zoomReset() {
    currentZoom = 1;
    panX = 0; panY = 0;
    applyViewBoxZoom();
  }

  function toggleZoom() {
    if (currentZoom < 1.5) {
      currentZoom = 2;
    } else {
      currentZoom = 1;
      panX = 0; panY = 0;
    }
    applyViewBoxZoom();
  }

  // Use viewBox manipulation for true vector zoom (text stays crisp)
  function applyViewBoxZoom() {
    if (currentSvg && originalViewBox) {
      const parts = originalViewBox.split(/\\s+/).map(parseFloat);
      const origW = parts[2], origH = parts[3];
      const newW = origW / currentZoom;
      const newH = origH / currentZoom;
      // Pan offset relative to original size
      const offsetX = (origW - newW) / 2 - (panX / currentZoom);
      const offsetY = (origH - newH) / 2 - (panY / currentZoom);
      currentSvg.setAttribute('viewBox', offsetX + ' ' + offsetY + ' ' + newW + ' ' + newH);
      // Update cursor based on mode
      updateCursor();
    }
  }

  function updateCursor() {
    if (spaceHeld) {
      svgContainer.style.cursor = isDragging ? 'grabbing' : 'grab';
      svgContainer.classList.remove('selecting');
    } else {
      svgContainer.style.cursor = 'default';
      svgContainer.classList.add('selecting');
    }
  }

  // Pan/drag - only when holding spacebar (like design apps)
  svgContainer.addEventListener('mousedown', function(e) {
    if (spaceHeld && currentZoom > 1) {
      isDragging = true;
      dragStartX = e.clientX;
      dragStartY = e.clientY;
      dragStartPanX = panX;
      dragStartPanY = panY;
      e.preventDefault();
      updateCursor();
    }
    // Otherwise allow normal text selection
  });

  document.addEventListener('mousemove', function(e) {
    if (isDragging && currentSvg) {
      panX = dragStartPanX + (e.clientX - dragStartX);
      panY = dragStartPanY + (e.clientY - dragStartY);
      applyViewBoxZoom();
    }
  });

  document.addEventListener('mouseup', function() {
    if (isDragging) {
      isDragging = false;
      updateCursor();
    }
  });

  // Zoom controls
  document.getElementById('mermaid-zoom-in').addEventListener('click', function(e) {
    e.stopPropagation();
    zoomBy(1.25);
  });
  document.getElementById('mermaid-zoom-out').addEventListener('click', function(e) {
    e.stopPropagation();
    zoomBy(0.8);
  });
  document.getElementById('mermaid-zoom-reset').addEventListener('click', function(e) {
    e.stopPropagation();
    zoomReset();
  });

  // Double-click to toggle zoom
  let lastClickTime = 0;
  svgContainer.addEventListener('dblclick', function(e) {
    e.preventDefault();
    toggleZoom();
  });

  // Keyboard shortcuts (with Cmd key for zoom, like macOS)
  document.addEventListener('keydown', function(e) {
    if (!overlay.classList.contains('active')) return;
    if (e.key === 'Escape') closeOverlay();
    // Spacebar to enable pan mode (like Photoshop/Figma)
    if (e.key === ' ' && !e.repeat) {
      e.preventDefault();
      spaceHeld = true;
      updateCursor();
    }
    // Cmd+Plus / Cmd+Equals to zoom in
    if ((e.metaKey || e.ctrlKey) && (e.key === '+' || e.key === '=')) {
      e.preventDefault();
      zoomBy(1.25);
    }
    // Cmd+Minus to zoom out
    if ((e.metaKey || e.ctrlKey) && (e.key === '-' || e.key === '_')) {
      e.preventDefault();
      zoomBy(0.8);
    }
    // Cmd+0 to reset zoom
    if ((e.metaKey || e.ctrlKey) && e.key === '0') {
      e.preventDefault();
      zoomReset();
    }
  });

  document.addEventListener('keyup', function(e) {
    if (e.key === ' ') {
      spaceHeld = false;
      isDragging = false;
      updateCursor();
    }
  });

  // Pinch-to-zoom (trackpad) and Cmd+scroll (mouse wheel)
  // On macOS, pinch gestures send wheel events with ctrlKey=true
  overlay.addEventListener('wheel', function(e) {
    if (!overlay.classList.contains('active')) return;

    // Pinch gesture (ctrlKey) or Cmd+scroll (metaKey)
    if (e.ctrlKey || e.metaKey) {
      e.preventDefault();
      // Use deltaY for smooth continuous zoom
      // Smaller factor for smoother pinch zoom
      const factor = e.ctrlKey ?
        Math.pow(1.01, -e.deltaY) :  // Pinch: very smooth
        (e.deltaY < 0 ? 1.1 : 0.9);   // Cmd+scroll: step zoom
      zoomBy(factor);
    }
    // Regular scroll without modifiers does nothing (natural behavior)
  }, { passive: false });
})();
</script>
"""
            } else {
                os_log("Could not load mermaid.min.js from bundle", log: OSLog.rendering, type: .error)
            }
        }

        // Search/find bar functionality for preview
        s_header += """
<style type="text/css">
.search-bar {
  display: none;
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  background: rgba(50, 50, 50, 0.95);
  padding: 8px 12px;
  z-index: 10001;
  box-shadow: 0 2px 8px rgba(0,0,0,0.3);
  backdrop-filter: blur(10px);
  -webkit-backdrop-filter: blur(10px);
}
.search-bar.active { display: flex; align-items: center; gap: 10px; }
.search-bar input {
  flex: 1;
  max-width: 400px;
  padding: 6px 12px;
  border: 1px solid rgba(255,255,255,0.2);
  border-radius: 6px;
  background: rgba(255,255,255,0.1);
  color: #fff;
  font-size: 14px;
  outline: none;
}
.search-bar input:focus { border-color: rgba(100,150,255,0.6); }
.search-bar input::placeholder { color: rgba(255,255,255,0.5); }
.search-bar-info {
  color: rgba(255,255,255,0.7);
  font-size: 13px;
  font-family: -apple-system, sans-serif;
  min-width: 80px;
}
.search-bar-btn {
  background: rgba(255,255,255,0.15);
  border: none;
  color: #fff;
  padding: 6px 10px;
  border-radius: 4px;
  cursor: pointer;
  font-size: 13px;
}
.search-bar-btn:hover { background: rgba(255,255,255,0.25); }
.search-bar-close {
  background: none;
  border: none;
  color: rgba(255,255,255,0.6);
  font-size: 20px;
  cursor: pointer;
  padding: 4px 8px;
  line-height: 1;
}
.search-bar-close:hover { color: #fff; }
.search-highlight {
  background-color: rgba(255, 230, 0, 0.4) !important;
  border-radius: 2px;
}
.search-highlight-current {
  background-color: rgba(255, 150, 0, 0.7) !important;
  border-radius: 2px;
}
</style>
"""
        s_footer += """
<div class="search-bar" id="search-bar">
  <input type="text" id="search-input" placeholder="Find in preview..." autocomplete="off">
  <span class="search-bar-info" id="search-info"></span>
  <button class="search-bar-btn" id="search-prev" title="Previous (Shift+Enter)">▲</button>
  <button class="search-bar-btn" id="search-next" title="Next (Enter)">▼</button>
  <button class="search-bar-close" id="search-close" title="Close (Escape)">×</button>
</div>
<script type="text/javascript">
(function() {
  const searchBar = document.getElementById('search-bar');
  const searchInput = document.getElementById('search-input');
  const searchInfo = document.getElementById('search-info');
  let highlights = [];
  let currentIndex = -1;
  let originalHTML = null;

  function escapeRegExp(string) {
    return string.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\\\$&');
  }

  function clearHighlights() {
    highlights.forEach(function(el) {
      const parent = el.parentNode;
      if (parent) {
        parent.replaceChild(document.createTextNode(el.textContent), el);
        parent.normalize();
      }
    });
    highlights = [];
    currentIndex = -1;
    searchInfo.textContent = '';
  }

  function highlightMatches(searchText) {
    clearHighlights();
    if (!searchText || searchText.length < 1) return;

    const walker = document.createTreeWalker(
      document.body,
      NodeFilter.SHOW_TEXT,
      {
        acceptNode: function(node) {
          // Skip search bar, scripts, styles
          const parent = node.parentElement;
          if (!parent) return NodeFilter.FILTER_REJECT;
          const tag = parent.tagName;
          if (tag === 'SCRIPT' || tag === 'STYLE' || parent.closest('.search-bar')) {
            return NodeFilter.FILTER_REJECT;
          }
          return NodeFilter.FILTER_ACCEPT;
        }
      }
    );

    const textNodes = [];
    while (walker.nextNode()) textNodes.push(walker.currentNode);

    const searchLower = searchText.toLowerCase();
    textNodes.forEach(function(node) {
      const text = node.textContent;
      const textLower = text.toLowerCase();
      let idx = textLower.indexOf(searchLower);
      if (idx === -1) return;

      const fragment = document.createDocumentFragment();
      let lastIdx = 0;
      while (idx !== -1) {
        if (idx > lastIdx) {
          fragment.appendChild(document.createTextNode(text.substring(lastIdx, idx)));
        }
        const span = document.createElement('span');
        span.className = 'search-highlight';
        span.textContent = text.substring(idx, idx + searchText.length);
        fragment.appendChild(span);
        highlights.push(span);
        lastIdx = idx + searchText.length;
        idx = textLower.indexOf(searchLower, lastIdx);
      }
      if (lastIdx < text.length) {
        fragment.appendChild(document.createTextNode(text.substring(lastIdx)));
      }
      node.parentNode.replaceChild(fragment, node);
    });

    if (highlights.length > 0) {
      currentIndex = 0;
      updateCurrentHighlight();
      searchInfo.textContent = '1 of ' + highlights.length;
    } else {
      searchInfo.textContent = 'No matches';
    }
  }

  function updateCurrentHighlight() {
    highlights.forEach(function(el, i) {
      if (i === currentIndex) {
        el.className = 'search-highlight-current';
        el.scrollIntoView({ behavior: 'smooth', block: 'center' });
      } else {
        el.className = 'search-highlight';
      }
    });
  }

  function goToNext() {
    if (highlights.length === 0) return;
    currentIndex = (currentIndex + 1) % highlights.length;
    updateCurrentHighlight();
    searchInfo.textContent = (currentIndex + 1) + ' of ' + highlights.length;
  }

  function goToPrev() {
    if (highlights.length === 0) return;
    currentIndex = (currentIndex - 1 + highlights.length) % highlights.length;
    updateCurrentHighlight();
    searchInfo.textContent = (currentIndex + 1) + ' of ' + highlights.length;
  }

  function openSearchBar() {
    searchBar.classList.add('active');
    searchInput.focus();
    searchInput.select();
  }

  function closeSearchBar() {
    searchBar.classList.remove('active');
    clearHighlights();
  }

  // Cmd+F to open search bar
  document.addEventListener('keydown', function(e) {
    if ((e.metaKey || e.ctrlKey) && e.key === 'f') {
      e.preventDefault();
      openSearchBar();
    }
    if (e.key === 'Escape' && searchBar.classList.contains('active')) {
      closeSearchBar();
    }
  });

  // Search input handlers
  let debounceTimer;
  searchInput.addEventListener('input', function() {
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(function() {
      highlightMatches(searchInput.value);
    }, 150);
  });

  searchInput.addEventListener('keydown', function(e) {
    if (e.key === 'Enter') {
      e.preventDefault();
      if (e.shiftKey) goToPrev();
      else goToNext();
    }
  });

  // Button handlers
  document.getElementById('search-next').addEventListener('click', goToNext);
  document.getElementById('search-prev').addEventListener('click', goToPrev);
  document.getElementById('search-close').addEventListener('click', closeSearchBar);
})();
</script>
"""

        let style = css_doc + css_highlight + css_doc_extended
        let wrapper_open = self.renderAsCode ? "<pre class='hl'>" : "<article class='markdown-body'>"
        let wrapper_close = self.renderAsCode ? "</pre>" : "</article>"
        let body_style = self.renderAsCode ? " class='hl'" : ""
        let html =
"""
<!doctype html>
<html>
<head>
<meta charset='utf-8'>
<meta name='viewport' content='width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=0'>
<title>\(title)</title>
\(style)
\(s_header)
</head>
<body\(body_style)>
\(wrapper_open)
\(processedBody)
\(wrapper_close)
\(s_footer)
</body>
</html>
"""
        return html
    }
    
    internal func parseYaml(node: Yams.Node) throws -> Any {
        switch node {
        case .scalar(let scalar):
            return scalar.string
        case .mapping(let mapping):
            var r: [(key: AnyHashable, value: Any)] = []
            for n in mapping {
                guard let k = try parseYaml(node: n.key) as? AnyHashable else {
                    continue
                }
                let v = try parseYaml(node: n.value)
                r.append((key: k, value: v))
            }
            return r
        case .sequence(let sequence):
            var r: [Any] = []
            for n in sequence {
                r.append(try parseYaml(node: n))
            }
            return r
        }
    }
    
    internal func renderYamlHeader(_ text: String, isHTML: inout Bool) -> String {
        if self.tableExtension {
            do {
                if let node = try Yams.compose(yaml: text), let yaml = try self.parseYaml(node: node) as? [(key: AnyHashable, value: Any)] {
                    isHTML = true
                    return renderYaml(yaml)
                }
            } catch {
                // print(error)
            }
        }
        // Embed the header inside a yaml block.
        isHTML = false
        return "```yaml\n"+text+"```\n"
    }
    
    /// Transform mermaid code blocks from `<pre...><code class="language-mermaid">...</code></pre>` to `<div class="mermaid">...</div>`
    private func transformMermaidBlocks(_ html: String) -> String {
        // Match <pre...><code...class="...language-mermaid..."...>...</code></pre>
        // We need to handle potential attributes and whitespace variations
        let pattern = #"<pre[^>]*>\s*<code[^>]*class="[^"]*language-mermaid[^"]*"[^>]*>([\s\S]*?)</code>\s*</pre>"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            os_log("Failed to create mermaid regex pattern", log: OSLog.rendering, type: .error)
            return html
        }

        var result = html
        let matches = regex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))

        // Process matches in reverse order to preserve indices
        for match in matches.reversed() {
            guard let fullRange = Range(match.range, in: html),
                  let contentRange = Range(match.range(at: 1), in: html) else { continue }

            // Get the mermaid content and decode HTML entities
            var content = String(html[contentRange])
            os_log("Mermaid raw content: %{public}@", log: OSLog.rendering, type: .debug, String(content.prefix(200)))
            content = decodeHTMLEntities(content)
            os_log("Mermaid decoded content: %{public}@", log: OSLog.rendering, type: .debug, String(content.prefix(200)))

            // Create the mermaid pre element (pre preserves whitespace unlike div)
            let mermaidPre = "<pre class=\"mermaid\">\(content)</pre>"
            result.replaceSubrange(fullRange, with: mermaidPre)
        }

        return result
    }

    /// Decode common HTML entities to their actual characters
    private func decodeHTMLEntities(_ text: String) -> String {
        var result = text
        let entities: [(String, String)] = [
            ("&#10;", "\n"),
            ("&#13;", "\r"),
            ("&#xA;", "\n"),
            ("&#xD;", "\r"),
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&#39;", "'"),
            ("&apos;", "'"),
            ("&#x27;", "'"),
            ("&#x2F;", "/"),
            ("&#47;", "/"),
            ("&nbsp;", " "),
            ("&#160;", " "),
        ]
        for (entity, char) in entities {
            result = result.replacingOccurrences(of: entity, with: char)
        }
        return result
    }

    /// Extract mermaid blocks from markdown, returning (modified markdown, stored blocks)
    /// This preserves original content with newlines intact
    private func extractMermaidBlocks(_ markdown: String) -> (String, [String: String]) {
        // Match ```mermaid ... ``` blocks, capturing the content
        let pattern = #"```mermaid\s*\n([\s\S]*?)```"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return (markdown, [:])
        }

        var result = markdown
        var storedBlocks: [String: String] = [:]
        let matches = regex.matches(in: markdown, options: [], range: NSRange(markdown.startIndex..., in: markdown))

        // Process in reverse to maintain indices
        for (index, match) in matches.reversed().enumerated() {
            guard let fullRange = Range(match.range, in: markdown),
                  let contentRange = Range(match.range(at: 1), in: markdown) else { continue }

            let content = String(markdown[contentRange])
            // Use a text placeholder that survives cmark-gfm processing
            // (HTML comments get stripped unless unsafe mode is on)
            let blockId = matches.count - 1 - index
            let placeholder = "MERMAID_PLACEHOLDER_\(blockId)_BLOCK"
            storedBlocks[placeholder] = content

            result.replaceSubrange(fullRange, with: placeholder)
        }

        return (result, storedBlocks)
    }

    /// Restore mermaid blocks from placeholders, wrapping in proper HTML
    private func restoreMermaidBlocks(_ html: String, blocks: [String: String]) -> String {
        var result = html
        for (placeholder, content) in blocks {
            // Wrap in pre.mermaid - pre preserves whitespace
            let mermaidHtml = "<pre class=\"mermaid\">\(escapeHtmlForMermaid(content))</pre>"
            // The placeholder gets wrapped in <p> tags by cmark-gfm
            result = result.replacingOccurrences(of: "<p>\(placeholder)</p>", with: mermaidHtml)
            // Also try without <p> tags (in case of different contexts)
            result = result.replacingOccurrences(of: placeholder, with: mermaidHtml)
        }
        return result
    }

    /// Escape HTML special characters for mermaid content (but preserve newlines)
    private func escapeHtmlForMermaid(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    internal func renderYaml(_ yaml: [(key: AnyHashable, value: Any)]) -> String {
        guard yaml.count > 0 else {
            return ""
        }
        
        var s = "<table>"
        for element in yaml {
            let key: String = "<strong>\(element.key)</strong>"
            /*
            do {
                key = try self.render(text: "**\(element.key)**", filename: "", forAppearance: .light, baseDir: "")
            } catch {
                key = "<strong>\(element.key)</strong>"
            }*/
            s += "<tr><td align='right'>\(key)</td><td>"
            if let t = element.value as? [(key: AnyHashable, value: Any)] {
                s += renderYaml(t)
            } else if let t = element.value as? [Any] {
                s += "<ul>\n" + t.map({ v in
                    let s: String = "\(v)"
                    /*
                    if let t = v as? String {
                        do {
                            s = try self.render(text: t, filename: "", forAppearance: .light, baseDir: "")
                        } catch {
                            s = t
                        }
                    } else {
                        s = "\(v)"
                    }*/
                    return "<li>\(s)</li>"
                }).joined(separator: "\n")
            } else if let t = element.value as? String {
                s += t
                /*
                do {
                    s += try self.render(text: t, filename: "", forAppearance: .light, baseDir: "")
                } catch {
                    s += t.replacingOccurrences(of: "|", with: #"\|"#)
                }
                */
            } else {
                s += "\(element.value)"
            }
            s += "</td></tr>\n"
        }
        s += "</table>"
        return s
    }
    
}
