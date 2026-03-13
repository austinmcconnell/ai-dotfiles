# Writing Style Guide

**Purpose**: Standards for voice, tone, and technical writing in documentation to ensure consistency and clarity.

## Core Principles

1. **Clarity over cleverness** - Be direct and unambiguous
2. **Consistency** - Use the same terms and patterns throughout
3. **Accessibility** - Write for diverse audiences and abilities
4. **Scannability** - Use structure to help readers find information quickly

## Voice and Tone

### Voice (Who We Are)

- **Professional but approachable** - Technical but not intimidating
- **Helpful** - Guide users to success
- **Precise** - Accurate and specific
- **Confident** - Authoritative without being arrogant

### Tone (How We Sound)

**In procedures:**

- Direct and instructional
- Use imperative mood: "Configure the gateway" not "You should configure the gateway"
- Encouraging: "You're ready to proceed" not "If you did everything correctly"

**In configuration:**

- Factual and descriptive
- Present tense: "The system uses" not "The system will use"
- Neutral: State facts without opinion

**In decisions (ADRs):**

- Analytical and balanced
- Past tense for decisions made: "We chose" not "We choose"
- Present consequences objectively

## Grammar and Style

### Person

**Use second person ("you") in procedures:**

```markdown
<!-- Good -->

Configure the gateway by navigating to Settings.

<!-- Avoid -->

The user should configure the gateway by navigating to Settings.
One configures the gateway by navigating to Settings.
```

**Use third person in configuration and components:**

```markdown
<!-- Good -->

The system routes traffic through the gateway.

<!-- Avoid -->

You route traffic through the gateway. (in configuration docs)
```

### Voice (Active vs Passive)

**Prefer active voice:**

```markdown
<!-- Good -->

The gateway routes traffic to the appropriate VLAN.

<!-- Avoid -->

Traffic is routed to the appropriate VLAN by the gateway.
```

**Passive voice is acceptable when:**

- The actor is unknown or irrelevant
- Emphasizing the action over the actor

```markdown
<!-- Acceptable -->

The configuration is validated before deployment.
```

### Tense

**Present tense for current state:**

```markdown
<!-- Good -->

The system uses TLS 1.3 for encryption.

<!-- Avoid -->

The system will use TLS 1.3 for encryption.
```

**Past tense for decisions:**

```markdown
<!-- Good -->

We chose PostgreSQL for its reliability.

<!-- Avoid -->

We choose PostgreSQL for its reliability.
```

**Future tense sparingly:**

```markdown
<!-- Use only when truly future -->

The next release will include support for IPv6.
```

### Mood

**Imperative for instructions:**

```markdown
<!-- Good -->

1. Navigate to Settings
2. Click Network
3. Enter the IP address

<!-- Avoid -->

1. You should navigate to Settings
2. You need to click Network
3. You must enter the IP address
```

## Terminology

### Consistency

**Choose one term and use it consistently:**

| Use           | Don't Mix With                 |
| ------------- | ------------------------------ |
| log in (verb) | login, sign in, sign on        |
| username      | user name, user ID, login name |
| email         | e-mail, Email, EMAIL           |
| setup (noun)  | set-up, set up                 |
| set up (verb) | setup                          |

### Technical Terms

**Use industry-standard terminology:**

- Use "IP address" not "IP" or "address"
- Use "VLAN" not "virtual LAN" after first use
- Use "TLS" not "SSL" (unless specifically SSL)

**Define acronyms on first use:**

```markdown
<!-- Good -->

The system uses Transport Layer Security (TLS) for encryption. TLS provides...

<!-- Avoid -->

The system uses TLS for encryption. (without defining)
```

### Avoid Jargon

**Replace jargon with clear language:**

| Instead of            | Use     |
| --------------------- | ------- |
| leverage              | use     |
| utilize               | use     |
| in order to           | to      |
| at this point in time | now     |
| due to the fact that  | because |

## Formatting Conventions

### Headings

**Use sentence case for headings:**

```markdown
<!-- Good -->

## Network configuration

<!-- Avoid -->

## Network Configuration
```

**Use descriptive headings:**

```markdown
<!-- Good -->

## Configure gateway settings

<!-- Avoid -->

## Settings
```

**Maintain hierarchy:**

- H1 (`#`) - Document title (one per file)
- H2 (`##`) - Major sections
- H3 (`###`) - Subsections
- Don't skip levels (H1 → H3)

### Lists

**Use numbered lists for sequential steps:**

```markdown
1. First step
2. Second step
3. Third step
```

**Use bullet lists for non-sequential items:**

```markdown
- Feature A
- Feature B
- Feature C
```

**Use consistent punctuation:**

- Complete sentences: End with period
- Fragments: No ending punctuation
- Be consistent within a list

### Code and Commands

**Use code formatting for:**

- Commands: `mdbook build`
- File paths: `/etc/config/network`
- Configuration values: `192.168.1.1`
- Code snippets: `const x = 5;`

**Use code blocks for multi-line code:**

````markdown
```bash
mdbook build
mdbook serve
```
````

