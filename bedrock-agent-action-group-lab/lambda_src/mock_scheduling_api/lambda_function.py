"""
Stands in for the internal scheduling API from the exam scenario. Never
called directly by Bedrock - only ever invoked by booking_validator, and
only after validation passes. If you see this function's log group receive
an invocation for a request that should have been rejected, that's a sign
the validator let something bad through.
"""

import uuid


def handler(event, context):
    confirmation_id = f"CONF-{uuid.uuid4().hex[:8].upper()}"
    return {
        "confirmation_id": confirmation_id,
        "terminal_id": event["terminal_id"],
        "appointment_time": event["appointment_time"],
        "container_type": event["container_type"],
        "status": "CONFIRMED",
    }
