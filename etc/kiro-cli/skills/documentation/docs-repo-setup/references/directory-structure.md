# Directory Structure

Recommended directory layout for documentation repositories.

```text
project-root/
├── AGENTS.md              # Content ownership model (not in book)
├── README.md              # Repo-level getting started guide (not in book)
├── INTRODUCTION.md        # Book introduction (first SUMMARY.md entry)
├── SUMMARY.md             # mdBook navigation
├── RESEARCH.md            # External references
├── glossary.md            # Terminology
├── planning/
│   ├── README.md          # Planning overview
│   ├── requirements.md    # Requirements only
│   └── bom.md             # Bill of materials
├── components/            # Hardware, software, or system components
│   ├── README.md
│   └── [component].md     # One file per component
├── configuration/
│   ├── README.md
│   └── [config].md        # One file per config area
├── procedures/
│   ├── README.md
│   ├── initial-setup.md   # Sequential setup guide
│   └── [procedure].md     # One file per procedure
└── decisions/
    ├── README.md
    ├── adr-template.md
    └── adr-NNN-*.md       # Numbered ADRs
```
