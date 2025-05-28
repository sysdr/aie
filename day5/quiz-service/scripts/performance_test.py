import asyncio
import aiohttp
import time
import statistics
from concurrent.futures import ThreadPoolExecutor

async def create_quiz_request(session, quiz_data):
    """Make a single quiz creation request"""
    start_time = time.time()
    try:
        async with session.post('http://localhost:8000/quizzes/', json=quiz_data) as response:
            await response.json()
            return time.time() - start_time, response.status
    except Exception as e:
        return time.time() - start_time, 500

async def get_quiz_request(session, quiz_id):
    """Make a single quiz retrieval request"""
    start_time = time.time()
    try:
        async with session.get(f'http://localhost:8000/quizzes/{quiz_id}') as response:
            await response.json()
            return time.time() - start_time, response.status
    except Exception as e:
        return time.time() - start_time, 500

async def performance_test():
    """Run performance tests"""
    
    # Sample quiz data
    quiz_data = {
        "title": "Performance Test Quiz",
        "description": "Testing API performance",
        "category": "Performance",
        "difficulty": "medium",
        "questions": [
            {
                "question_text": "What is load testing?",
                "question_type": "multiple_choice",
                "points": 5,
                "order_index": 1,
                "answers": [
                    {"answer_text": "Testing individual components", "is_correct": False, "order_index": 1},
                    {"answer_text": "Testing system under load", "is_correct": True, "order_index": 2}
                ]
            }
        ]
    }
    
    print("🚀 Starting Performance Tests...")
    
    # Test concurrent quiz creation
    async with aiohttp.ClientSession() as session:
        print("📝 Testing Quiz Creation (100 concurrent requests)...")
        
        start_time = time.time()
        tasks = [create_quiz_request(session, quiz_data) for _ in range(100)]
        results = await asyncio.gather(*tasks)
        total_time = time.time() - start_time
        
        response_times = [r[0] for r in results]
        status_codes = [r[1] for r in results]
        
        successful_requests = sum(1 for code in status_codes if code == 201)
        
        print(f"✅ Quiz Creation Results:")
        print(f"   Total time: {total_time:.2f}s")
        print(f"   Successful requests: {successful_requests}/100")
        print(f"   Requests per second: {100/total_time:.2f}")
        print(f"   Average response time: {statistics.mean(response_times):.3f}s")
        print(f"   95th percentile: {statistics.quantiles(response_times, n=20)[18]:.3f}s")
        
        # Test concurrent quiz retrieval
        print("\n📖 Testing Quiz Retrieval (500 concurrent requests)...")
        
        start_time = time.time()
        # Use random quiz IDs from 1-10 (assuming some exist)
        tasks = [get_quiz_request(session, (i % 10) + 1) for i in range(500)]
        results = await asyncio.gather(*tasks)
        total_time = time.time() - start_time
        
        response_times = [r[0] for r in results]
        status_codes = [r[1] for r in results]
        
        successful_requests = sum(1 for code in status_codes if code in [200, 404])
        
        print(f"✅ Quiz Retrieval Results:")
        print(f"   Total time: {total_time:.2f}s")
        print(f"   Successful requests: {successful_requests}/500")
        print(f"   Requests per second: {500/total_time:.2f}")
        print(f"   Average response time: {statistics.mean(response_times):.3f}s")
        print(f"   95th percentile: {statistics.quantiles(response_times, n=20)[18]:.3f}s")

if __name__ == "__main__":
    asyncio.run(performance_test())
