import asyncio
import math
import time
from collections import defaultdict, deque


class InMemoryRateLimiter:
    """A small fixed-window limiter for a single service instance.

    This is a defense-in-depth limit. Multi-instance/serverless deployments
    should additionally enforce a shared limit at the edge or in Redis.
    """

    def __init__(self, *, requests: int, window_seconds: int) -> None:
        self._requests = requests
        self._window_seconds = window_seconds
        self._attempts: dict[str, deque[float]] = defaultdict(deque)
        self._lock = asyncio.Lock()

    async def check(self, identifier: str) -> int | None:
        now = time.monotonic()
        cutoff = now - self._window_seconds
        async with self._lock:
            attempts = self._attempts[identifier]
            while attempts and attempts[0] <= cutoff:
                attempts.popleft()
            if len(attempts) >= self._requests:
                return max(1, math.ceil(self._window_seconds - (now - attempts[0])))
            attempts.append(now)
            return None
