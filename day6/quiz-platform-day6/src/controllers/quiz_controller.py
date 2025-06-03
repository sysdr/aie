from flask import Flask, request, jsonify
from typing import Dict, Any
import json
from src.services.quiz_service import QuizService
from src.models.quiz import QuizCreateRequest
from src.repositories.quiz_repository import InMemoryQuizRepository
from src.exceptions.quiz_exceptions import (
    ValidationError, QuizNotFoundError, UnauthorizedError, 
    QuizCreationLimitError, InvalidQuizStateError
)

class QuizController:
    def __init__(self, app: Flask):
        self.app = app
        self.setup_routes()

    def get_quiz_service(self) -> QuizService:
        repository = InMemoryQuizRepository()
        return QuizService(repository)

    def setup_routes(self):
        @self.app.route('/api/v1/quizzes/', methods=['POST'])
        def create_quiz():
            """Create a new quiz"""
            try:
                data = request.get_json()
                creator_id = request.headers.get('X-User-ID', 'user_123')  # In real app, get from JWT token
                
                quiz_request = QuizCreateRequest(
                    title=data['title'],
                    questions=data['questions'],
                    description=data.get('description'),
                    time_limit=data.get('time_limit'),
                    max_attempts=data.get('max_attempts', 3)
                )
                
                quiz_service = self.get_quiz_service()
                import asyncio
                result = asyncio.run(quiz_service.create_quiz(quiz_request, creator_id))
                
                return jsonify(result.to_dict()), 201
                
            except ValidationError as e:
                return jsonify({"message": e.message, "code": e.error_code}), 400
            except QuizCreationLimitError as e:
                return jsonify({"message": e.message, "code": e.error_code}), 429
            except ValueError as e:
                return jsonify({"message": str(e), "code": "VALIDATION_ERROR"}), 400
            except Exception as e:
                return jsonify({"message": "Internal server error", "code": "INTERNAL_ERROR"}), 500

        @self.app.route('/api/v1/quizzes/<quiz_id>', methods=['GET'])
        def get_quiz(quiz_id):
            """Get quiz by ID"""
            try:
                requester_id = request.headers.get('X-User-ID', 'user_123')
                
                quiz_service = self.get_quiz_service()
                import asyncio
                result = asyncio.run(quiz_service.get_quiz(quiz_id, requester_id))
                
                return jsonify(result.to_dict()), 200
                
            except QuizNotFoundError as e:
                return jsonify({"message": e.message, "code": e.error_code}), 404
            except UnauthorizedError as e:
                return jsonify({"message": e.message, "code": e.error_code}), 403
            except Exception as e:
                return jsonify({"message": "Internal server error"}), 500

        @self.app.route('/api/v1/quizzes/', methods=['GET'])
        def get_user_quizzes():
            """Get all quizzes for a user"""
            try:
                creator_id = request.args.get('creator_id', 'user_123')
                requester_id = request.headers.get('X-User-ID', 'user_123')
                
                quiz_service = self.get_quiz_service()
                import asyncio
                results = asyncio.run(quiz_service.get_user_quizzes(creator_id, requester_id))
                
                return jsonify([result.to_dict() for result in results]), 200
                
            except UnauthorizedError as e:
                return jsonify({"message": e.message, "code": e.error_code}), 403
            except Exception as e:
                return jsonify({"message": "Internal server error"}), 500

        @self.app.route('/api/v1/quizzes/<quiz_id>/publish', methods=['POST'])
        def publish_quiz(quiz_id):
            """Publish a quiz"""
            try:
                publisher_id = request.headers.get('X-User-ID', 'user_123')
                
                quiz_service = self.get_quiz_service()
                import asyncio
                result = asyncio.run(quiz_service.publish_quiz(quiz_id, publisher_id))
                
                return jsonify(result.to_dict()), 200
                
            except QuizNotFoundError as e:
                return jsonify({"message": e.message, "code": e.error_code}), 404
            except UnauthorizedError as e:
                return jsonify({"message": e.message, "code": e.error_code}), 403
            except InvalidQuizStateError as e:
                return jsonify({"message": e.message, "code": e.error_code}), 422
            except Exception as e:
                return jsonify({"message": "Internal server error"}), 500
