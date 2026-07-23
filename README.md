# Balanced PA Panel MT4

Independent MT4 indicator package for a balanced price-action dashboard.

This release is designed for public/open-source distribution. It is an independent implementation built from general trading concepts such as:

- session value area (`POC`, `VAH`, `VAL`)
- liquidity sweeps
- `BOS` and `CHOCH`
- Wyckoff-style phase context
- Brooks-style trigger timing
- breakout and pullback arrows

It is not affiliated with, endorsed by, or distributed on behalf of any private trading group, paid community, or locked binary product.

## Included

- `Indicators/BalancedPAPanelMT4.mq4`
- `LICENSE`
- `docs/OPEN_SOURCE_NOTES.md`

## Features

- compact on-chart PA dashboard
- session profile context with `POC`, `VAH`, `VAL`, `EqH`, `EqL`
- value acceptance vs rejection read
- Wyckoff context summary
- Brooks trigger summary
- separate breakout and pullback arrows
- movable panel with saved chart position

## Arrow Colors

- `Aqua`: breakout long
- `Lime`: pullback long
- `OrangeRed`: breakout short
- `Gold`: pullback short

## Installation

1. Copy `Indicators/BalancedPAPanelMT4.mq4` into your MT4 `MQL4/Indicators` folder.
2. Open MetaEditor and compile the file.
3. In MT4, refresh the Navigator or restart the terminal.
4. Drag `BalancedPAPanelMT4` onto a chart.

## Notes

- This is an `MT4` indicator, not an expert advisor.
- Defaults are tuned for XAUUSD-style intraday chart reading, but inputs are editable.
- The panel language is English so the package is easier to publish and maintain on GitHub.

## Public Release Guidance

- keep the neutral name and non-affiliation wording
- do not include private-group logos, screenshots, or locked binaries
- do not claim it is an official conversion of someone else's closed-source tool

## Disclaimer

Educational use only. This project does not provide financial advice, trading guarantees, or execution automation.
