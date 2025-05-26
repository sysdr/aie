#!/usr/bin/env python3
"""
Comprehensive test runner for the AI Quiz Authentication Service
"""

import os
import sys
import subprocess
import time
import requests
from pathlib import Path

class TestRunner:
    def __init__(self):
        self.project_root = Path(__file__).parent
        self.success_count = 0
        self.failure_count = 0

    def run_command(self, command, description=""):
        """Run a command and return success status"""
        print(f"\n{'='*60}")
        print(f"🔧 {description}")
        print(f"{'='*60}")
        print(f"Command: {command}")
        
        try:
            result = subprocess.run(command, shell=True, check=True, capture_output=True, text=True)
            print("✅ SUCCESS")
            if result.stdout:
                print("Output:", result.stdout)
            self.success_count += 1
            return True
        except subprocess.CalledProcessError as e:
            print("❌ FAILED")
            print(f"Error: {e}")
            if e.stdout:
                print("Stdout:", e.stdout)
            if e.stderr:
                print("Stderr:", e.stderr)
            self.failure_count += 1
            return False

    def check_dependencies(self):
        """Check if required dependencies are available"""
        print("\n🔍 Checking Dependencies...")
        
        dependencies = [
            ("python", "python --version"),
            ("pip", "pip --version"),
            ("docker", "docker --version"),
            ("docker-compose", "docker-compose --version")
        ]
        
        for name, command in dependencies:
            if self.run_command(command, f"Checking {name}"):
                print(f"✅ {name} is available")
            else:
                print(f"❌ {name} is not available")
                return False
        return True

    def setup_environment(self):
        """Set up the testing environment"""
        print("\n🏗️ Setting up Environment...")
        
        # Install Python dependencies
        if not self.run_command("pip install -r requirements.txt", "Installing Python dependencies"):
            return False
            
        return True

    def run_unit_tests(self):
        """Run unit tests"""
        print("\n🧪 Running Unit Tests...")
        
        # Set PYTHONPATH
        env = os.environ.copy()
        env['PYTHONPATH'] = str(self.project_root)
        
        # Run pytest on unit tests
        command = "python -m pytest tests/unit/ -v --tb=short"
        return self.run_command(command, "Unit Tests")

    def start_test_services(self):
        """Start services for integration testing"""
        print("\n🚀 Starting Test Services...")
        
        # Clean up any existing containers
        self.run_command("docker-compose -f docker/docker-compose.yml down", "Cleaning up existing containers")
        
        # Start services
        if not self.run_command("docker-compose -f docker/docker-compose.yml up -d", "Starting services with Docker Compose"):
            return False
        
        # Wait for services to be ready
        print("⏳ Waiting for services to start...")
        time.sleep(15)
        
        # Check if services are healthy
        max_retries = 30
        for i in range(max_retries):
            try:
                response = requests.get("http://localhost:8000/health", timeout=5)
                if response.status_code == 200:
                    print("✅ Auth service is ready!")
                    return True
            except requests.exceptions.RequestException:
                pass
            
            print(f"⏳ Waiting for services... ({i+1}/{max_retries})")
            time.sleep(2)
        
        print("❌ Services failed to start within timeout")
        return False

    def run_integration_tests(self):
        """Run integration tests"""
        print("\n🔗 Running Integration Tests...")
        
        # Set PYTHONPATH
        env = os.environ.copy()
        env['PYTHONPATH'] = str(self.project_root)
        
        # Run pytest on integration tests
        command = "python -m pytest tests/integration/ -v --tb=short"
        return self.run_command(command, "Integration Tests")

    def test_api_endpoints(self):
        """Test API endpoints manually"""
        print("\n🌐 Testing API Endpoints...")
        
        base_url = "http://localhost:8000"
        
        # Test health endpoint
        try:
            response = requests.get(f"{base_url}/health")
            if response.status_code == 200:
                print("✅ Health endpoint working")
                self.success_count += 1
            else:
                print(f"❌ Health endpoint failed: {response.status_code}")
                self.failure_count += 1
        except Exception as e:
            print(f"❌ Health endpoint error: {e}")
            self.failure_count += 1

        # Test auth health endpoint
        try:
            response = requests.get(f"{base_url}/auth/health")
            if response.status_code == 200:
                print("✅ Auth health endpoint working")
                self.success_count += 1
            else:
                print(f"❌ Auth health endpoint failed: {response.status_code}")
                self.failure_count += 1
        except Exception as e:
            print(f"❌ Auth health endpoint error: {e}")
            self.failure_count += 1

        # Test user registration
        test_user = {
            "username": "testuser_api",
            "email": "testapi@example.com",
            "password": "TestPass123!",
            "full_name": "API Test User"
        }
        
        try:
            response = requests.post(f"{base_url}/auth/register", json=test_user)
            if response.status_code == 200:
                print("✅ User registration working")
                self.success_count += 1
                
                # Test login
                login_data = {"username": test_user["username"], "password": test_user["password"]}
                response = requests.post(f"{base_url}/auth/login", json=login_data)
                if response.status_code == 200:
                    print("✅ User login working")
                    self.success_count += 1
                    
                    # Test protected endpoint
                    token = response.json()["access_token"]
                    headers = {"Authorization": f"Bearer {token}"}
                    response = requests.get(f"{base_url}/auth/me", headers=headers)
                    if response.status_code == 200:
                        print("✅ Protected endpoint working")
                        self.success_count += 1
                    else:
                        print(f"❌ Protected endpoint failed: {response.status_code}")
                        self.failure_count += 1
                else:
                    print(f"❌ User login failed: {response.status_code}")
                    self.failure_count += 1
            else:
                print(f"❌ User registration failed: {response.status_code}")
                self.failure_count += 1
        except Exception as e:
            print(f"❌ API test error: {e}")
            self.failure_count += 1

    def cleanup_services(self):
        """Clean up test services"""
        print("\n🧹 Cleaning up services...")
        self.run_command("docker-compose -f docker/docker-compose.yml down", "Stopping services")

    def print_summary(self):
        """Print test summary"""
        total = self.success_count + self.failure_count
        success_rate = (self.success_count / total * 100) if total > 0 else 0
        
        print(f"\n{'='*60}")
        print("🎯 TEST SUMMARY")
        print(f"{'='*60}")
        print(f"✅ Successful: {self.success_count}")
        print(f"❌ Failed: {self.failure_count}")
        print(f"📊 Success Rate: {success_rate:.1f}%")
        print(f"{'='*60}")
        
        if self.failure_count == 0:
            print("🎉 ALL TESTS PASSED!")
            return True
        else:
            print("💥 SOME TESTS FAILED!")
            return False

    def run_all_tests(self):
        """Run all tests in sequence"""
        print("🚀 Starting Comprehensive Test Suite")
        print("=" * 60)
        
        # Check dependencies
        if not self.check_dependencies():
            print("❌ Dependencies check failed. Exiting.")
            return False
        
        # Setup environment
        if not self.setup_environment():
            print("❌ Environment setup failed. Exiting.")
            return False
        
        # Run unit tests
        self.run_unit_tests()
        
        # Start services and run integration tests
        if self.start_test_services():
            # Run integration tests
            self.run_integration_tests()
            
            # Test API endpoints
            self.test_api_endpoints()
            
            # Cleanup
            self.cleanup_services()
        else:
            print("❌ Failed to start services for integration tests")
            self.failure_count += 1
        
        # Print summary
        return self.print_summary()

def main():
    """Main entry point"""
    runner = TestRunner()
    
    if len(sys.argv) > 1:
        test_type = sys.argv[1].lower()
        if test_type == "unit":
            runner.setup_environment()
            runner.run_unit_tests()
        elif test_type == "integration":
            runner.setup_environment()
            if runner.start_test_services():
                runner.run_integration_tests()
                runner.cleanup_services()
        elif test_type == "api":
            runner.setup_environment()
            if runner.start_test_services():
                runner.test_api_endpoints()
                runner.cleanup_services()
        else:
            print("Usage: python run_tests.py [unit|integration|api]")
            return False
    else:
        # Run all tests
        success = runner.run_all_tests()
        sys.exit(0 if success else 1)
    
    runner.print_summary()
    return runner.failure_count == 0

if __name__ == "__main__":
    main()
