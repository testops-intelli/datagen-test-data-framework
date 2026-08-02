from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import psycopg2
from psycopg2 import sql

from .config import DB_CONFIG, MAINTENANCE_DB


def _build_connection_config(dbname: Optional[str] = None) -> Dict[str, object]:
    cfg = dict(DB_CONFIG)
    if dbname is not None:
        cfg["dbname"] = dbname
    return cfg


def get_connection(dbname: Optional[str] = None):
    return psycopg2.connect(**_build_connection_config(dbname))


def database_exists(dbname: str) -> bool:
    conn = get_connection(MAINTENANCE_DB)
    conn.autocommit = True
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT 1 FROM pg_database WHERE datname = %s;",
                (dbname,),
            )
            return cur.fetchone() is not None
    finally:
        conn.close()


def create_database_if_missing(dbname: str) -> bool:
    if database_exists(dbname):
        return False

    conn = get_connection(MAINTENANCE_DB)
    conn.autocommit = True
    try:
        with conn.cursor() as cur:
            cur.execute(
                sql.SQL("CREATE DATABASE {}").format(sql.Identifier(dbname))
            )
        return True
    finally:
        conn.close()


def execute_sql(sql_text: str, dbname: Optional[str] = None) -> None:
    conn = get_connection(dbname)
    conn.autocommit = True
    try:
        with conn.cursor() as cur:
            cur.execute(sql_text)
    finally:
        conn.close()


def execute_sql_file(file_path: Path, dbname: Optional[str] = None) -> None:
    with file_path.open("r", encoding="utf-8") as f:
        sql_text = f.read()
    execute_sql(sql_text, dbname=dbname)


def fetch_all(sql_text: str, dbname: Optional[str] = None) -> List[Tuple[Any, ...]]:
    conn = get_connection(dbname)
    conn.autocommit = True
    try:
        with conn.cursor() as cur:
            cur.execute(sql_text)
            return cur.fetchall()
    finally:
        conn.close()


def fetch_one(sql_text: str, dbname: Optional[str] = None) -> Optional[Tuple[Any, ...]]:
    conn = get_connection(dbname)
    conn.autocommit = True
    try:
        with conn.cursor() as cur:
            cur.execute(sql_text)
            return cur.fetchone()
    finally:
        conn.close()


def execute_and_fetch_all(
    sql_text: str,
    dbname: Optional[str] = None,
) -> Tuple[List[str], List[Tuple[Any, ...]]]:
    conn = get_connection(dbname)
    conn.autocommit = True
    try:
        with conn.cursor() as cur:
            cur.execute(sql_text)
            columns = [desc[0] for desc in cur.description] if cur.description else []
            rows = cur.fetchall() if cur.description else []
            return columns, rows
    finally:
        conn.close()


def call_then_fetch_all(
    call_sql: str,
    select_sql: str,
    dbname: Optional[str] = None,
) -> Tuple[List[str], List[Tuple[Any, ...]]]:
    """
    Runs a CALL statement and a subsequent SELECT in the SAME
    connection/session. Required whenever the CALL materializes
    a TEMP TABLE that the SELECT then reads -- TEMP TABLEs are
    only visible within the session that created them, so a
    fresh connection per statement (as execute_sql /
    execute_and_fetch_all do) would not see it.
    """
    conn = get_connection(dbname)
    conn.autocommit = True
    try:
        with conn.cursor() as cur:
            cur.execute(call_sql)
            cur.execute(select_sql)
            columns = [desc[0] for desc in cur.description] if cur.description else []
            rows = cur.fetchall() if cur.description else []
            return columns, rows
    finally:
        conn.close()