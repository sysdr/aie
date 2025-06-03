class QuizServiceError(Exception):
    """Base exception for quiz service errors"""
    def __init__(self, message: str, error_code: str = None):
        super().__init__(message)
        self.message = message
        self.error_code = error_code

class ValidationError(QuizServiceError):
    """Raised when quiz validation fails"""
    pass

class QuizNotFoundError(QuizServiceError):
    """Raised when quiz is not found"""
    pass

class UnauthorizedError(QuizServiceError):
    """Raised when user lacks permissions"""
    pass

class QuizCreationLimitError(QuizServiceError):
    """Raised when user exceeds quiz creation quota"""
    pass

class InvalidQuizStateError(QuizServiceError):
    """Raised when quiz is in invalid state for operation"""
    pass
