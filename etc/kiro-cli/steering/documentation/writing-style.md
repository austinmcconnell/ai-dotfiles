# Writing Style Guide

**Purpose**: Standards for voice, tone, and technical writing in documentation to ensure consistency
and clarity.

## Core Principles

1. **Clarity over cleverness** - Be direct and unambiguous
1. **Consistency** - Use the same terms and patterns throughout
1. **Accessibility** - Write for diverse audiences and abilities
1. **Scannability** - Use structure to help readers find information quickly

## Voice and Tone

- Professional but approachable, helpful, precise, confident
- Procedures: direct, instructional, imperative mood, encouraging
- Configuration: factual, descriptive, present tense, neutral
- Decisions (ADRs): analytical, balanced, past tense for decisions made

## Grammar and Style

**Person:**

- Second person ("you") in procedures
- Third person in configuration and components

**Voice:**

- Prefer active voice
- Passive acceptable when actor is unknown or emphasizing action over actor

**Tense:**

- Present tense for current state
- Past tense for decisions
- Future tense only when truly future

**Mood:**

- Imperative for instructions (e.g., "Navigate to Settings" not "You should navigate to Settings")

## Terminology

| Use           | Don't Mix With                 |
| ------------- | ------------------------------ |
| log in (verb) | login, sign in, sign on        |
| username      | user name, user ID, login name |
| email         | e-mail, Email, EMAIL           |
| setup (noun)  | set-up, set up                 |
| set up (verb) | setup                          |

- Use industry-standard terms: "IP address" not "IP", "TLS" not "SSL" (unless specifically SSL)
- Define acronyms on first use

| Instead of            | Use     |
| --------------------- | ------- |
| leverage              | use     |
| utilize               | use     |
| in order to           | to      |
| at this point in time | now     |
| due to the fact that  | because |

## Formatting Conventions

**Headings:** Sentence case. Descriptive. One H1 per file. Maintain hierarchy (don't skip levels).

**Lists:** Numbered for sequential steps. Bullets for non-sequential items. Consistent punctuation
(complete sentences get periods, fragments don't).

**Code:** Inline code for commands, file paths, config values, snippets. Code blocks for multi-line
code with language specified.

**Emphasis:** Bold for UI elements. Italics sparingly for emphasis or introducing terms. Never ALL
CAPS.

## Sentence Structure

- Aim for 15-20 words per sentence
- One idea per sentence
- Prefer simple structures over complex compound sentences

## Accessibility

- Use descriptive link text (never "click here" or "this link")
- Always include alt text on images
- Always include headers on tables
- Don't rely on color alone to convey meaning (use icons/text)

## Numbers and Dates

- Spell out one through nine; use numerals for 10 and above
- Always use numerals for technical values (ports, frequencies, IPs)
- Use ISO 8601 format for dates: YYYY-MM-DD

## Punctuation

- Use Oxford comma
- Use colons to introduce lists or explanations
- Hyphenate compound modifiers (step-by-step, well-known, command-line)
- Use hyphens for parenthetical breaks
