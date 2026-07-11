from fastapi import FastAPI, HTTPException
from redis import Redis
from contextlib import asynccontextmanager
import os
import logging
import json

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize connections
redis_url = os.getenv("REDIS_URL", "redis://redis:6379/0")
kafka_brokers = os.getenv("KAFKA_BROKERS", "redpanda:19092")

try:
    # Parse Redis URL
    redis_client = Redis.from_url(redis_url, decode_responses=True)
    redis_client.ping()
    logger.info("✓ Redis connected")
except Exception as e:
    logger.warning(f"Redis connection warning: {e}")
    redis_client = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup and shutdown events"""
    logger.info("Demo App starting")
    yield
    logger.info("Demo App shutting down")


app = FastAPI(title="Demo-App-QAI", lifespan=lifespan)


@app.get("/health")
async def health():
    """Health check endpoint"""
    return {"status": "healthy", "service": "demo-app-qai"}


@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "service": "demo-app-qai",
        "status": "running",
        "version": "1.0.0"
    }


@app.get("/metrics")
async def metrics():
    """Get application metrics"""
    try:
        info = {
            "redis": "connected" if redis_client else "disconnected",
            "kafka_brokers": kafka_brokers
        }
        return info
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/event")
async def process_event(event: dict):
    """Process incoming event"""
    try:
        if redis_client:
            redis_client.rpush("events", json.dumps(event))
        return {"status": "processed", "event": event}
    except Exception as e:
        logger.error(f"Error processing event: {e}")
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
