#!/usr/bin/env python3

import subprocess
import sys
import asyncio
import time

def run_command(cmd, description):
    print(f"\n🔍 {description}")
    print(f"Running: {cmd}")
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    
    if result.returncode == 0:
        print(f"✅ {description} - SUCCESS")
        if result.stdout:
            print(f"Output: {result.stdout[:500]}")
    else:
        print(f"❌ {description} - FAILED")
        print(f"Error: {result.stderr}")
        return False
    return True

async def main():
    print("🧪 Running Quiz Session Management Tests")
    
    tests = [
        ("python3 -m pytest tests/unit/ -v", "Unit Tests"),
        ("python3 -m pytest tests/integration/ -v", "Integration Tests"),
        ("python3 -c \"import src.models.attempt; print('✅ Models import OK')\"", "Model Validation"),
        ("python3 -c \"import src.services.session_manager; print('✅ Services import OK')\"", "Service Validation"),
    ]
    
    all_passed = True
    for cmd, desc in tests:
        if not run_command(cmd, desc):
            all_passed = False
    
    if all_passed:
        print("\n🎉 All tests passed! System is ready for deployment.")
    else:
        print("\n⚠️  Some tests failed. Check the output above.")
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())
