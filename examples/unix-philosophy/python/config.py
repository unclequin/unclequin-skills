import os


def port_silent():
    # Silent failure: falls back without telling anyone
    port = int(os.environ.get("PORT", "0"))
    return port


def port_or_exit():
    # Fail fast at startup (or validate all config with pydantic-settings)
    try:
        port = int(os.environ["PORT"])
    except (KeyError, ValueError) as e:
        raise SystemExit(f"invalid PORT: {os.environ.get('PORT')!r}") from e
    return port
