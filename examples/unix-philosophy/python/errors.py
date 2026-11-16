import httpx


class OrderFetchError(RuntimeError):
    pass


def fetch_order(order_id):
    if order_id == "missing":
        raise httpx.ConnectError("connection refused")
    return {"id": order_id}


def fetch_opaque(order_id):
    order = None
    # Opaque and silent
    try:
        order = fetch_order(order_id)
    except Exception:
        pass
    return order


def fetch_transparent(order_id):
    # Transparent: specific exception, context, original cause kept
    try:
        order = fetch_order(order_id)
    except httpx.HTTPError as e:
        raise OrderFetchError(f"fetch order {order_id}") from e
    return order
