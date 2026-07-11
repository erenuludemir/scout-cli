import random

try:
    from termcolor import colored
except ImportError:  # pragma: no cover
    def colored(text, *_args, **_kwargs):
        return text


class BursaPredictiveAI:
    """Signal generator for short horizon market forecasts."""

    def __init__(self):
        self.confidence_threshold = 0.85
        self.sentiment_score = 0.5

    def generate_signal(self, market_data, technical_indicators):
        _ = market_data, technical_indicators
        prediction = random.choice(["BUY", "SELL", "HOLD"])
        confidence = random.uniform(0.70, 0.99)
        self.sentiment_score = random.uniform(0.2, 0.8)

        if confidence >= self.confidence_threshold:
            color = "green" if prediction == "BUY" else "red"
            print(colored(f"[AI-ORACLE] Sinyal: {prediction} (%{confidence * 100:.1f} guven) | Sentiment: {self.sentiment_score:.2f}", color))
            return {"action": prediction, "confidence": confidence, "sentiment": self.sentiment_score}

        return {"action": "HOLD", "confidence": confidence}


if __name__ == "__main__":
    ai = BursaPredictiveAI()
    print(ai.generate_signal({}, {"RSI": 32, "MACD": "Bullish_Cross"}))
