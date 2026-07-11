from statistics import mean


class BursaNeuralNet:
    """Collective learning layer for trade outcomes."""

    def __init__(self):
        self.knowledge_base = []
        self.global_risk_multiplier = 1.0

    def learn_from_trade(self, bot_id, result_pnl, market_state):
        experience = {"id": bot_id, "pnl": result_pnl, "state": market_state}
        self.knowledge_base.append(experience)

        recent = [item["pnl"] for item in self.knowledge_base[-50:]]
        avg_pnl = mean(recent) if recent else 0.0
        if avg_pnl < -0.02:
            self.global_risk_multiplier = 0.5
            print(f"[NEURAL NET] Kolektif risk algilandi. Risk carpani: {self.global_risk_multiplier}")
            return "THROTTLE_ALL_BOTS"
        return "STABLE"


if __name__ == "__main__":
    net = BursaNeuralNet()
    print(net.learn_from_trade("BOT_01", -0.05, "VOLATILE"))
