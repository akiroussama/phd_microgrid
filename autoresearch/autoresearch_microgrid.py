"""
AutoResearch Microgrid Agent
============================
Autonomous EMS parameter discovery for Prattico microgrid model.

Loop: Read FIS -> Claude proposes change -> Apply -> Simulate -> Score -> Keep/Revert

Usage:
    python autoresearch_microgrid.py                 # run 500 experiments (default)
    python autoresearch_microgrid.py --max-iter 50   # run 50 experiments
    python autoresearch_microgrid.py --dry-run        # propose changes without simulating
"""

import argparse
import csv
import json
import os
import shutil
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

import anthropic

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
CONFIG_PATH = SCRIPT_DIR / "config.json"
LOG_DIR = SCRIPT_DIR / "logs"
LOG_CSV = LOG_DIR / "experiment_log.csv"

# ---------------------------------------------------------------------------
# Load config
# ---------------------------------------------------------------------------

def load_config() -> dict:
    with open(CONFIG_PATH, "r") as f:
        return json.load(f)


# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------

LOG_FIELDS = [
    "experiment_id",
    "timestamp",
    "description",
    "file_modified",
    "DeltaV_max",
    "SOC_in_range_pct",
    "daily_cost_eur",
    "self_consumption_pct",
    "safety_violations",
    "score",
    "accepted",
    "duration_s",
    "error",
]


def init_log():
    """Create the CSV log file with headers if it does not exist."""
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    if not LOG_CSV.exists():
        with open(LOG_CSV, "w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=LOG_FIELDS)
            writer.writeheader()


def append_log(row: dict):
    with open(LOG_CSV, "a", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=LOG_FIELDS)
        writer.writerow(row)


# ---------------------------------------------------------------------------
# Backup / restore
# ---------------------------------------------------------------------------

def backup_file(filepath: Path) -> Path:
    """Copy filepath to filepath.bak. Returns backup path."""
    bak = filepath.with_suffix(filepath.suffix + ".bak")
    shutil.copy2(filepath, bak)
    return bak


def restore_file(filepath: Path):
    """Restore filepath from its .bak copy."""
    bak = filepath.with_suffix(filepath.suffix + ".bak")
    if bak.exists():
        shutil.copy2(bak, filepath)
    else:
        raise FileNotFoundError(f"Backup not found: {bak}")


# ---------------------------------------------------------------------------
# Read current FIS source
# ---------------------------------------------------------------------------

def read_fis_source(config: dict) -> str:
    """Read the main FIS .m file and return its content."""
    fis_path = PROJECT_ROOT / config["modifiable_files"][0]
    with open(fis_path, "r") as f:
        return f.read()


# ---------------------------------------------------------------------------
# Claude API: propose ONE modification
# ---------------------------------------------------------------------------

SYSTEM_PROMPT = """\
You are an EMS parameter tuning expert for a Prattico microgrid Simscape model.

Your job: propose exactly ONE small parametric modification to the FIS file.

Allowed modifications (pick ONE per call):
- Change membership function vertices (the numeric triplets in fis.inputs/outputs .mfs)
- Shift SOC thresholds (e.g. Low upper bound from 45 to 50)
- Change DeltaP breakpoints
- Adjust Tariff breakpoints
- Modify a rule output (change which MF index a rule maps to)

Rules you MUST follow:
- ONE change only. Never modify more than one parameter group at a time.
- Keep values within physical bounds (SOC 0-100, DeltaP -150..150, Tariff 0.05..0.15).
- MF vertices must stay sorted (a <= b <= c for triangular).
- Return your answer as a JSON object with these exact keys:
  {
    "description": "human-readable explanation of the change",
    "file": "relative path to the file being modified",
    "old_text": "exact text to find and replace (copy-paste from the source)",
    "new_text": "replacement text"
  }
- The old_text must be an EXACT substring of the current file content.
- Return ONLY the JSON object. No markdown fences, no commentary.
"""


def propose_modification(
    fis_source: str,
    config: dict,
    history_summary: str,
    client: anthropic.Anthropic,
) -> dict:
    """Ask Claude to propose one parametric change. Returns parsed JSON."""

    user_msg = (
        "Here is the current FIS source code:\n\n"
        f"```matlab\n{fis_source}\n```\n\n"
        f"Parameter bounds:\n{json.dumps(config['parameter_bounds'], indent=2)}\n\n"
        f"Score weights (higher is better):\n{json.dumps(config['score_weights'], indent=2)}\n\n"
        f"Recent experiment history:\n{history_summary}\n\n"
        "Propose ONE modification to improve the overall score."
    )

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=1024,
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": user_msg}],
    )

    raw = response.content[0].text.strip()

    # Strip markdown fences if Claude added them despite instructions
    if raw.startswith("```"):
        raw = raw.split("\n", 1)[1]
    if raw.endswith("```"):
        raw = raw.rsplit("\n", 1)[0]

    return json.loads(raw)


