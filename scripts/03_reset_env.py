import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from core.db import execute_sql_file

# Repo root -- one level up from scripts/03_reset_env.py. sql/
# lives at repo root, not inside scripts/.
PROJECT_ROOT = Path(__file__).resolve().parent.parent
RESET_FILE = PROJECT_ROOT / "sql" / "00_reset_all.sql"


if __name__ == "__main__":
    print("=== TESTOPS DATAGEN RESET START ===")

    print("[RESET]")
    execute_sql_file(RESET_FILE)
    print("Executed: 00_reset_all.sql")

    print("=== TESTOPS DATAGEN RESET COMPLETE ===")