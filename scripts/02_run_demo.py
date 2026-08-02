import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from core.config import (
    DEMO_SCHEMA,
    DEMO_TABLE,
    MODE_2_MULTIPLIER,
    MODE_3_MULTIPLIER,
)
from core.db import call_then_fetch_all, execute_and_fetch_all
from core.demo_helpers import print_section
from core.export import export_rows_to_xlsx


def run_mode_1_demo() -> None:
    print_section("MODE 1 SAMPLE")
    print("Generating the deterministic structural param space (placeholders for the rest).")

    columns, rows = call_then_fetch_all(
        f"CALL datagen.materialize_mode_1_with_placeholders('{DEMO_SCHEMA}', '{DEMO_TABLE}');",
        "SELECT * FROM datagen_mode_1_with_placeholders;",
    )
    print("Row count:", len(rows))
    print("Columns:", columns)
    for row in rows:
        print(row)

    out_path = export_rows_to_xlsx(columns, rows, "mode_1_output.xlsx", "Mode 1")
    print(f"Exported: {out_path}")


def run_mode_2_demo() -> None:
    print_section("MODE 2 SAMPLE")
    print(f"Resolving placeholders from historical data, multiplier={MODE_2_MULTIPLIER}.")

    columns, rows = call_then_fetch_all(
        f"CALL datagen.materialize_mode_2('{DEMO_SCHEMA}', '{DEMO_TABLE}', {MODE_2_MULTIPLIER});",
        "SELECT * FROM datagen_mode_2_output;",
    )
    print("Row count:", len(rows))
    print("Columns:", columns)
    for row in rows[:10]:
        print(row)
    if len(rows) > 10:
        print(f"... ({len(rows) - 10} more rows)")

    out_path = export_rows_to_xlsx(columns, rows, "mode_2_output.xlsx", "Mode 2")
    print(f"Exported: {out_path}")


def run_mode_3_demo() -> None:
    print_section("MODE 3 SAMPLE")
    print(f"Resolving placeholders from the registered candidates table, multiplier={MODE_3_MULTIPLIER}.")

    registry_sql = f"""
    SELECT candidates_schema_name, candidates_table_name, placeholder_columns_json
    FROM datagen.mode_3_resolution_map
    WHERE target_schema_name = '{DEMO_SCHEMA}'
      AND target_table_name  = '{DEMO_TABLE}'
      AND is_active;
    """
    _, registry_rows = execute_and_fetch_all(registry_sql)
    for cand_schema, cand_table, placeholder_cols in registry_rows:
        print(f"Registered candidates table: {cand_schema}.{cand_table}")
        print(f"Resolving columns: {placeholder_cols}")

    columns, rows = call_then_fetch_all(
        f"CALL datagen.materialize_mode_3('{DEMO_SCHEMA}', '{DEMO_TABLE}', {MODE_3_MULTIPLIER});",
        "SELECT * FROM datagen_mode_3_output;",
    )
    print("Row count:", len(rows))
    print("Columns:", columns)
    for row in rows[:10]:
        print(row)
    if len(rows) > 10:
        print(f"... ({len(rows) - 10} more rows)")

    out_path = export_rows_to_xlsx(columns, rows, "mode_3_output.xlsx", "Mode 3")
    print(f"Exported: {out_path}")


if __name__ == "__main__":
    print("=== TESTOPS DATAGEN DEMO START ===")
    run_mode_1_demo()
    run_mode_2_demo()
    run_mode_3_demo()
    print("=== TESTOPS DATAGEN DEMO COMPLETE ===")