# ---------------------------------------------------------------------------
# Apply modification via text replacement
# ---------------------------------------------------------------------------

def apply_modification(mod: dict) -> Path:
    """Apply a find-and-replace modification. Returns the modified file path."""
    filepath = PROJECT_ROOT / mod["file"]
    if not filepath.exists():
        raise FileNotFoundError(f"Target file not found: {filepath}")

    content = filepath.read_text()
    if mod["old_text"] not in content:
        raise ValueError(
            f"old_text not found in {filepath}. "
            "Claude may have hallucinated the text. Skipping."
        )

    new_content = content.replace(mod["old_text"], mod["new_text"], 1)
    filepath.write_text(new_content)
    return filepath


# ---------------------------------------------------------------------------
# Run MATLAB simulation
# ---------------------------------------------------------------------------

def run_simulation(config: dict) -> dict:
    """
    Launch MATLAB in batch mode, run the simulation, read results CSV.
    Returns a dict of metric values or raises on failure.
    """
    matlab = config["matlab_path"]
    batch_cmd = config["matlab_batch_cmd"]
    timeout = config["timeout_seconds"]

    cmd = [matlab, "-batch", batch_cmd]

    result = subprocess.run(
        cmd,
        cwd=str(PROJECT_ROOT),
        capture_output=True,
        text=True,
        timeout=timeout,
    )

    if result.returncode != 0:
        raise RuntimeError(
            f"MATLAB exited with code {result.returncode}.\n"
            f"STDERR:\n{result.stderr[-500:]}"
        )

    return read_results(config)


def read_results(config: dict) -> dict:
    """Read the last row of the results CSV produced by evaluate_experiment.m."""
    csv_path = PROJECT_ROOT / config["results_csv"]
    if not csv_path.exists():
        raise FileNotFoundError(f"Results CSV not found: {csv_path}")

    with open(csv_path, "r") as f:
        reader = csv.DictReader(f)
        rows = list(reader)

    if not rows:
        raise ValueError("Results CSV is empty.")

    last = rows[-1]
    return {
        "DeltaV_max": float(last.get("DeltaV_max", 0)),
        "SOC_in_range_pct": float(last.get("SOC_in_range_pct", 0)),
        "daily_cost_eur": float(last.get("daily_cost_eur", 0)),
        "self_consumption_pct": float(last.get("self_consumption_pct", 0)),
        "safety_violations": int(float(last.get("safety_violations", 0))),
    }


# ---------------------------------------------------------------------------
# Scoring
# ---------------------------------------------------------------------------

def compute_score(metrics: dict, weights: dict) -> float:
    """Weighted sum of metrics. Higher = better."""
    score = 0.0
    for key, w in weights.items():
        score += w * metrics.get(key, 0)
    return score


# ---------------------------------------------------------------------------
# History summary (last N experiments for Claude context)
# ---------------------------------------------------------------------------

def get_history_summary(n: int = 10) -> str:
    """Return a short text summary of the last N experiments."""
    if not LOG_CSV.exists():
        return "No experiments yet."

    with open(LOG_CSV, "r") as f:
        reader = csv.DictReader(f)
        rows = list(reader)

    if not rows:
        return "No experiments yet."

    recent = rows[-n:]
    lines = []
    for r in recent:
        accepted = "KEPT" if r.get("accepted") == "True" else "REVERTED"
        lines.append(
            f"  #{r['experiment_id']} | score={r.get('score','?')} | "
            f"{accepted} | {r.get('description','')}"
        )
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

