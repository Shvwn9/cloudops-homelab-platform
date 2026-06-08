from app.worker.simulator import build_heartbeat


def test_build_heartbeat() -> None:
    heartbeat = build_heartbeat()

    assert heartbeat["type"] == "heartbeat"
    assert heartbeat["status"] == "ok"
    assert heartbeat["asset"]
    assert heartbeat["timestamp"]