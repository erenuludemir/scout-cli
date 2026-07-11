try:
    from fastapi import FastAPI, Header, HTTPException
except ImportError:  # pragma: no cover
    FastAPI = None

    class HTTPException(Exception):
        def __init__(self, status_code, detail):
            super().__init__(detail)
            self.status_code = status_code
            self.detail = detail

    def Header(default=None):
        return default


class _StubApp:
    def get(self, *_args, **_kwargs):
        def decorator(func):
            return func
        return decorator


app = FastAPI(title="Bursa HQ Enterprise Gateway") if FastAPI is not None else _StubApp()

PARTNERS = {
    "BURSA_INVEST_01": {"tier": "ULTRA", "pqc_enabled": True},
    "OSMANGAZI_BANK_X": {"tier": "ENTERPRISE", "pqc_enabled": True},
}


@app.get("/v1/execute")
async def execute_enterprise_order(x_partner_id: str = Header(None)):
    """Validates tenant identity and returns a dry-run routing result."""
    if x_partner_id not in PARTNERS:
        raise HTTPException(status_code=403, detail="Partner Unauthorized")

    partner_data = PARTNERS[x_partner_id]
    return {
        "status": "routed",
        "mode": "dry_run",
        "pipeline": "mega_v3",
        "tier": partner_data["tier"],
        "pqc_sealed": partner_data["pqc_enabled"],
    }


if __name__ == "__main__" and FastAPI is not None:
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
