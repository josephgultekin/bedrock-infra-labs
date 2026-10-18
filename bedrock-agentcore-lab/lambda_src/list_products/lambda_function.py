"""
list_products - AgentCore Gateway MCP tool, backed by Lambda.

Returns a small static product catalog. No external calls, no credentials -
this tool exists purely to prove the Gateway -> Lambda target wiring works.

NOTE: the exact event shape AgentCore Gateway sends to a Lambda target for an
inline MCP tool call hasn't been confirmed against a live invocation from
this sandbox. This handler defensively looks for tool arguments under a few
likely keys; check CloudWatch Logs after a real `tofu apply` + test call and
adjust `_extract_arguments` if the real shape differs.
"""

import json

CATALOG = [
    {"sku": "PICKUP-STD", "name": "Standard container pickup", "price_usd": 150.00},
    {"sku": "PICKUP-EXP", "name": "Expedited container pickup", "price_usd": 275.00},
    {"sku": "STORAGE-DAY", "name": "Per-day container storage", "price_usd": 25.00},
]


def _extract_arguments(event):
    if isinstance(event, dict):
        for key in ("arguments", "input", "parameters"):
            if key in event:
                return event[key]
    return event


def handler(event, context):
    arguments = _extract_arguments(event) or {}
    category = arguments.get("category") if isinstance(arguments, dict) else None

    products = CATALOG
    if category:
        products = [p for p in CATALOG if category.lower() in p["name"].lower()]

    return {"products": products}
