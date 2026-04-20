# Directory Structure

Recommended directory layout for documentation repositories.

## Standard layout

```text
project-root/
├── AGENTS.md              # Content ownership model (not in book)
├── README.md              # Repo-level getting started guide (not in book)
├── INTRODUCTION.md        # Book introduction (first SUMMARY.md entry)
├── SUMMARY.md             # mdBook navigation
├── glossary.md            # Terminology
├── planning/
│   ├── README.md          # Planning overview
│   └── requirements.md    # Requirements only
├── research/              # Top-level section in SUMMARY.md
│   ├── README.md          # Research index with topic links
│   └── [topic].md         # One file per research topic
├── decisions/
│   ├── README.md
│   ├── adr-template.md
│   └── adr-NNN-*.md       # Numbered ADRs
├── components/            # Hardware, software, or system components
│   ├── README.md
│   ├── [component].md     # One file per component
│   └── bom.md             # Bill of materials
├── configuration/
│   ├── README.md
│   └── [config].md        # One file per config area
└── procedures/
    ├── README.md
    ├── initial-setup.md   # Sequential setup guide
    └── [procedure].md     # One file per procedure
```

## Single-file research (alternative)

For very small projects with only a few research links, a single `RESEARCH.md` at the project root
is acceptable. List it in SUMMARY.md below a `---` separator as appendix material. Migrate to the
directory format when the file exceeds ~300 lines or has five or more distinct topics.
