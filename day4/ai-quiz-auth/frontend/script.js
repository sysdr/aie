// Authentication Frontend JavaScript

class AuthApp {
    constructor() {
        this.token = localStorage.getItem('auth_token');
        this.user = null;
        this.init();
    }

    init() {
        this.setupEventListeners();
        this.checkSystemHealth();
        
        // Check if user is already logged in
        if (this.token) {
            this.getCurrentUser();
        }
    }

    setupEventListeners() {
        // Registration form
        const registerForm = document.getElementById('registerForm');
        if (registerForm) {
            registerForm.addEventListener('submit', this.handleRegister.bind(this));
        }

        // Login form
        const loginForm = document.getElementById('loginForm');
        if (loginForm) {
            loginForm.addEventListener('submit', this.handleLogin.bind(this));
        }
    }

    // API Helper Methods
    async apiRequest(endpoint, options = {}) {
        const url = endpoint.startsWith('http') ? endpoint : `${window.location.origin}${endpoint}`;
        
        const defaultOptions = {
            headers: {
                'Content-Type': 'application/json',
            }
        };

        if (this.token) {
            defaultOptions.headers['Authorization'] = `Bearer ${this.token}`;
        }

        const config = { ...defaultOptions, ...options };
        
        try {
            const response = await fetch(url, config);
            const data = await response.json();
            
            if (!response.ok) {
                throw new Error(data.detail || `HTTP error! status: ${response.status}`);
            }
            
            return data;
        } catch (error) {
            console.error('API Request failed:', error);
            throw error;
        }
    }

    // Authentication Methods
    async handleRegister(event) {
        event.preventDefault();
        
        const formData = new FormData(event.target);
        const userData = {
            username: formData.get('username'),
            email: formData.get('email'),
            password: formData.get('password'),
            full_name: formData.get('full_name') || null
        };

        try {
            this.showMessage('Creating your account...', 'info');
            
            const result = await this.apiRequest('/auth/register', {
                method: 'POST',
                body: JSON.stringify(userData)
            });

            this.showMessage('Account created successfully! Please login.', 'success');
            this.showLogin();
            event.target.reset();
            
        } catch (error) {
            this.showMessage(`Registration failed: ${error.message}`, 'error');
        }
    }

    async handleLogin(event) {
        event.preventDefault();
        
        const formData = new FormData(event.target);
        const loginData = {
            username: formData.get('username'),
            password: formData.get('password')
        };

        try {
            this.showMessage('Logging you in...', 'info');
            
            const result = await this.apiRequest('/auth/login', {
                method: 'POST',
                body: JSON.stringify(loginData)
            });

            this.token = result.access_token;
            localStorage.setItem('auth_token', this.token);
            
            this.showMessage('Login successful!', 'success');
            await this.getCurrentUser();
            
        } catch (error) {
            this.showMessage(`Login failed: ${error.message}`, 'error');
        }
    }

    async getCurrentUser() {
        try {
            const user = await this.apiRequest('/auth/me');
            this.user = user;
            this.showDashboard();
        } catch (error) {
            this.showMessage('Failed to get user info. Please login again.', 'error');
            this.logout();
        }
    }

    async logout() {
        try {
            if (this.token) {
                await this.apiRequest('/auth/logout', { method: 'POST' });
            }
        } catch (error) {
            console.log('Logout request failed:', error);
        } finally {
            this.token = null;
            this.user = null;
            localStorage.removeItem('auth_token');
            this.showLogin();
            this.showMessage('Logged out successfully!', 'success');
        }
    }

    async testAuthenticatedRequest() {
        try {
            this.showMessage('Testing authenticated request...', 'info');
            
            const result = await this.apiRequest('/auth/me');
            this.showMessage('✅ Authentication working correctly!', 'success');
            
            console.log('Current user data:', result);
        } catch (error) {
            this.showMessage(`❌ Authentication test failed: ${error.message}`, 'error');
        }
    }

    // UI Methods
    showRegister() {
        document.getElementById('register-form').style.display = 'block';
        document.getElementById('login-form').style.display = 'none';
        document.getElementById('user-dashboard').style.display = 'none';
    }

    showLogin() {
        document.getElementById('register-form').style.display = 'none';
        document.getElementById('login-form').style.display = 'block';
        document.getElementById('user-dashboard').style.display = 'none';
    }

    showDashboard() {
        document.getElementById('register-form').style.display = 'none';
        document.getElementById('login-form').style.display = 'none';
        document.getElementById('user-dashboard').style.display = 'block';
        
        // Populate user data
        if (this.user) {
            document.getElementById('user-name').textContent = this.user.full_name || this.user.username;
            document.getElementById('dashboard-username').textContent = this.user.username;
            document.getElementById('dashboard-email').textContent = this.user.email;
            document.getElementById('dashboard-created').textContent = new Date(this.user.created_at).toLocaleDateString();
            document.getElementById('dashboard-last-login').textContent = 
                this.user.last_login ? new Date(this.user.last_login).toLocaleString() : 'First login';
        }
    }

    showMessage(message, type = 'info') {
        const container = document.getElementById('message-container');
        const messageDiv = document.createElement('div');
        messageDiv.className = `message ${type}`;
        messageDiv.textContent = message;
        
        container.appendChild(messageDiv);
        
        // Auto remove after 5 seconds
        setTimeout(() => {
            if (messageDiv.parentNode) {
                messageDiv.parentNode.removeChild(messageDiv);
            }
        }, 5000);
    }

    async checkSystemHealth() {
        // Check main service health
        try {
            await this.apiRequest('/health');
            this.updateStatusIndicator('auth-status', 'healthy', 'Healthy');
        } catch (error) {
            this.updateStatusIndicator('auth-status', 'error', 'Error');
        }

        // Check auth service health
        try {
            await this.apiRequest('/auth/health');
            this.updateStatusIndicator('db-status', 'healthy', 'Connected');
        } catch (error) {
            this.updateStatusIndicator('db-status', 'error', 'Error');
        }
    }

    updateStatusIndicator(elementId, status, text) {
        const element = document.getElementById(elementId);
        if (element) {
            element.className = `status-indicator ${status}`;
            element.textContent = text;
        }
    }
}

// Global functions for HTML onclick handlers
function showRegister() {
    app.showRegister();
}

function showLogin() {
    app.showLogin();
}

function logout() {
    app.logout();
}

function testAuthenticatedRequest() {
    app.testAuthenticatedRequest();
}

// Initialize app when DOM is loaded
let app;
document.addEventListener('DOMContentLoaded', () => {
    app = new AuthApp();
});
