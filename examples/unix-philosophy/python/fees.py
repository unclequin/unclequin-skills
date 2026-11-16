SHIPPING_FEES = {"BKK": 40, "CENTRAL": 60, "NORTH": 80}


def shipping_fee(zone: str) -> int:
    return SHIPPING_FEES.get(zone, 100)
