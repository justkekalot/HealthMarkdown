import SwiftUI

/// Renders a chat bubble's text. Assistant messages are parsed as Markdown
/// (bold, italics, lists, inline code) so Gemma's formatting shows properly;
/// user messages stay plain. Falls back to plain text if parsing fails.
struct ChatBubbleText: View {
    let text: String
    let isUser: Bool

    var body: some View {
        Group {
            if isUser {
                Text(text)
            } else {
                Text(attributed)
            }
        }
        .font(.callout)
        .foregroundStyle(isUser ? Color.white : Theme.textPrimary)
        .tint(Theme.accent)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var attributed: AttributedString {
        // Full-document markdown so lists / line breaks survive (the default
        // inline-only mode collapses them).
        let options = AttributedString.MarkdownParsingOptions(
            allowsExtendedAttributes: true,
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        if let a = try? AttributedString(markdown: text, options: options) {
            return a
        }
        return AttributedString(text)
    }
}
