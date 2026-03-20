#!/usr/bin/env python3
"""
Health Check Standardization Monitor

Monitors all running Docker Compose services and reports health status.
Standardizes health check logging and alerting.
"""

import subprocess
import json
import sys
from typing import Dict, List, Optional
from dataclasses import dataclass
from datetime import datetime


@dataclass
class ServiceHealth:
    name: str
    status: str  # running, exited, paused
    health: Optional[str]  # healthy, unhealthy, starting, none
    uptime: Optional[str]
    port: Optional[str]


def get_compose_services() -> List[Dict]:
    """Get all services from docker compose ps (JSON format)"""
    try:
        result = subprocess.run(
            ["docker", "compose", "ps", "--format", "json"],
            capture_output=True,
            text=True,
            timeout=30,
        )
        if result.returncode == 0:
            return json.loads(result.stdout)
        else:
            print(f"❌ Failed to get services: {result.stderr}", file=sys.stderr)
            return []
    except Exception as e:
        print(f"❌ Error: {e}", file=sys.stderr)
        return []


def check_service_health(service: Dict) -> ServiceHealth:
    """Extract health information from service"""
    return ServiceHealth(
        name=service.get("Name", "unknown"),
        status=service.get("State", "unknown"),
        health=service.get("Health", "none"),
        uptime=service.get("Created", None),
        port=service.get("Ports", ""),
    )


def print_health_report(services: List[ServiceHealth]) -> None:
    """Print formatted health check report"""
    print("\n" + "=" * 100)
    print(f"{'SERVICE':<30} {'STATUS':<12} {'HEALTH':<15} {'PORTS':<30}")
    print("=" * 100)

    healthy_count = 0
    unhealthy_count = 0

    for svc in sorted(services, key=lambda x: x.name):
        # Color coding
        health_emoji = {
            "healthy": "✅",
            "unhealthy": "❌",
            "starting": "⏳",
            "none": "⊘",
        }.get(svc.health or "none", "❓")

        status_emoji = {
            "running": "▶",
            "exited": "⏹",
            "paused": "⏸",
        }.get(svc.status, "❓")

        print(
            f"{svc.name:<30} {status_emoji} {svc.status:<10} "
            f"{health_emoji} {svc.health or 'none':<13} {svc.port:<30}"
        )

        if svc.health == "healthy":
            healthy_count += 1
        elif svc.health == "unhealthy":
            unhealthy_count += 1

    print("=" * 100)
    print(f"\n📊 Summary: {healthy_count} healthy, {unhealthy_count} unhealthy, {len(services) - healthy_count - unhealthy_count} other\n")

    return unhealthy_count


def watch_services(interval: int=5) -> None:
    """Continuously watch services health"""
    print(f"🔍 Monitoring services every {interval}s (Ctrl+C to stop)...\n")

    try:
        while True:
            services = get_compose_services()
            if not services:
                print("No services running")
                return

            # Clear screen (simple fallback for Windows/Mac/Linux)
            print("\033[2J\033[H", end="", flush=True)

            health_data = [check_service_health(s) for s in services]
            unhealthy = print_health_report(health_data)

            if unhealthy > 0:
                print(f"⚠️  {unhealthy} service(s) unhealthy")

            print(f"Last updated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

            import time
            time.sleep(interval)
    except KeyboardInterrupt:
        print("\n\nMonitoring stopped.")


def validate_healthchecks(compose_file: str="compose.yml") -> Dict[str, bool]:
    """Validate that all services have consistent health checks"""
    print(f"\n📋 Validating health checks in {compose_file}...\n")

    issues = {}

    try:
        with open(compose_file, 'r') as f:
            content = f.read()

        import yaml
        config = yaml.safe_load(content)

        for service_name, service_config in config.get('services', {}).items():
            healthcheck = service_config.get('healthcheck')

            if not healthcheck:
                issues[service_name] = False
                print(f"⚠️  {service_name}: No healthcheck defined")
            else:
                test = healthcheck.get('test', [])
                interval = healthcheck.get('interval', 'default')

                # Validate test command
                if isinstance(test, list) and len(test) > 0:
                    print(f"✅ {service_name}: {test[0]} | interval={interval}")
                    issues[service_name] = True
                else:
                    issues[service_name] = False
                    print(f"❌ {service_name}: Invalid test command")

    except ImportError:
        print("⚠️  PyYAML not installed. Install with: pip install pyyaml")
    except Exception as e:
        print(f"❌ Error reading {compose_file}: {e}")

    return issues


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Health Check Standardization Monitor\n")
        print("Usage:")
        print("  python3 health_monitor.py status         - Get current status")
        print("  python3 health_monitor.py watch [N]      - Watch services (every N seconds, default 5)")
        print("  python3 health_monitor.py validate       - Validate compose healthchecks\n")
        sys.exit(1)

    command = sys.argv[1]

    if command == "status":
        services = get_compose_services()
        if services:
            health_data = [check_service_health(s) for s in services]
            print_health_report(health_data)

    elif command == "watch":
        interval = int(sys.argv[2]) if len(sys.argv) > 2 else 5
        watch_services(interval)

    elif command == "validate":
        compose_file = sys.argv[2] if len(sys.argv) > 2 else "compose.yml"
        validate_healthchecks(compose_file)

    else:
        print(f"Unknown command: {command}", file=sys.stderr)
        sys.exit(1)
