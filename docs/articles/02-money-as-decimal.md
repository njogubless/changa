# The missing cent: money as `Decimal`, not `float`

Here's a small experiment you can run in almost any programming language:

```python
>>> 0.1 + 0.2
0.30000000000000004
```

That's not a bug in Python — it's how binary floating-point numbers work. Computers store `0.1` the same way you'd store `1/3` in decimal: as an endless, repeating approximation, quietly rounded off somewhere past the digits you can see. Most of the time that rounding error is too small to notice. In a system that sums up thousands of contributions and needs the total to match, to the cent, what Safaricom's settlement report says — it isn't too small to notice. It's the whole problem.

Changa stored every monetary value — a project's target, how much it had raised, each individual contribution — as `Float`, which becomes a PostgreSQL `DOUBLE PRECISION` column. Every contribution added to a project's running total compounded a tiny bit more representation error. The order contributions arrived in could even change the final total. And separately, the M-Pesa integration sent `int(amount)` to Safaricom's API — which doesn't round, it just chops off anything after the decimal point. A member contributing KES 100.75 got charged KES 100 by M-Pesa, while Changa's own database still said 100.75. Two systems, two numbers, no way to reconcile them, for every single non-whole-number contribution.

## What we changed

The fix has one rule: **represent money as an exact decimal, everywhere, and never let a fractional amount reach a payment provider.**

- Every monetary column became `NUMERIC(14,2)` in Postgres and `Decimal` in Python — an exact, base-10 number type built for exactly this, instead of a binary approximation.
- We added one conversion function, `to_money()`, used everywhere a number becomes money. It matters *how* you build a `Decimal`: `Decimal(0.1)` still imports the same floating-point error you were trying to escape, because it starts from the already-imprecise float. `Decimal(str(0.1))` doesn't — it starts from the decimal text `"0.1"` and reads it exactly. One easy-to-get-wrong line, centralized in one place instead of repeated (and eventually mis-copied) at every call site.
- We stopped truncating money to talk to a payment provider. If an amount would require sending sub-cent precision the provider can't accept, the request is rejected up front with a clear error, instead of being silently rounded away.

## How we knew it worked

Beyond the migration-verification loop described in the schema truth article, this one needed a functional check specifically for the arithmetic: seed contributions with awkward decimal amounts, sum them through the API, and confirm the total matches what you'd get adding the numbers by hand — not what floating point would produce. We also had to update every schema that serialized money over JSON, since a `Decimal` needs an explicit, deliberate serialization rule or it'll either come out as a float again (reintroducing the exact bug we fixed) or as a string the client isn't expecting.

**The lesson:** floating point is for physics simulations and graphics, not ledgers. If your total has to match someone else's — a bank, a provider, a member checking their own math — use a number type built to be exact, and control precisely how values enter and leave it.
