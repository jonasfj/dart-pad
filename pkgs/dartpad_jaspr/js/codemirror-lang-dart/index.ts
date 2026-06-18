import { parser } from "./dart.grammar"
export { parser as dartParser, parser }
import {
  LRLanguage,
  LanguageSupport,
  indentNodeProp,
  foldNodeProp,
  foldInside,
  continuedIndent,
  delimitedIndent
} from "@codemirror/language"
import { parseMixed } from "@lezer/common"
import { markdownLanguage } from "@codemirror/lang-markdown"
import { dartHighlight } from "./highlight"

/// A language provider based on the Lezer Dart parser, extended with
/// highlighting and indentation information.
export const dartLanguage = LRLanguage.define({
  name: "dart",
  parser: parser.configure({
    props: [
      dartHighlight,
      indentNodeProp.add({
        IfStatement: continuedIndent({ except: /^\s*({|else\b)/ }),
        TryStatement: continuedIndent({ except: /^\s*({|catch\b|finally\b|on\b)/ }),
        "Block ClassBody": delimitedIndent({ closing: "}" }),
        "Statement Declaration": continuedIndent()
      }),
      foldNodeProp.add({
        "Block ClassBody": foldInside,
        BlockComment(tree) { return { from: tree.from + 2, to: tree.to - 2 } }
      })
    ],
    wrap: parseMixed((node, input) => {
      if (node.name == "DocBlockComment") {
        let from = node.from + 3, to = node.to - 2
        if (from >= to) return null
        return {
          parser: markdownLanguage.parser,
          overlay: [{ from, to }]
        }
      }
      if (node.name == "DocComment") {
        let text = input.read(node.from, node.to)
        let overlays = []
        let pos = node.from
        let lines = text.split("\n")
        for (let i = 0; i < lines.length; i++) {
          let line = lines[i]
          let match = /^[ \t]*\/\/\/( ?)/.exec(line)
          if (match) {
            let from = pos + match[0].length
            // Include the newline in the overlay if it's not the last line
            let to = pos + line.length + (i < lines.length - 1 ? 1 : 0)
            if (to > from) overlays.push({ from, to })
          } else {
            // Include empty/non-comment lines as part of the markdown (e.g. gap between ///)
            let to = pos + line.length + (i < lines.length - 1 ? 1 : 0)
            if (to > pos) overlays.push({ from: pos, to })
          }
          pos += line.length + 1
        }
        if (overlays.length == 0) return null
        return {
          parser: markdownLanguage.parser,
          overlay: overlays
        }
      }
      return null
    })
  }),
  languageData: {
    commentTokens: { line: "//", block: { open: "/*", close: "*/" } },
    indentOnInput: /^\s*[{}]$|^\s*(?:case |default:|else\b|catch\b|finally\b|on\b)/,
    closeBrackets: { brackets: ["(", "[", "{", "'", '"', "'''", '"""'] },
    wordChars: "$"
  }
})

/// Dart language support.
export function dart() {
  return new LanguageSupport(dartLanguage)
}
