from flask import Flask
from flask_cors import CORS
from src.controllers.quiz_controller import QuizController

def create_app():
    app = Flask(__name__)
    
    # Add CORS support
    CORS(app, resources={
        r"/api/*": {
            "origins": "*",
            "methods": ["GET", "POST", "PUT", "DELETE"],
            "allow_headers": ["Content-Type", "X-User-ID"]
        }
    })
    
    # Setup controllers
    QuizController(app)
    
    @app.route("/")
    def root():
        return {"message": "Quiz Platform Day 6 - Business Logic Service"}

    @app.route("/health")
    def health_check():
        return {"status": "healthy", "service": "quiz-service"}
    
    return app

app = create_app()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000, debug=True)
