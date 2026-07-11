import random
import time

try:
    from termcolor import colored
except ImportError:  # pragma: no cover
    def colored(text, *_args, **_kwargs):
        return text


class MegaPipelineRouter:
    """Routes incoming events into either a micro-batch lane or a critical fork lane."""

    def __init__(self):
        self.micro_batch_threshold = 100
        self.large_tx_threshold = 1_000_000
        self.micro_batch_queue = []

    def ingest_event(self, event_data):
        amount = float(event_data.get("amount", 0))
        if amount >= self.large_tx_threshold:
            return self.fork_critical_transaction(event_data)
        return self.route_to_micro_batch(event_data)

    def fork_critical_transaction(self, data):
        trace_id = f"fork-{int(time.time() * 1000)}"
        risk_lane = {
            "trace_id": trace_id,
            "lane": "risk",
            "priority": "critical",
            "payload": data,
        }
        execution_lane = {
            "trace_id": trace_id,
            "lane": "execution",
            "priority": "hold_for_review",
            "payload": data,
        }
        print(colored(f"[FORKING] Critical transaction isolated: {trace_id}", "magenta"))
        return {
            "status": "critical_path_locked",
            "risk_lane": risk_lane,
            "execution_lane": execution_lane,
        }

    def route_to_micro_batch(self, data):
        self.micro_batch_queue.append(data)
        print(colored(f"[BATCH] Event queued: ${float(data.get('amount', 0)):.2f}", "green"))
        if len(self.micro_batch_queue) >= self.micro_batch_threshold:
            return self.flush_micro_batch()
        return {
            "status": "micro_batch_routed",
            "queued": len(self.micro_batch_queue),
        }

    def flush_micro_batch(self):
        total_amount = sum(float(item.get("amount", 0)) for item in self.micro_batch_queue)
        batch_size = len(self.micro_batch_queue)
        batch_id = f"batch-{random.randint(1000, 9999)}"
        self.micro_batch_queue.clear()
        print(colored(f"[AGGREGATOR] {batch_size} events sealed into {batch_id}", "cyan"))
        return {
            "status": "micro_batch_flushed",
            "batch_id": batch_id,
            "batch_size": batch_size,
            "total_amount": total_amount,
        }


if __name__ == "__main__":
    router = MegaPipelineRouter()
    router.ingest_event({"amount": 10, "type": "BUY"})
    router.ingest_event({"amount": 1_000_000, "type": "TRANSFER"})
