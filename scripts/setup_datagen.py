"""
Builds Layer 2: installs the DataGen engine onto an existing
database -- schema, helper functions, and Mode 1/2/3. Creates
the (empty) Mode 3 registry table (datagen.mode_3_resolution_map)
but does not populate it.

Run this against a database that already has your business
tables (either the simulated environment from 01_create_env.py,
or your own real tables). Run setup_candidates.py afterward to
enable Mode 3 against specific tables.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from core.demo_helpers import install_datagen_engine

if __name__ == "__main__":
    install_datagen_engine()
