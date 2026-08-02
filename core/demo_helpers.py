from pathlib import Path
from typing import Iterable

from .config import (
    BUSINESS_ENV_SQL_SEQUENCE,
    CANDIDATES_SQL_SEQUENCE,
    DATAGEN_ENGINE_SQL_SEQUENCE,
    DB_CONFIG,
)
from .db import create_database_if_missing, execute_sql_file

# Repo root -- two levels up from core/demo_helpers.py. sql/ lives
# at repo root, not inside core/.
PROJECT_ROOT = Path(__file__).resolve().parent.parent
SQL_DIR = PROJECT_ROOT / "sql"


def print_section(title: str) -> None:
    print(f"=== {title} ===")


def print_substep(message: str) -> None:
    print(message)


def run_sql_sequence(file_names: Iterable[str]) -> None:
    for file_name in file_names:
        file_path = SQL_DIR / file_name
        execute_sql_file(file_path)
        print(f"Executed: {file_name}")


def ensure_demo_database() -> None:
    dbname = str(DB_CONFIG["dbname"])
    print("[DB SETUP] Ensuring demo database exists")
    if create_database_if_missing(dbname):
        print(f"✔ Database created: {dbname}")
    else:
        print(f"✔ Database already exists: {dbname}")


def build_business_environment(reset_first: bool = True) -> None:
    """
    Layer 1: simulates a pre-existing customer database -- the
    tables and historical data a real user would already have,
    with zero DataGen involvement.
    """
    print("=== TESTOPS DATAGEN BUSINESS ENV BUILD START ===")
    print(
        "[CONFIG]\n"
        f"  Host    : {DB_CONFIG['host']}\n"
        f"  Port    : {DB_CONFIG['port']}\n"
        f"  User    : {DB_CONFIG['user']}\n"
        f"  Database: {DB_CONFIG['dbname']}"
    )

    ensure_demo_database()

    if reset_first:
        print_section("RESET")
        execute_sql_file(SQL_DIR / "00_reset_all.sql")
        print("Executed: 00_reset_all.sql")

    print_section("BUSINESS ENVIRONMENT")
    run_sql_sequence(BUSINESS_ENV_SQL_SEQUENCE)

    print("=== TESTOPS DATAGEN BUSINESS ENV BUILD COMPLETE ===")


def install_datagen_engine() -> None:
    """
    Layer 2: installs the DataGen engine onto an existing
    database -- schema, helper functions, and all three modes.
    Creates the (empty) Mode 3 registry table; does not
    populate it with candidates.
    """
    print("=== TESTOPS DATAGEN ENGINE INSTALL START ===")
    print_section("DATAGEN ENGINE")
    run_sql_sequence(DATAGEN_ENGINE_SQL_SEQUENCE)
    print("=== TESTOPS DATAGEN ENGINE INSTALL COMPLETE ===")


def setup_datagen_candidates() -> None:
    """
    Layer 3: the one manual step a DataGen user performs
    themselves -- curate candidates tables and register them
    in datagen.mode_3_resolution_map for Mode 3 to use.
    """
    print("=== TESTOPS DATAGEN CANDIDATES SETUP START ===")
    print_section("CANDIDATES")
    run_sql_sequence(CANDIDATES_SQL_SEQUENCE)
    print("=== TESTOPS DATAGEN CANDIDATES SETUP COMPLETE ===")


def run_full_env_build() -> None:
    """
    Convenience wrapper chaining all three layers -- used by the
    packaged repo demo (run_all.py) so a single command still
    stands the whole thing up end to end. Each layer above can
    also be run independently.
    """
    build_business_environment(reset_first=True)
    install_datagen_engine()
    setup_datagen_candidates()