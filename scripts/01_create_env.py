"""
Builds Layer 1 only: the pre-existing business environment
(companies, securities, transactions tables + historical data).
Simulates what a real customer database looks like before
DataGen is ever installed -- no DataGen schema, functions, or
candidates are touched here.

Run setup_datagen.py next to install the engine, then
setup_candidates.py to enable Mode 3.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from core.demo_helpers import build_business_environment

if __name__ == "__main__":
    build_business_environment()
