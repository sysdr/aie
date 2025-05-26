from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse
from src.auth.routes import router as auth_router
import uvicorn

# Create FastAPI application
app = FastAPI(
    title="AI Quiz Platform - Authentication Service",
    description="Secure authentication service for the AI Quiz Platform",
    version="1.0.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify exact origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include authentication routes
app.include_router(auth_router)

# Serve static files (frontend)
try:
    app.mount("/static", StaticFiles(directory="frontend"), name="static")
except:
    pass  # Frontend directory might not exist in tests

@app.get("/", response_class=HTMLResponse)
async def root():
    """Serve the frontend application"""
    try:
        with open("frontend/index.html", "r") as f:
            return HTMLResponse(content=f.read())
    except FileNotFoundError:
        return HTMLResponse(content="""
        <html>
            <body>
                <h1>AI Quiz Platform - Authentication Service</h1>
                <p>Authentication service is running!</p>
                <p>API Documentation: <a href="/docs">/docs</a></p>
                <p>Health Check: <a href="/auth/health">/auth/health</a></p>
            </body>
        </html>
        """)

@app.get("/health")
async def health_check():
    """Main health check endpoint"""
    return {"status": "healthy", "service": "ai-quiz-auth"}

if __name__ == "__main__":
    uvicorn.run(
        "src.main:app",
        host="0.0.0.0",
        port=8000,
        reload=True
    )