**Specify language for syntax highlighting:**

````markdown
```python
def hello():
    print("Hello, world!")
```
````

### Emphasis

**Use bold for UI elements:**

```markdown
Click **Settings** > **Network** > **Advanced**.
```

**Use italics sparingly:**

- For emphasis: _only_ when necessary
- For introducing new terms: The _gateway_ is the...

**Avoid ALL CAPS:**

```markdown
<!-- Good -->

Important: Back up your configuration first.

<!-- Avoid -->

IMPORTANT: BACK UP YOUR CONFIGURATION FIRST.
```

## Sentence Structure

### Length

**Keep sentences concise:**

- Aim for 15-20 words per sentence
- Break long sentences into multiple shorter ones
- One idea per sentence

```markdown
<!-- Good -->

The gateway routes traffic between VLANs. It uses firewall rules to control access.

<!-- Avoid -->

The gateway routes traffic between VLANs and uses firewall rules to control access, which provides security.
```

### Complexity

**Prefer simple sentence structures:**

```markdown
<!-- Good -->

Configure the gateway. Then test the connection.

<!-- Avoid -->

After configuring the gateway, which involves setting the IP address and subnet mask, test the connection to ensure proper functionality.
```

## Accessibility

### Link Text

**Use descriptive link text:**

```markdown
<!-- Good -->

See [Configuration: Network Topology](../configuration/network-topology.md) for details.

<!-- Avoid -->

See [here](../configuration/network-topology.md) for details.
Click [this link](../configuration/network-topology.md).
```

### Images

**Always include alt text:**

```markdown
![Network topology diagram showing three VLANs](images/network-topology.png)
```

### Tables

**Include headers:**

```markdown
| Setting | Value       | Description     |
| ------- | ----------- | --------------- |
| IP      | 192.168.1.1 | Gateway address |
```

### Color

**Don't rely on color alone:**

```markdown
<!-- Good -->

✅ Success: Configuration saved
❌ Error: Invalid IP address

<!-- Avoid -->

Success: Configuration saved (shown in green)
Error: Invalid IP address (shown in red)
```

## Numbers and Dates

### Numbers

**Spell out one through nine:**

```markdown
<!-- Good -->

The system has three VLANs.
The system supports 10 concurrent connections.

<!-- Avoid -->

The system has 3 VLANs.
```

**Use numerals for 10 and above:**

```markdown
<!-- Good -->

Configure 15 firewall rules.

<!-- Avoid -->

Configure fifteen firewall rules.
```

**Use numerals for technical values:**

```markdown
<!-- Always use numerals -->

Port 443
5 GHz
192.168.1.1
```

### Dates

**Use ISO 8601 format (YYYY-MM-DD):**

```markdown
<!-- Good -->

2024-03-13

<!-- Avoid -->

3/13/2024
March 13, 2024
13 March 2024
```

**For ADR frontmatter:**

```yaml
date: 2024-03-13
```

## Punctuation

### Commas

**Use Oxford comma:**

```markdown
<!-- Good -->

The system supports IPv4, IPv6, and dual-stack configurations.

<!-- Avoid -->

The system supports IPv4, IPv6 and dual-stack configurations.
```

### Colons

**Use colons to introduce lists or explanations:**

```markdown
<!-- Good -->

The system requires three components: gateway, switch, and access point.

<!-- Avoid -->

The system requires three components, gateway, switch, and access point.
```

### Hyphens and Dashes

**Hyphenate compound modifiers:**

```markdown
<!-- Good -->

step-by-step instructions
well-known port
command-line interface

<!-- Avoid -->

step by step instructions
well known port
command line interface
```

**Use em dash (—) for breaks in thought:**

```markdown
The gateway—configured with default settings—routes all traffic.
```

## Common Mistakes

### Avoid Ambiguity

```markdown
<!-- Ambiguous -->

Configure the gateway and switch settings.
(Gateway settings and switch settings? Or gateway-and-switch settings?)

<!-- Clear -->

Configure the gateway settings and the switch settings.
```

### Avoid Assumptions

```markdown
<!-- Assumes knowledge -->

Simply configure the VLAN.

<!-- Better -->

Configure the VLAN by following these steps:
```

### Avoid Redundancy

```markdown
<!-- Redundant -->

Completely finish the configuration.
Advance planning is required.

<!-- Better -->

Finish the configuration.
Planning is required.
```

## Quality Checklist

Before finalizing documentation:

- [ ] Voice is consistent (second person in procedures, third person in configuration)
- [ ] Active voice used where appropriate
- [ ] Present tense for current state
- [ ] Terminology is consistent
- [ ] Acronyms defined on first use
- [ ] Headings use sentence case
- [ ] Lists use consistent punctuation
- [ ] Code and commands properly formatted
- [ ] Link text is descriptive
- [ ] Images have alt text
- [ ] Tables have headers
- [ ] Numbers follow style guide
- [ ] Dates use ISO 8601 format
- [ ] Oxford comma used
- [ ] No jargon or ambiguity
- [ ] Sentences are concise
- [ ] Accessibility guidelines followed
