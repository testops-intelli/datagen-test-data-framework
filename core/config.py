import os
from pathlib import Path
from typing import Dict


# Repo root -- two levels up from core/config.py (core/ -> repo root).
# .env lives at repo root by convention, regardless of where the
# Python modules that read it live.
PROJECT_ROOT = Path(__file__).resolve().parent.parent
ENV_FILE = PROJECT_ROOT / ".env"


def _load_env_file() -> None:
    if not ENV_FILE.exists():
        return

    for raw_line in ENV_FILE.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()

        if not line or line.startswith("#") or "=" not in line:
            continue

        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")

        if key and key not in os.environ:
            os.environ[key] = value


def _get_env(name: str, default: str) -> str:
    value = os.getenv(name, default)
    return value.strip() if isinstance(value, str) else value


def _get_env_int(name: str, default: int) -> int:
    raw = _get_env(name, str(default))
    try:
        return int(raw)
    except ValueError as exc:
        raise ValueError(f"Invalid integer for {name}: {raw}") from exc


_load_env_file()

DB_CONFIG: Dict[str, object] = {
    "host": _get_env("PG_HOST", "localhost"),
    "port": _get_env_int("PG_PORT", 5432),
    "dbname": _get_env("PG_DATABASE", "datagen_demo"),
    "user": _get_env("PG_USER", "postgres"),
    "password": _get_env("PG_PASSWORD", ""),
}

MAINTENANCE_DB = "postgres"

DEMO_SCHEMA = _get_env("DEMO_SCHEMA", "public")
DEMO_TABLE = _get_env("DEMO_TABLE", "transactions")

# Multiplier passed to Mode 2 / Mode 3 -- how many passes of the
# base param space to generate. Each pass is resolved with the
# next distinct historical tuple (Mode 2) or candidate row
# (Mode 3). Capped automatically at however many distinct
# tuples/rows actually exist -- no repeats.
MODE_2_MULTIPLIER = _get_env_int("MODE_2_MULTIPLIER", 2)
MODE_3_MULTIPLIER = _get_env_int("MODE_3_MULTIPLIER", 2)

# Directory where exported .xlsx files are written.
EXPORT_DIR = PROJECT_ROOT / _get_env("EXPORT_DIR", "outputs")

SQL_SEQUENCE = [
    "00_reset_all.sql",
    "01_schema.sql",
    "02_seed_demo_data.sql",
    "03_core_helpers.sql",
    "04_mode_1.sql",
    "05_mode_2.sql",
    "06_mode_3.sql",
    "07_seed_candidates_demo.sql",
    "08_seed_candidates_companies_securities.sql",
]

# Layer 1: the pre-existing business environment -- what a real
# customer's database already looks like, with zero DataGen
# involvement. Tables + their historical data only.
BUSINESS_ENV_SQL_SEQUENCE = [
    "01_schema.sql",
    "02_seed_demo_data.sql",
]

# Layer 2: installing the DataGen engine onto that database --
# schema, helper functions, and all three modes. Creates the
# (empty) Mode 3 registry table, but does not populate it.
DATAGEN_ENGINE_SQL_SEQUENCE = [
    "03_core_helpers.sql",
    "04_mode_1.sql",
    "05_mode_2.sql",
    "06_mode_3.sql",
]

# Layer 3: candidates setup -- the one manual step a DataGen user
# performs themselves: curate candidates tables and register them
# for Mode 3. Kept separate from engine install on purpose.
CANDIDATES_SQL_SEQUENCE = [
    "07_seed_candidates_demo.sql",
    "08_seed_candidates_companies_securities.sql",
]

# Retained for backward compatibility / single-file reruns.
CORE_SQL_SEQUENCE = BUSINESS_ENV_SQL_SEQUENCE + ["03_core_helpers.sql"]

MODE_1_SQL_SEQUENCE = [
    "04_mode_1.sql",
]

MODE_2_SQL_SEQUENCE = [
    "05_mode_2.sql",
]

MODE_3_SQL_SEQUENCE = [
    "06_mode_3.sql",
]