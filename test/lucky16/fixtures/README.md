# Lucky 16 Card test fixtures

These are **adapted**, not fresh captures. Each file was copied from
`test/lucky_card/fixtures/`, Lucky Card's real answers captured from the live
database on 2026-10-06. The `lucky16_*` player functions (migration
`20261028160000_lucky16_player_functions.sql`) return exactly the same JSON
fields and raise the same SQLSTATE codes and messages as Lucky Card's. This was
checked against their live definitions on 2026-10-28. Only the values that
differ for Lucky 16 Card were changed:

| File | Change from the Lucky Card capture |
|---|---|
| `current_round_betting.json` | none |
| `current_round_drawn.json` | winning card Q clubs changed to **A hearts**, so the new rank is parsed |
| `my_result_no_bet.json` | none |
| `my_result_unsettled.json` | 10 on each of **16** cards: total_stake 120 → **160**, coin_balance 67322 → **67282** |
| `my_result_settled_win.json` | 10 on each of 16 cards at 3X pays 10 × **14** × 3: total_stake **160**, total_payout 300 → **420**, coin_balance → **67702** |
| `place_bet_success.json` | total_stake **160**, coin_balance **67282** |
| `recent_rounds.json` | the middle round's Q diamonds changed to **A diamonds** |
| `history_rows.json` | adapted from Lucky Card's capture of 2026-10-22 (rows of lucky16_bets with lucky16_rounds embedded): the win row is 10,000 on every one of 16 cards, total_stake 480000 → **160000**, at 5X paying 10,000 × 14 × 5, total_payout 2400000 → **700000**; the loss row's Q hearts changed to **A hearts** |
| `errors.json` | none (same codes and messages in `lucky16_place_bet`) |

The round ids, round numbers and timestamps are still the Lucky Card ones. The
tests only check their shape, never that they exist in `lucky16_rounds`.
