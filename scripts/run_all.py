import sys
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from core.demo_helpers import run_full_env_build


def _load_run_demo_module():
    project_root = Path(__file__).resolve().parent
    run_demo_path = project_root / "02_run_demo.py"
    spec = spec_from_file_location("run_demo_module", run_demo_path)
    if spec is None or spec.loader is None:
        raise ImportError(f"Could not load module from {run_demo_path}")
    module = module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


if __name__ == "__main__":
    print("=== TESTOPS DATAGEN RUN_ALL START ===")

    run_full_env_build()

    print("\n=== TESTOPS DATAGEN DEMO START ===")
    run_demo = _load_run_demo_module()
    run_demo.run_mode_1_demo()
    run_demo.run_mode_2_demo()
    run_demo.run_mode_3_demo()
    print("=== TESTOPS DATAGEN DEMO COMPLETE ===")

    print("\n✔ Demo completed successfully")
    print("=== TESTOPS DATAGEN RUN_ALL COMPLETE ===")