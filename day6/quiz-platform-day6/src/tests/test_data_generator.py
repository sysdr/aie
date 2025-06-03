from faker import Faker
import random
from src.models.quiz import QuizCreateRequest, DifficultyLevel, QuestionType

fake = Faker()

def generate_question_data(difficulty: str, question_type: str) -> dict:
    """Generate a realistic question as dictionary"""
    
    base_questions = {
        ("easy", "multiple_choice"): {
            "text": "What is the capital of the United States?",
            "options": ["New York", "Washington D.C.", "Los Angeles", "Chicago"],
            "correct_answer": "Washington D.C.",
            "explanation": "Washington D.C. has been the capital since 1790"
        },
        ("medium", "short_answer"): {
            "text": "Explain the concept of recursion in programming",
            "correct_answer": "A function calling itself with a base case",
            "explanation": "Recursion is when a function calls itself to solve smaller subproblems"
        },
        ("hard", "multiple_choice"): {
            "text": "What is the time complexity of quicksort in the worst case?",
            "options": ["O(n)", "O(n log n)", "O(n²)", "O(log n)"],
            "correct_answer": "O(n²)",
            "explanation": "Worst case occurs when pivot is always the smallest or largest element"
        }
    }
    
    template = base_questions.get((difficulty, question_type))
    if not template:
        # Fallback generic question
        template = {
            "text": f"Sample {difficulty} {question_type} question?",
            "correct_answer": "Sample answer",
            "explanation": f"This is a {difficulty} level explanation"
        }
        if question_type == "multiple_choice":
            template["options"] = ["Option A", "Option B", "Option C", "Option D"]
    
    points = {"easy": 1, "medium": 2, "hard": 3}[difficulty]
    
    question_data = {
        "text": template["text"],
        "question_type": question_type,
        "difficulty": difficulty,
        "correct_answer": template["correct_answer"],
        "explanation": template["explanation"],
        "points": points
    }
    
    if "options" in template:
        question_data["options"] = template["options"]
        
    return question_data

def generate_valid_quiz(title: str = None) -> QuizCreateRequest:
    """Generate a valid quiz with proper difficulty progression"""
    
    if not title:
        title = f"{fake.word().title()} {fake.word().title()} Quiz"
    
    # Start with required difficulties in order
    questions = [
        generate_question_data("easy", "multiple_choice"),
        generate_question_data("easy", "true_false"),
        generate_question_data("medium", "short_answer"),
        generate_question_data("medium", "multiple_choice"),
        generate_question_data("hard", "multiple_choice"),
        generate_question_data("hard", "short_answer"),
    ]
    
    # Add a few more in progression order
    additional_count = random.randint(1, 3)
    for i in range(additional_count):
        if i == 0:
            difficulty = "easy"
        elif i == 1:
            difficulty = "medium" 
        else:
            difficulty = "hard"
        question_type = random.choice(["multiple_choice", "true_false", "short_answer"])
        questions.append(generate_question_data(difficulty, question_type))
    
    return QuizCreateRequest(
        title=title,
        description=fake.text(max_nb_chars=200),
        questions=questions,
        time_limit=random.randint(300, 1800),
        max_attempts=random.randint(1, 5)
    )

if __name__ == "__main__":
    # Generate sample quiz
    quiz = generate_valid_quiz("Sample Generated Quiz")
    print(f"Generated quiz: {quiz.title}")
    print(f"Questions: {len(quiz.questions)}")
    print(f"Difficulties: {[q['difficulty'] for q in quiz.questions]}")
