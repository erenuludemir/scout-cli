import random

try:
    from termcolor import colored
except ImportError:  # pragma: no cover
    def colored(text, *_args, **_kwargs):
        return text


class BursaStressGuard:
    """Runs a Monte Carlo style drawdown simulation for a portfolio."""

    def __init__(self):
        self.sim_count = 100_000
        self.risk_threshold = 0.15

    def run_black_swan_sim(self, portfolio_value):
        failures = 0
        for _ in range(self.sim_count):
            shock = random.gauss(-0.05, 0.10)
            impacted_value = portfolio_value * (1 + shock)
            if impacted_value < (portfolio_value * (1 - self.risk_threshold)):
                failures += 1

        failure_rate = (failures / self.sim_count) * 100
        if failure_rate > 5.0:
            print(colored(f"[CRITICAL] Stress test failed: %{failure_rate:.2f}", "red"))
            return False

        print(colored(f"[SAFE] Stress test passed: %{100 - failure_rate:.2f}", "green"))
        return True


if __name__ == "__main__":
    guard = BursaStressGuard()
    guard.run_black_swan_sim(1_000_000)
