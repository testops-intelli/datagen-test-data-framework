from pathlib import Path
import shutil

# Repo root -- one level up from scripts/00_init_env.py. .env and
# .env.example live at repo root, not inside scripts/.
PROJECT_ROOT = Path(__file__).resolve().parent.parent
ENV_FILE = PROJECT_ROOT / ".env"
ENV_EXAMPLE_FILE = PROJECT_ROOT / ".env.example"


def main() -> None:
    print("=== TESTOPS DATAGEN ENV INIT START ===")

    if not ENV_EXAMPLE_FILE.exists():
        raise FileNotFoundError(f"Missing required template: {ENV_EXAMPLE_FILE.name}")

    if ENV_FILE.exists():
        print("✔ .env already exists")
    else:
        shutil.copyfile(ENV_EXAMPLE_FILE, ENV_FILE)
        print("✔ Created .env from .env.example")

    print("→ Next step:")
    print("  1. Open .env")
    print("  2. Set PG_PASSWORD")
    print("  3. Optionally change PG_DATABASE (recommended: keep default)")
    print("  4. Run: python scripts/run_all.py")
    print("=== TESTOPS DATAGEN ENV INIT COMPLETE ===")


if __name__ == "__main__":
    main()