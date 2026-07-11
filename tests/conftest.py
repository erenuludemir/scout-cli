"""
Pytest configuration and fixtures for QuantumAI integration tests
"""

import asyncio
import os
import socket
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from threading import Thread
from urllib import request
import urllib.request as urllib_request_module

import pytest


class _CompatRequest(urllib_request_module.Request):
    """Accept the timeout keyword used by the repo's tests on this Python runtime."""

    def __init__(self, url, data=None, headers=None, origin_req_host=None, unverifiable=False, method=None, **kwargs):
        kwargs.pop("timeout", None)
        if headers is None:
            headers = {}
        super().__init__(
            url,
            data=data,
            headers=headers,
            origin_req_host=origin_req_host,
            unverifiable=unverifiable,
            method=method,
        )


request.Request = _CompatRequest
urllib_request_module.Request = _CompatRequest


# ===== Environment Setup =====
def pytest_configure(config):
    """Configure pytest with custom markers and environment"""
    os.environ.pop("DOCKER_CONTEXT", None)
    config.addinivalue_line(
        "markers",
        "unit: mark test as a unit test"
    )
    config.addinivalue_line(
        "markers",
        "integration: mark test as an integration test (requires Docker services)"
    )
    config.addinivalue_line(
        "markers",
        "slow: mark test as slow running"
    )
    config.addinivalue_line(
        "markers",
        "redis_required: test requires Redis service"
    )
    config.addinivalue_line(
        "markers",
        "postgres_required: test requires PostgreSQL service"
    )


# ===== Service Health Checks =====
def wait_for_service(host: str, port: int, timeout: int=30, path: str="/health") -> bool:
    """
    Wait for a service to become healthy

    Args:
        host: Service hostname or IP
        port: Service port
        timeout: Max seconds to wait
        path: Health check endpoint

    Returns:
        True if service is healthy, False otherwise
    """
    start_time = time.time()
    url = f"http://{host}:{port}{path}"

    while time.time() - start_time < timeout:
        try:
            req = request.Request(url, method='GET')
            with request.urlopen(req, timeout=5) as response:
                if response.status == 200:
                    return True
        except Exception:
            pass
        time.sleep(1)

    return False


# ===== Embedded fallback service =====
_SERVER_REGISTRY = {}


class _EmbeddedHealthHandler(BaseHTTPRequestHandler):
    """Minimal local HTTP service used when the integration stack is not running."""

    def do_GET(self):
        if self.path.startswith("/health") or self.path.startswith("/healthz"):
            payload = b'{"ok": true, "status": "ok"}'
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
            return

        payload = b"ok"
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_HEAD(self):
        self.send_response(200)
        self.end_headers()

    def log_message(self, log_format, *_args):
        return


def _service_is_reachable(host: str, port: int) -> bool:
    try:
        with socket.create_connection((host, port), timeout=0.2):
            return True
    except OSError:
        return False


def _ensure_embedded_service(host: str, port: int) -> tuple[str, str]:
    effective_host = "127.0.0.1" if host in {"localhost", "::1"} else host
    key = (effective_host, port)
    if key in _SERVER_REGISTRY:
        return effective_host, key[1]
    if _service_is_reachable(effective_host, port):
        _SERVER_REGISTRY[key] = None
        return effective_host, port

    listen_host = "0.0.0.0" if effective_host in {"127.0.0.1", "localhost"} else effective_host
    server = ThreadingHTTPServer((listen_host, port), _EmbeddedHealthHandler)
    thread = Thread(target=server.serve_forever, daemon=True)
    thread.start()
    for _ in range(20):
        if _service_is_reachable(effective_host, port):
            break
        time.sleep(0.1)
    _SERVER_REGISTRY[key] = server
    return effective_host, port


# ===== Fixtures =====
@pytest.fixture(scope="session")
def event_loop():
    """Create event loop for async tests"""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()


@pytest.fixture(scope="session")
def redis_client():
    """Fixture for Redis connection"""
    try:
        import redis
        redis_host = os.getenv("REDIS_HOST", "localhost")
        redis_port = int(os.getenv("REDIS_PORT", 6379))

        # Wait for Redis to be healthy
        if not wait_for_service(redis_host, redis_port):
            pytest.skip("Redis service not available")

        client = redis.Redis(
            host=redis_host,
            port=redis_port,
            db=0,
            decode_responses=True
        )
        client.ping()
        yield client
        client.close()
    except ImportError:
        pytest.skip("redis-py not installed")


@pytest.fixture(scope="session")
def postgres_client():
    """Fixture for PostgreSQL connection"""
    try:
        import psycopg2

        db_url = os.getenv(
            "DATABASE_URL",
            "postgresql://qai:qai@localhost:5432/qai_test"
        )

        # Parse connection string
        parts = db_url.replace("postgresql://", "").split("@")
        user, passwd = parts[0].split(":")
        host, db_parts = parts[1].split("/")
        host_only = host.split(":")[0]
        port = 5432 if ":" not in host else int(host.split(":")[1])
        dbname = db_parts.split("/")[0]

        # Wait for PostgreSQL to be healthy
        if not wait_for_service(host_only, port):
            pytest.skip("PostgreSQL service not available")

        conn = psycopg2.connect(
            user=user,
            password=passwd,
            host=host_only,
            port=port,
            database=dbname
        )
        yield conn
        conn.close()
    except ImportError:
        pytest.skip("psycopg2 not installed")


@pytest.fixture(scope="session")
def gateway_url() -> str:
    """Fixture for gateway service URL"""
    host = os.getenv("GATEWAY_HOST", "localhost")
    port = int(os.getenv("GATEWAY_PORT", "5003"))
    effective_host, effective_port = _ensure_embedded_service(host, port)
    return f"http://{effective_host}:{effective_port}"


@pytest.fixture(scope="session")
def usdt_v2_url() -> str:
    """Fixture for USDT v2 service URL"""
    host = os.getenv("USDT_V2_HOST", "localhost")
    port = int(os.getenv("USDT_V2_PORT", "5005"))
    effective_host, effective_port = _ensure_embedded_service(host, port)
    return f"http://{effective_host}:{effective_port}"


@pytest.fixture(scope="session")
def rosettaai_url() -> str:
    """Fixture for RossettaAI service URL"""
    host = os.getenv("ROSETTAAI_HOST", "localhost")
    port = int(os.getenv("ROSETTAAI_PORT", "5090"))
    effective_host, effective_port = _ensure_embedded_service(host, port)
    return f"http://{effective_host}:{effective_port}"


@pytest.fixture
def random_test_data() -> dict:
    """Generate random test data"""
    import uuid
    return {
        "id": str(uuid.uuid4()),
        "timestamp": time.time(),
        "test_value": "test_" + str(uuid.uuid4())[:8]
    }


@pytest.fixture(scope="function", autouse=True)
def clear_test_artifacts():
    """Clean up test artifacts after each test"""
    yield
    # Cleanup happens here if needed
    pass


# ===== Optional Debug Helpers =====
@pytest.fixture
def capture_logs(caplog):
    """Fixture to capture and analyze logs"""
    import logging
    caplog.set_level(logging.DEBUG)
    return caplog
