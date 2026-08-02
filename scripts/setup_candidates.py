"""
Builds Layer 3: candidates setup -- the one manual step a
DataGen user performs themselves. Curates candidates tables and
registers them in datagen.mode_3_resolution_map so Mode 3 can
resolve placeholders against them.

This script seeds the DEMO candidates tables/registrations
(for companies, securities, transactions) so the packaged repo
demo works out of the box. For your own tables, this is where
you'd instead build your own candidates table and INSERT your
own row into datagen.mode_3_resolution_map -- see the
"Registering a New Table for Mode 3" section in README.md.

Requires setup_datagen.py to have been run first (this depends
on datagen.mode_3_resolution_map already existing).
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from core.demo_helpers import setup_datagen_candidates

if __name__ == "__main__":
    setup_datagen_candidates()
