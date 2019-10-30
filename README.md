# ExBanking

https://coingaming.github.io/elixir-test/

THIS IS NOT FINAL VERSION

Minimal implementation, should pass functional tests, but it does not meet
performance requirements, as everything is done in single process.

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
