from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
from src.api.session_endpoints import router as session_router
from src.services.database import init_db
import asyncio

app = FastAPI(
    title="Quiz Session Management Service",
    version="1.0.0",
    description="Stateful session management for distributed quiz platform"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(session_router, prefix="/api/v1/sessions", tags=["sessions"])

@app.on_event("startup")
async def startup_event():
    await init_db()

@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "quiz-session-management"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8002)
