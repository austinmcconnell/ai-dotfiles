# BOM File Template

```markdown
# Bill of materials

<!-- This file is a PROCUREMENT LEDGER — it records actual per-unit costs. -->
<!-- Purchase details (price, date) live in individual component files. -->
<!-- Prices are pre-tax, pre-shipping unit prices. -->
<!-- BOM prices must match the real prices in component files. -->

## Components

| Component                                        | Qty | Unit price | Status |
| ------------------------------------------------ | --- | ---------- | ------ |
| [Specific Product Name](name.md)   | 0   | $0.00      | Needed |
| [Another Product Name](name-2.md)  | 0   | $0.00      | Needed |
| **Total**                                        |     | **$0.00**  |        |

## Notes

- Unit prices are pre-tax, pre-shipping per component file conventions
- Update component files first, then sync this ledger

## Related documentation

- [Components](./) — authoritative purchase details per component
- [Requirements](../planning/requirements.md) — project requirements and budget constraints
```

## Conventions

### Component naming

Use specific product or model names, not generic categories. The BOM should read as a procurement
ledger — someone should be able to look at a row and know exactly what was ordered and what it cost.

| Use                       | Don't use   |
| ------------------------- | ----------- |
| Noctua NF-A12x25 PWM      | Case fans   |
| Samsung 970 EVO Plus 1TB  | Storage     |
| USW-Flex-2.5G-8-PoE       | Main Switch |
| UniFi Cloud Gateway Fiber | Gateway     |
| AMD Ryzen 7 9700X         | CPU         |

### One row per purchasable item

Each distinct purchasable item gets its own row. Do not aggregate multiple products into a single
row.

- Qty reflects the actual quantity of that specific item
- When a component file covers multiple products, list each product as a separate BOM row linking to
  the same component file
- A component file for "case fans" with three different fan models and two hub models produces five
  BOM rows, not one

### Linking

Multiple BOM rows can link to the same component file. The link target is the component file that
contains the item's purchase information.
