"""
Dexcom services removed.

This file previously contained integration logic with the pydexcom library to fetch
glucose readings. Dexcom integration has been intentionally removed; all glucose
data should now be sourced from HealthKit (client-side) and sent to the backend
via the unified glucose endpoints.

Keeping this stub prevents import errors from other modules while making it clear
that Dexcom functionality is no longer available.
"""

def dexcom_removed(*args, **kwargs):
    raise RuntimeError("Dexcom integration removed. Use HealthKit as the source of glucose data.")


class DexcomService:
    """Compatibility shim: preserve the DexcomService symbol so older imports don't crash.

    Any attempt to call methods on this shim will raise a RuntimeError indicating the
    integration was removed and pointing to the HealthKit/client-side flow.
    """
    def __init__(self, *args, **kwargs):
        raise RuntimeError("DexcomService is not available. Dexcom integration has been removed. Use HealthKit/client-side sync instead.")


