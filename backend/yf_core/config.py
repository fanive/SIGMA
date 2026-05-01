from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "data"
DB_PATH = DATA_DIR / "market_data.db"
WATCHLIST_PATH = BASE_DIR / "watchlist.txt"

DEFAULT_HISTORY_PERIOD = "1mo"
DEFAULT_HISTORY_INTERVAL = "1d"
DEFAULT_SCHEDULE_MINUTES = 5

DATA_DIR.mkdir(parents=True, exist_ok=True)
