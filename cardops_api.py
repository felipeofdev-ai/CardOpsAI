#!/usr/bin/env python3
"""Start CardOpsAI FastAPI server."""
import uvicorn

if __name__ == "__main__":
    uvicorn.run(
        "api.server:app",
        host="0.0.0.0",
        port=int(__import__("os").environ.get("CARDOPS_API_PORT", "8000")),
        reload=False,
    )
