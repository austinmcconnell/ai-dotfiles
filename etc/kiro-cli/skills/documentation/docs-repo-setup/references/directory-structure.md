# Directory Structure

Recommended directory layout for documentation repositories.

## Standard layout (single-file research)

```text
project-root/
├── AGENTS.md              # Content ownership model (not in book)
├── README.md              # Repo-level getting started guide (not in book)
├── INTRODUCTION.md        # Book introduction (first SUMMARY.md entry)
├── SUMMARY.md             # mdBook navigation
├── RESEARCH.md            # External references (appendix in SUMMARY.md)
├── glossary.md            # Terminology
├── planning/
│   ├── README.md          # Planning overview
│   └── requirements.md    # Requirements only
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

## Expanded layout (directory research)

When research outgrows a single file (~300 lines or 5+ topics), replace `RESEARCH.md` with a
`research/` directory:

```text
project-root/
├── AGENTS.md
├── README.md
├── INTRODUCTION.md
├── SUMMARY.md
├── glossary.md
├── planning/
│   ├── README.md
│   └── requirements.md
├── research/              # Top-level section in SUMMARY.md
│   ├── README.md          # Research index with topic links
│   └── [topic].md         # One file per research topic
├── decisions/
│   ├── README.md
│   └── adr-NNN-*.md
├── components/
│   ├── README.md
│   ├── [component].md
│   └── bom.md
├── configuration/
│   ├── README.md
│   └── [config].md
└── procedures/
    ├── README.md
    └── [procedure].md
```
