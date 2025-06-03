import asyncio
import json
from src.services.quiz_service import QuizService
from src.repositories.quiz_repository import InMemoryQuizRepository
from src.tests.test_data_generator import generate_valid_quiz
from src.exceptions.quiz_exceptions import ValidationError, QuizCreationLimitError

async def demonstrate_business_logic():
    """Demonstrate business logic features"""
    
    print("🧠 Quiz Service Business Logic Demonstration")
    print("=" * 50)
    
    # Setup service
    repository = InMemoryQuizRepository()
    service = QuizService(repository, max_quizzes_per_user=2)
    
    # Demo 1: Successful quiz creation
    print("\n1. Creating a valid quiz...")
    valid_quiz = generate_valid_quiz("Demo Quiz 1")
    try:
        result = await service.create_quiz(valid_quiz, "demo_user")
        print(f"✅ Quiz created successfully!")
        print(f"   Title: {result.title}")
        print(f"   Questions: {result.question_count}")
        print(f"   Difficulty distribution: {result.difficulty_distribution}")
    except Exception as e:
        print(f"❌ Error: {e}")
    
    # Demo 2: Quiz quota enforcement
    print("\n2. Testing quiz quota enforcement...")
    try:
        await service.create_quiz(generate_valid_quiz("Demo Quiz 2"), "demo_user")
        print("✅ Second quiz created")
        
        # This should fail
        await service.create_quiz(generate_valid_quiz("Demo Quiz 3"), "demo_user")
        print("❌ This shouldn't happen - quota should be enforced!")
    except QuizCreationLimitError as e:
        print(f"✅ Quota enforced correctly: {e.message}")
    
    # Demo 3: Difficulty progression validation
    print("\n3. Testing difficulty progression validation...")
    from src.models.quiz import QuizCreateRequest
    
    invalid_questions = [
        {
            "text": "Easy question only",
            "question_type": "true_false",
            "difficulty": "easy",
            "correct_answer": "True",
            "explanation": "Missing other difficulties"
        }
    ]
    
    invalid_quiz = QuizCreateRequest(
        title="Invalid Quiz",
        questions=invalid_questions
    )
    
    try:
        await service.create_quiz(invalid_quiz, "other_user")
        print("❌ This shouldn't happen - validation should fail!")
    except ValidationError as e:
        print(f"✅ Validation working: {e.message}")
    
    # Demo 4: Access control
    print("\n4. Testing access control...")
    quiz_result = await service.create_quiz(generate_valid_quiz("Private Quiz"), "owner_user")
    
    try:
        # Owner should access
        owner_access = await service.get_quiz(quiz_result.id, "owner_user")
        print(f"✅ Owner can access quiz: {owner_access.title}")
        
        # Other user should not access unpublished quiz
        try:
            await service.get_quiz(quiz_result.id, "other_user")
            print("❌ This shouldn't happen - access should be denied!")
        except Exception as e:
            print(f"✅ Access control working: unauthorized access denied")
            
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
    
    print("\n🎉 Business logic demonstration completed!")

if __name__ == "__main__":
    asyncio.run(demonstrate_business_logic())
