from __future__ import annotations

import logging
from typing import Iterable

from apscheduler.schedulers.blocking import BlockingScheduler
from apscheduler.triggers.interval import IntervalTrigger

from .collector import YFinanceCollector

LOGGER = logging.getLogger(__name__)


def run_scheduler(
    collector: YFinanceCollector,
    symbols: Iterable[str],
    history_period: str,
    history_interval: str,
    interval_minutes: int,
) -> None:
    scheduler = BlockingScheduler(timezone="UTC")

    def scheduled_job() -> None:
        LOGGER.info("Scheduled collection started")
        collector.collect_symbols(symbols, history_period=history_period, history_interval=history_interval)
        LOGGER.info("Scheduled collection finished")

    scheduler.add_job(
        scheduled_job,
        trigger=IntervalTrigger(minutes=interval_minutes),
        id="yfinance_collection",
        replace_existing=True,
        max_instances=1,
        coalesce=True,
    )

    LOGGER.info("Running initial collection before scheduler loop")
    scheduled_job()
    LOGGER.info("Scheduler active (every %s minutes)", interval_minutes)
    scheduler.start()
