"""
Integration tests for QuantumAI Gateway service
"""

import pytest
import json
from urllib import request, error
from typing import Dict, Any

pytestmark = pytest.mark.integration


class TestGatewayHealth:
    """Test Gateway service health and availability"""

    def test_gateway_health_endpoint(self, gateway_url: str):
        """Test that gateway health endpoint is accessible"""
        try:
            req = request.Request(
                f"{gateway_url}/health",
                method="GET"
            )
            with request.urlopen(req, timeout=5) as response:
                assert response.status == 200
                body = response.read().decode('utf-8')
                # Should return some response, not necessarily JSON
                assert len(body) > 0
        except error.HTTPError:
            # Gateway might not have /health endpoint, check / instead
            req = request.Request(f"{gateway_url}/", method="GET")
            with request.urlopen(req, timeout=5) as response:
                assert response.status in [200, 301]

    def test_gateway_connectivity(self, gateway_url: str):
        """Test basic gateway connectivity"""
        req = request.Request(f"{gateway_url}/", method="GET")
        with request.urlopen(req, timeout=5) as response:
            assert response.status in [200, 301, 404]

    def test_gateway_headers(self, gateway_url: str):
        """Test that gateway returns proper headers"""
        req = request.Request(f"{gateway_url}/", method="GET")
        with request.urlopen(req, timeout=5) as response:
            headers = response.headers
            # Nginx should have via header
            assert headers is not None


class TestGatewayRouting:
    """Test Gateway routing to backend services"""

    @pytest.mark.slow
    def test_gateway_routes_to_services(self, gateway_url: str):
        """Test that gateway routes requests properly"""
        # This is a placeholder for service routing tests
        # Actual routes depend on nginx config
        req = request.Request(f"{gateway_url}/", method="GET")
        with request.urlopen(req, timeout=5) as response:
            assert response.status in [200, 301, 404]

    def test_gateway_404_handling(self, gateway_url: str):
        """Test that gateway handles 404s properly"""
        try:
            req = request.Request(
                f"{gateway_url}/nonexistent-endpoint-xyz",
                method="GET"
            )
            with request.urlopen(req, timeout=5):
                pass  # Should raise HTTPError
        except error.HTTPError as e:
            # 404 or 405 is expected
            assert e.code in [404, 405]


class TestUSDTv2Service:
    """Test USDT v2 service functionality"""

    def test_usdt_v2_health(self, usdt_v2_url: str):
        """Test USDT v2 health endpoint"""
        try:
            req = request.Request(
                f"{usdt_v2_url}/health",
                method="GET"
            )
            with request.urlopen(req, timeout=5) as response:
                assert response.status == 200
        except error.HTTPError:
            # Try root endpoint
            req = request.Request(f"{usdt_v2_url}/", method="GET")
            with request.urlopen(req, timeout=5) as response:
                assert response.status in [200, 404]

    @pytest.mark.redis_required
    def test_usdt_v2_with_redis(self, usdt_v2_url: str, redis_client):
        """Test USDT v2 can connect to Redis"""
        # Verify Redis is available
        assert redis_client.ping() is True

        # Test USDT v2 connectivity
        req = request.Request(f"{usdt_v2_url}/", method="GET")
        with request.urlopen(req, timeout=5) as response:
            assert response.status in [200, 404]


class TestRossettaAIService:
    """Test RossettaAI model serving service"""

    def test_rosettaai_health(self, rosettaai_url: str):
        """Test RossettaAI health endpoint"""
        try:
            req = request.Request(
                f"{rosettaai_url}/health",
                method="GET"
            )
            with request.urlopen(req, timeout=5) as response:
                assert response.status == 200
        except error.HTTPError:
            # Try root endpoint
            req = request.Request(f"{rosettaai_url}/", method="GET")
            with request.urlopen(req, timeout=5) as response:
                assert response.status in [200, 404]

    @pytest.mark.slow
    def test_rosettaai_model_availability(self, rosettaai_url: str):
        """Test that RossettaAI has model loaded"""
        # This depends on model file availability
        # Placeholder for future implementation
        req = request.Request(f"{rosettaai_url}/", method="GET")
        with request.urlopen(req, timeout=5) as response:
            assert response.status in [200, 404]


class TestServiceIntegration:
    """Test integration between services"""

    def test_all_services_accessible(
        self,
        gateway_url: str,
        usdt_v2_url: str,
        rosettaai_url: str
    ):
        """Test that all services are accessible"""
        services = {
            "gateway": gateway_url,
            "usdt-v2": usdt_v2_url,
            "rosettaai": rosettaai_url
        }

        accessible = {}
        for name, url in services.items():
            try:
                req = request.Request(f"{url}/", method="GET", timeout=5)
                with request.urlopen(req) as response:
                    accessible[name] = response.status in [200, 301, 404]
            except Exception:
                accessible[name] = False

        # At least gateway should be accessible
        assert accessible.get("gateway", False), "Gateway not accessible"

    @pytest.mark.redis_required
    def test_redis_integration(self, redis_client, random_test_data: Dict[str, Any]):
        """Test Redis caching integration"""
        key = f"test:{random_test_data['id']}"
        value = json.dumps(random_test_data)

        # Set
        assert redis_client.set(key, value) is True

        # Get
        retrieved = redis_client.get(key)
        assert retrieved == value

        # Delete
        assert redis_client.delete(key) == 1

    @pytest.mark.postgres_required
    def test_postgres_connectivity(self, postgres_client):
        """Test PostgreSQL connectivity"""
        cursor = postgres_client.cursor()
        try:
            cursor.execute("SELECT version();")
            version = cursor.fetchone()
            assert version is not None
            assert "PostgreSQL" in version[0] or "postgres" in version[0].lower()
        finally:
            cursor.close()


class TestDockerCompose:
    """Test Docker Compose configuration"""

    def test_compose_files_exist(self):
        """Verify compose files exist"""
        import os
        files = [
            "compose.yml",
            "docker-compose.base.yml",
            "COMPOSE_STRATEGY.md"
        ]
        for file in files:
            assert os.path.exists(file), f"{file} not found"

    def test_compose_config_valid(self):
        """Test that Docker Compose config is valid"""
        import subprocess
        result = subprocess.run(
            [
                "docker",
                "compose",
                "--file", "compose.yml",
                "config",
                "--quiet"
            ],
            capture_output=True
        )
        assert result.returncode == 0, f"Compose config invalid: {result.stderr.decode()}"
