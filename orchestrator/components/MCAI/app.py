from fastapi import FastAPI
from contextlib import asynccontextmanager
import os
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Service name from environment
SERVICE_NAME = os.getenv("SERVICE_NAME", "MCAI-Service")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup and shutdown events"""
    logger.info(f"Starting {SERVICE_NAME}")
    yield
    logger.info(f"Shutting down {SERVICE_NAME}")


app = FastAPI(title=SERVICE_NAME, lifespan=lifespan)


@app.get("/health")
async def health():
    """Health check endpoint"""
    return {"status": "healthy", "service": SERVICE_NAME}


@app.get("/docs", include_in_schema=False)
async def docs():
    """FastAPI docs redirect"""
    return {"message": "See /docs for API documentation"}


@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "service": SERVICE_NAME,
        "status": "running",
        "version": "1.0.0"
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
