import random
import unittest

from orders import Order, YearMonth, revenue_by_month, revenue_by_month_spec


def random_orders(rng: random.Random) -> list[Order]:
    return [
        Order(
            id=str(i),
            total=rng.randrange(1000),
            paid_in=YearMonth(2024 + rng.randrange(2), 1 + rng.randrange(12))
            if rng.randrange(3) > 0
            else None,
            refunded=rng.randrange(4) == 0,
        )
        for i in range(rng.randrange(20))
    ]


class SeededProperties(unittest.TestCase):
    def test_derived_equals_spec(self):
        rng = random.Random(42)
        for case in range(1000):
            orders = random_orders(rng)  # small totals, two years, some unpaid
            self.assertEqual(revenue_by_month(orders, 2024), revenue_by_month_spec(orders, 2024), f"case {case}")
