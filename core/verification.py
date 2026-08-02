from typing import Optional

from .db import fetch_one


def get_scalar_count(sql: str) -> int:
    row = fetch_one(sql)
    if row is None:
        return 0
    return int(row[0])


def table_exists(table_name: str) -> bool:
    sql = f"""
    SELECT EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_name = '{table_name}'
    );
    """
    row = fetch_one(sql)
    return bool(row[0]) if row else False