# XGE Backtest Report - XAUUSD 1 Year

- Data: XAUUSD M5 (XM) resampled to M15, 2021-12-01 .. 2026-08-21
- Evaluation window: **2025-08-21 .. 2026-08-21** (1 year), indicators warmed up on 1358 days of prior history
- Simulation: faithful Python mirror of XauusdAdaptiveEA v1.00 (all default inputs; session/news times mapped to dataset timezone)
- Start balance: $10,000, risk 1.0%/trade, spread taken from broker data (avg 0.20 USD)

## Results

| Metric | Value |
|---|---|
| Net profit | $573.35 (+5.73%) |
| Final equity | $10,573.35 |
| Closed trades (round turns) | 161 |
| Win rate (round turns) | 52.2% |
| Profit factor (incl. partials) | 1.07 |
| Avg win / avg loss | $62.13 / $-105.02 |
| Max drawdown | 15.51% |
| Longest losing streak | 7 |
| Sharpe (daily) | 0.46 |

## Capital protection kicked in (by design)

- Last trade closed: **2025-12-01 14:00**. From that point the 15% max-drawdown
  limit kept equity more than 15% below its peak, so the EA correctly **blocked every new
  entry for the rest of the year** (263 days flat). This is the
  spec behaviour: once the risk limit is breached, new trading stops until operator review.
- Equity at the halt point stayed at **$10,573.35** for the remaining period -
  capital was preserved instead of being given back in the choppy market that followed.

## Monthly breakdown (all fills incl. partial closes)

| Month | Fills | P/L ($) |
|---|---|---|
| 2025-08 | 24.0 | +117.73 |
| 2025-09 | 67.0 | +943.10 |
| 2025-10 | 78.0 | +1,088.16 |
| 2025-11 | 46.0 | -1,476.69 |
| 2025-12 | 3.0 | -98.94 |

## By strategy

| Strategy | Round turns | Win% | Total P/L incl. partials ($) |
|---|---|---|---|
| Breakout | 35 | 51% | +151.17 |
| Pullback | 62 | 55% | +1,222.87 |
| Range | 7 | 29% | -433.32 |
| Retest | 4 | 50% | +127.58 |
| Trend | 53 | 53% | -494.94 |

## By exit reason

| Exit | Fills | P/L ($) |
|---|---|---|
| PARTIAL | 57.0 | +3,441.05 |
| SL | 115.0 | -7,437.46 |
| TP | 42.0 | +4,628.91 |
| WEEKEND | 4.0 | -59.14 |

## Condition distribution (bars)

- UNCERTAIN: 8098 (34.2%)
- RANGE: 4750 (20.0%)
- WEAK DOWNTREND: 3312 (14.0%)
- WEAK UPTREND: 3273 (13.8%)
- STRONG UPTREND: 1329 (5.6%)
- STRONG DOWNTREND: 735 (3.1%)
- PULLBACK BULL: 693 (2.9%)
- PULLBACK BEAR: 524 (2.2%)
- BREAKOUT BULL: 467 (2.0%)
- BREAKOUT BEAR: 277 (1.2%)
- LOW VOL: 187 (0.8%)
- EXTREME VOL: 46 (0.2%)
- ABNORMAL: 4 (0.0%)

## Why trades were skipped (gate blocks)

- Outside session: 2200
- Max drawdown: 1784
- News window: 895
- HTF conflict: 183
- Friday stop: 54
- Low confidence: 39
- Same setup repeat: 37
- Weekly loss limit: 14
- Loss cooldown: 6
- Condition: UNCERTAIN: 6
- High spread: 5
- Condition: LOW VOL: 5
- Condition: EXTREME VOL: 4
- Entry gap: 2
- Max trades/day: 1

> Disclaimer: simulated approximation of the MT5 EA (execution timing, tick path and calendar news differ from the live Strategy Tester). Validate in MT5 before live use.