def run_agent(max_iter: int, dry_run: bool = False):
    config = load_config()
    weights = config["score_weights"]
    init_log()

    client = anthropic.Anthropic()  # uses ANTHROPIC_API_KEY env var

    # Determine starting experiment ID from existing log
    start_id = 1
    if LOG_CSV.exists():
        with open(LOG_CSV, "r") as f:
            reader = csv.DictReader(f)
            ids = [int(r["experiment_id"]) for r in reader if r["experiment_id"].isdigit()]
            if ids:
                start_id = max(ids) + 1

    best_score = float("-inf")
    print(f"=== AutoResearch Agent ===")
    print(f"  Max iterations : {max_iter}")
    print(f"  Dry run        : {dry_run}")
    print(f"  Starting at    : experiment #{start_id}")
    print(f"  Log file       : {LOG_CSV}")
    print()

    for i in range(max_iter):
        exp_id = start_id + i
        t0 = time.time()
        log_row = {
            "experiment_id": exp_id,
            "timestamp": datetime.now().isoformat(timespec="seconds"),
            "accepted": False,
            "error": "",
        }

        try:
            # 1. Read current FIS
            fis_source = read_fis_source(config)

            # 2. Ask Claude for one modification
            history = get_history_summary()
            mod = propose_modification(fis_source, config, history, client)
            log_row["description"] = mod.get("description", "")
            log_row["file_modified"] = mod.get("file", "")
            print(f"[{exp_id}] Proposed: {mod.get('description', '???')}")

            if dry_run:
                print(f"  [DRY RUN] old_text: {mod['old_text'][:80]}...")
                print(f"  [DRY RUN] new_text: {mod['new_text'][:80]}...")
                log_row["error"] = "dry_run"
                log_row["duration_s"] = round(time.time() - t0, 1)
                append_log(log_row)
                continue

            # 3. Backup + apply
            target = PROJECT_ROOT / mod["file"]
            backup_file(target)
            apply_modification(mod)

            # 4. Simulate
            print(f"  Running MATLAB simulation (timeout {config['timeout_seconds']}s)...")
            metrics = run_simulation(config)

            # 5. Score
            score = compute_score(metrics, weights)
            log_row.update(metrics)
            log_row["score"] = round(score, 4)
            print(f"  Score: {score:.4f}  (best so far: {best_score:.4f})")

            # 6. Keep or revert
            if score > best_score:
                best_score = score
                log_row["accepted"] = True
                print(f"  -> KEPT (new best)")
            else:
                restore_file(target)
                log_row["accepted"] = False
                print(f"  -> REVERTED")

        except json.JSONDecodeError as e:
            log_row["error"] = f"JSON parse error: {e}"
            print(f"  ERROR: Bad JSON from Claude: {e}")
        except subprocess.TimeoutExpired:
            log_row["error"] = "MATLAB timeout"
            print(f"  ERROR: MATLAB timed out")
            # Revert on timeout
            try:
                restore_file(PROJECT_ROOT / mod["file"])
            except Exception:
                pass
        except Exception as e:
            log_row["error"] = str(e)[:200]
            print(f"  ERROR: {e}")
            # Revert on any error
            try:
                restore_file(PROJECT_ROOT / mod["file"])
            except Exception:
                pass

        log_row["duration_s"] = round(time.time() - t0, 1)
        append_log(log_row)
        print()

    # Final summary
    print("=" * 50)
    print(f"Completed {max_iter} experiments.")
    print(f"Best score: {best_score:.4f}")
    print(f"Log: {LOG_CSV}")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="AutoResearch Microgrid Agent")
    parser.add_argument(
        "--max-iter",
        type=int,
        default=None,
        help="Number of experiments to run (default: from config.json)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Propose changes but do not simulate",
    )
    args = parser.parse_args()

    config = load_config()
    max_iter = args.max_iter if args.max_iter is not None else config["max_experiments"]

    run_agent(max_iter=max_iter, dry_run=args.dry_run)


if __name__ == "__main__":
    main()
