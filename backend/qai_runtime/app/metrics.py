from __future__ import annotations

from .integrations import RuntimeIntegrations
from .storage import RuntimeStore


class RuntimeMetricsRenderer:
    def __init__(self, store: RuntimeStore, integrations: RuntimeIntegrations):
        self.store = store
        self.integrations = integrations

    def render(self) -> str:
        checks = self.integrations.health_checks()
        outbox = self.store.outbox_stats()
        relay = self.store.relay_metrics_snapshot()
        audit = self.store.relay_audit_counts()
        lines = [
            "# HELP qai_orders_total Total accepted orders in the runtime store.",
            "# TYPE qai_orders_total gauge",
            f"qai_orders_total {self.store.order_count()}",
            "# HELP qai_commands_pending Pending control-plane commands.",
            "# TYPE qai_commands_pending gauge",
            f"qai_commands_pending {self.store.pending_command_count()}",
            "# HELP qai_outbox_events Runtime outbox events grouped by status.",
            "# TYPE qai_outbox_events gauge",
        ]
        for status, value in sorted(outbox.items()):
            lines.append(f'qai_outbox_events{{status="{status}"}} {value}')
        lines.extend(
            [
                "# HELP qai_relay_attempts_total Total relay attempts recorded in the outbox store.",
                "# TYPE qai_relay_attempts_total gauge",
                f"qai_relay_attempts_total {relay['attempts_total']}",
                "# HELP qai_relay_deliveries_total Total outbox events delivered successfully.",
                "# TYPE qai_relay_deliveries_total gauge",
                f"qai_relay_deliveries_total {relay['sent_total']}",
                "# HELP qai_relay_dead_letter_total Total outbox events currently in dead-letter state.",
                "# TYPE qai_relay_dead_letter_total gauge",
                f"qai_relay_dead_letter_total {relay['dead_letter_total']}",
                "# HELP qai_relay_failed_total Total outbox events currently in failed retryable state.",
                "# TYPE qai_relay_failed_total gauge",
                f"qai_relay_failed_total {relay['failed_total']}",
                "# HELP qai_outbox_oldest_age_seconds Oldest outbox age by bucket.",
                "# TYPE qai_outbox_oldest_age_seconds gauge",
                (
                    'qai_outbox_oldest_age_seconds{bucket="retryable"} '
                    f"{relay['oldest_retryable_age_seconds']}"
                ),
                (
                    'qai_outbox_oldest_age_seconds{bucket="dead_letter"} '
                    f"{relay['oldest_dead_letter_age_seconds']}"
                ),
                "# HELP qai_dependency_up Dependency reachability for runtime integrations.",
                "# TYPE qai_dependency_up gauge",
            ]
        )
        for name, status in sorted(checks.items()):
            lines.append(f'qai_dependency_up{{name="{name}"}} {1 if status == "connected" else 0}')
        lines.extend(
            [
                "# HELP qai_relay_audit_total Total relay audit actions by type.",
                "# TYPE qai_relay_audit_total gauge",
            ]
        )
        for action, value in sorted(audit.items()):
            lines.append(f'qai_relay_audit_total{{action="{action}"}} {value}')
        return "\n".join(lines) + "\n"
