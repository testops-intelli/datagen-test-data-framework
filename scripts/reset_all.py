from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path


def _load_reset_module():
    project_root = Path(__file__).resolve().parent
    reset_path = project_root / "03_reset_env.py"
    spec = spec_from_file_location("reset_env_module", reset_path)
    if spec is None or spec.loader is None:
        raise ImportError(f"Could not load module from {reset_path}")
    module = module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


if __name__ == "__main__":
    print("=== TESTOPS DATAGEN RESET START ===")

    reset_module = _load_reset_module()

    print("[RESET]")
    reset_module.execute_sql_file(reset_module.RESET_FILE)
    print("Executed: 00_reset_all.sql")

    print("=== TESTOPS DATAGEN RESET COMPLETE ===")
