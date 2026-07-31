"""Exact decimal money handling.

IEEE-754 floats cannot represent most decimal fractions exactly, so
accumulating floats (`raised_amount += amount` across thousands of
contributions) drifts from the true sum and the drift is not reproducible
across summation order. Every monetary value in this application is
represented as `Decimal` in Python and `NUMERIC(14, 2)` in Postgres — never
`float` / `Float` / `Double`. See docs/Changa_Engineering_audit.md, FIN-01.
"""
from decimal import Decimal, ROUND_HALF_UP, InvalidOperation
from sqlalchemy import Numeric

# Exact, up to 999,999,999,999.99 — matches KES amounts with room to spare.
MoneyColumn = Numeric(14, 2)

CENT = Decimal("0.01")
ZERO = Decimal("0.00")


def to_money(value) -> Decimal:
    """Coerce any numeric input to an exact, 2-decimal-place Decimal.

    Never route a value through `float` on the way in — construct the
    Decimal from a string (or an existing Decimal/int) so no binary
    floating-point rounding error is introduced before it ever reaches
    the database.
    """
    if isinstance(value, Decimal):
        d = value
    elif isinstance(value, int):
        d = Decimal(value)
    else:
        # str(value) first: Decimal(0.1) would faithfully encode the binary
        # float's error; Decimal(str(0.1)) == Decimal("0.1").
        d = Decimal(str(value))

    try:
        return d.quantize(CENT, rounding=ROUND_HALF_UP)
    except InvalidOperation as exc:
        raise ValueError(f"{value!r} is not a valid monetary amount") from exc


class ProviderPrecisionError(ValueError):
    """Raised when an amount cannot be represented in a provider's units."""


def is_whole_currency_unit(amount: Decimal) -> bool:
    """True if `amount` has no sub-unit (cents) component.

    M-Pesa's STK Push and the Airtel Money disbursement API both only
    accept whole-shilling amounts — reject fractional amounts at the
    boundary instead of silently truncating them (the previous behaviour:
    `int(amount)` quietly discarded cents, so a KES 100.75 contribution was
    requested from the provider as KES 100 while the ledger recorded
    100.75, guaranteeing a permanent, unreconcilable discrepancy).
    """
    return amount == amount.to_integral_value()
