"""Offline adapter fixture: soft-target cross entropy updates a Bernoulli policy."""
import json
import math
import pathlib
import sys
import time

stage, source, destination = sys.argv[1:]
request = json.loads(pathlib.Path(source).read_text())
result = {"request_id": request["request_id"]}
if stage == "train_fail_once":
    marker = pathlib.Path(source).parent.parent / "failed-once"
    if not marker.exists():
        marker.write_text("failed")
        sys.exit(7)
    stage = "train"
if stage == "train_cancel":
    (pathlib.Path(source).parent.parent / "training-entered").write_text("entered")
    time.sleep(2)
    (pathlib.Path(source).parent.parent / "late-mutation").write_text("wrong")
    stage = "train"
if stage == "train_reset_env":
    (pathlib.Path(source).parent.parent / "world.json").write_text('{"cursor":88}')
    stage = "train"
if stage == "score":
    result["scores"] = [{"id": t["id"], "reward": 0.0} for t in request["transitions"]]
elif stage == "teacher":
    result["targets"] = [
        {"window_id": w["id"], "context": "choose action one", "positions": [
            {"token_ids": [0, 1], "probabilities": [0.1, 0.9]}]}
        for w in request["windows"]
    ]
elif stage == "train":
    model = json.loads(pathlib.Path(request["checkpoint"]).read_text())
    weight = model["weight"]
    positions = [p for target in request["targets"] for p in target["positions"]]
    target = sum(dict(zip(p["token_ids"], p["probabilities"])).get(1, 0) for p in positions) / len(positions)
    for _ in range(8):
        prediction = 1 / (1 + math.exp(-weight))
        weight -= 0.5 * (prediction - target)
    pathlib.Path(request["output_checkpoint"]).write_text(json.dumps({"weight": weight}))
    result["checkpoint"] = request["output_checkpoint"]
    result["objective"] = "soft_sft"
elif stage == "activate":
    result["model"] = "mock/" + request["checkpoint"]
    result["checkpoint_sha256"] = request["checkpoint_sha256"]
else:
    raise ValueError(stage)
pathlib.Path(destination).write_text(json.dumps(result))
