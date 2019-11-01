# ExBanking

https://coingaming.github.io/elixir-test/

Current implementation, should pass functional tests, posses required
performance properties and rate limit. But no tests for concurrency yet

## Throttling

Throttling works by checking `erlang:process_info(message_queue_len)`. While
this is not perfectly reliable, and allow more than ten messages in queue
due to inherent raciness of check-perform pattern, it is cheap and does
not involve new potential bottleneck

## Registry bottleneck

Should not be a problem, as partitioning is supported out of the box.

## Wallet transactions

Only practical benefit from transaction commit/rollback mess here is fixing
potential deadlock in send:

- Process 1: A sends to B

- Process 1: Withdraw from A

- Process 2: deposits loads on money into A and B, almost to the cap

- Process 1: Cannot deposit to B, cannot return money to A

With two phases, returning money does not involve changing balance, so it cannot
be blocked by stuffing account - process 2 will fail when creating deposit transaction
for A.

Other way to fix that would be ensuring, that only one high-level transaction (ExBanking function)
is running over one account - for example by running them in worker processes, limited to 1 per
wallet. But two-phase payment is somewhat common pattern, so I decided to show it here.

## Float problem

Internally, all balances are kept as fixed-point decimal (represented by integer).
But API uses floating point numbers, which creates several problems.

### Precision loss

Erlang uses 64 bit floats, which have 53 significand bits, which translate to 15 significant
decimal positions. So, while balance can be arbitrarily large, at some point it cannot be
represented in API, leading to one of the following:

- corruption: `12345678901234567890` turns into `12345678901234567168`.
Which in my opinion is unacceptable.

- errors: too large balances either cause error, or are reported as some special value: `{imprecise, 12345678901234567168}`.

- balance cap: balance is capped at some maximum value: deposits/sends that would produce value outside of float range
return `{error, too_much_money}`.
Such change in API seems less dramatic, than changing number format, so it's what I done.

### Rounding

Decimal precision of two places is specified. That does not map cleanly to binary
places, so while large precision inconsistencies (like `deposit("foo", 0.126, "bar")`) can be
rejected with `:wrong_arguments`, small ones should be accepted, as they are artefacts of encoding.
