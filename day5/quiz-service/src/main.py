from fastapi import FastAPI, Depends, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from typing import List, Optional
import uvicorn

from src.services.quiz_service import QuizService
from src.models.quiz import QuizCreate, QuizUpdate, QuizResponse, QuizSummary

app = FastAPI(
    title="Quiz Service API",
    description="High-performance quiz data service with repository pattern",
    version="1.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.post("/quizzes/", response_model=QuizResponse, status_code=201)
async def create_quiz(
    quiz_data: QuizCreate,
    quiz_service: QuizService = Depends()
):
    """Create a new quiz with questions and answers"""
    return await quiz_service.create_quiz(quiz_data)

@app.get("/quizzes/{quiz_id}", response_model=QuizResponse)
async def get_quiz(
    quiz_id: int,
    quiz_service: QuizService = Depends()
):
    """Get a specific quiz by ID"""
    return await quiz_service.get_quiz(quiz_id)

@app.get("/quizzes/", response_model=List[QuizSummary])
async def get_quizzes(
    skip: int = Query(0, ge=0, description="Number of quizzes to skip"),
    limit: int = Query(20, ge=1, le=100, description="Number of quizzes to return"),
    category: Optional[str] = Query(None, description="Filter by category"),
    difficulty: Optional[str] = Query(None, description="Filter by difficulty"),
    quiz_service: QuizService = Depends()
):
    """Get list of quizzes with filtering and pagination"""
    return await quiz_service.get_quizzes(skip, limit, category, difficulty)

@app.put("/quizzes/{quiz_id}", response_model=QuizResponse)
async def update_quiz(
    quiz_id: int,
    quiz_data: QuizUpdate,
    quiz_service: QuizService = Depends()
):
    """Update an existing quiz"""
    return await quiz_service.update_quiz(quiz_id, quiz_data)

@app.delete("/quizzes/{quiz_id}")
async def delete_quiz(
    quiz_id: int,
    quiz_service: QuizService = Depends()
):
    """Delete a quiz (soft delete)"""
    success = await quiz_service.delete_quiz(quiz_id)
    return {"message": "Quiz deleted successfully", "success": success}

@app.get("/quizzes/search/", response_model=List[QuizSummary])
async def search_quizzes(
    q: str = Query(..., min_length=1, description="Search query"),
    limit: int = Query(10, ge=1, le=50, description="Number of results to return"),
    quiz_service: QuizService = Depends()
):
    """Search quizzes by title or description"""
    return await quiz_service.search_quizzes(q, limit)

@app.get("/quizzes/stats/")
async def get_quiz_statistics(quiz_service: QuizService = Depends()):
    """Get quiz statistics and analytics"""
    return await quiz_service.get_statistics()

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "service": "quiz-data-layer"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000, reload=True)
