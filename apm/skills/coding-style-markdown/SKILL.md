---
name: coding-style-markdown
description: 'Coding style and formatting conventions for authoring consistent, portable, LLM-friendly CommonMark Markdown. Use when creating, editing, reviewing, or reformatting any Markdown file (*.md, *.markdown, *.instructions.md, README, docs, changelogs): headings, spacing, lists, code blocks, links, images, tables, extended syntax, tone, and diagram conventions.'
---

# Markdown Coding Style Guidelines

Guidelines for writing clean, consistent, and portable Markdown documentation optimized for both human readability and LLM processing.

## Project Context

- **Standard**: CommonMark-compliant Markdown
- **Rendering**: Must work with standard Markdown processors and documentation tools
- **Diagrams**: Use Mermaid for diagrams instead of images where possible
- **Style Reference**:
  - [Markdown Guide: Basic Syntax](https://www.markdownguide.org/basic-syntax/)
  - [Markdown Guide: Extended Syntax](https://www.markdownguide.org/extended-syntax/)

## General Principles

- Produce Markdown that renders correctly in git diffs, terminals, and documentation sites.
- Optimize for readability in both raw and rendered form.
- Prefer simple, portable constructs over renderer-specific extensions.
- **Never use HTML** unless absolutely necessary or requested by the project's specifications.

## Spacing and Formatting

- Use a single blank line to separate block elements (headings, paragraphs, lists, tables, code blocks, block quotes).
- Do not use more than one consecutive blank line.
- Do not insert arbitrary leading spaces unless required for list nesting or fenced code blocks.
- Avoid trailing whitespace at end of lines.
- Always finish the file with a single newline (one blank line at end of file).

## Headings

- Use ATX-style (`#`,`##`,`###`) with a single space after the hashes and **no trailing `#`**.
- Use **sentence case** for headings (capitalize only the first word and proper nouns).
- Use exactly one H1 (`#`) per document, as the first heading.
- Do not skip heading levels; change by one level at a time (H1 → H2 → H3 → H4).
- Place exactly one blank line before and after each heading, except when the heading is the first line.

## Paragraphs

- Paragraphs are one or more lines of text separated from other blocks by a single blank line.
- Do not indent the first line of a paragraph.
- Keep each paragraph as its own block separated by a blank line.

## Emphasis, strong text, and inline code

- Use `*italic*` for emphasis and `**bold**` for strong emphasis; avoid `_` variants.
- Avoid overusing bold or italics, especially in headings. Keep headings plain text.
- Use backticks for inline code: `` `Get-Help` ``.
- For inline code that contains backticks, increase the delimiter size. Use as many backticks as necessary, for example:
  - If the code contains a single backtick: use double backticks: ` `X`Y` `.
  - If code contains triple backticks-like content, use four backticks: ` ```x``` `.

## Lists

- Use `-` for unordered lists (not `*` or `+`).
- Use sequential numbering for ordered lists (`1.`, `2.`, `3.`).
- Place exactly one space between bullet or number and text (`- item`, `1. item`).
- Insert a single blank line before and after a list when surrounded by other block elements.
- Keep simple lists contiguous (no blank lines between items).
- For complex list items containing multiple paragraphs or code blocks:
  - Start the first paragraph on the same line as the bullet.
  - Indent subsequent paragraphs, code blocks or sub-lists by **two spaces** so they remain part of the same item.
  - Leave a single blank line between paragraphs or blocks within the same list item.
- Punctuation: do not add a trailing period to list items unless the item is a full sentence.

### Nested lists

- Indent nested lists by **two spaces** from the parent bullet text column.
- Use the same bullet style (`-`) and numbering rules as the parent list.

## Code blocks

- Prefer fenced code blocks (triple backticks) over indented blocks.
- Always specify a language when known (`powershell`, `bash`, `json`, `yaml`, `csharp`, etc.). Use `text` for non-code samples or by default.
- Insert a single blank line before and after fenced code blocks.
- Place opening and closing fences at column 0 unless the block is inside a list item.
- For code blocks inside list items:
  - Indent the fenced block by **two spaces** to align with the list item's content.
  - Keep opening fence, closing fence and inner code aligned.
- Avoid multiple consecutive blank lines inside code blocks.

## Links and URLs

- Use descriptive link text instead of raw URLs. Example: `[Markdown syntax guide](https://www.markdownguide.org/basic-syntax/)`.
- Do not break link definitions across multiple lines unless necessary.
- For reference-style links, group definitions near the end of the file separated by a single blank line.
- Prefer relative paths for internal links/images and absolute URLs for external resources.

## Images and accessibility

- Use Markdown image syntax; do **not** use raw HTML `<img>`.
- Always provide `alt` text. Markdown produced by a coding assistant must follow this pattern, substituting the real description and path:

  ```md
  ![Short alt text describing the image](/assets/diagram.png)
  ```

- If the image requires a longer explanation, add a short caption or a descriptive paragraph following the image.
- Prefer relative paths for repo images and small images in `assets/`.
- Example with caption:

  ```md
  ![Architecture overview](/assets/arch.png)

  _Figure 1 — high-level architecture overview._
  ```

## Tables

- Use pipe tables with header and separator row.
- Align columns with colons when alignment matters (`:---`, `:---:`, `---:`).
- Place a single blank line before and after tables.
- Keep cell content short; move long explanations into a paragraph after the table.

## Extended syntax

- Task lists: `- [ ]` and `- [x]`.
- Footnotes: use `[^1]` with definitions grouped near the bottom.
- Strikethrough: `~~text~~`.
- Surround task list blocks with a single blank line before and after.
- Group footnote definitions together, separated from the main content by a single blank line.

## Language, Tone and Style

- Use clear, concise sentences and active voice.
- Prefer second person ("you") for how-to and user-facing documentation.
- For commands or code:
  - Provide one short sentence of context before the code block.
  - Follow the code block with a short explanation of what it does.

## LLM-Specific Guidance

- Respect the one-blank-line rule between block elements.
- Minimize changes to existing spacing unless correcting an inconsistency.
- Preserve existing indentation inside lists and code blocks; only adjust when broken.
- When making edits, prefer small, focused commits that minimize unrelated reformatting.
- For generated content: where appropriate, include short examples and minimal tests.

## References

- [Markdown Guide: Basic Syntax](https://www.markdownguide.org/basic-syntax/)
- [Markdown Guide: Extended Syntax](https://www.markdownguide.org/extended-syntax/)
