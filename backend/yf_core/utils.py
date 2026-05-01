from __future__ import annotations

from datetime import date, datetime
from typing import Any


def safe_float(value: Any, default: float = 0.0) -> float:
    if value is None:
        return default
    try:
        out = float(value)
    except (TypeError, ValueError):
        return default
    return default if out != out else out


def safe_json_value(value: Any) -> Any:
    if value is None:
        return None
    if isinstance(value, (str, int, float, bool)):
        return value
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    if isinstance(value, dict):
        return {str(k): safe_json_value(v) for k, v in value.items()}
    if isinstance(value, (list, tuple, set)):
        return [safe_json_value(v) for v in value]
    return str(value)
