from __future__ import annotations

import json
import os
import time
from datetime import datetime, timezone


INTERVAL_SECONDS = float(
    os.getenv("WORKER_INTERVAL_SECONDS", "30")
)

ASSET_NAME = os.getenv(
    "WORKER_ASSET_NAME",
    "worker-simulator-001",
)


def build_heartbeat() -> dict[str, str]:
    """Construit un heartbeat simulé."""

    return {
        "type": "heartbeat",
        "asset": ASSET_NAME,
        "status": "ok",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


def main() -> None:
    print(
        f"Worker démarré pour {ASSET_NAME}, "
        f"intervalle={INTERVAL_SECONDS}s",
        flush=True,
    )

    while True:
        heartbeat = build_heartbeat()
        print(json.dumps(heartbeat), flush=True)
        time.sleep(INTERVAL_SECONDS)


if __name__ == "__main__":
    main()