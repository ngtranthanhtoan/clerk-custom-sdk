# 🔨 JavaScript/Web Clerk SDK: Complete Development Guide

> **Build, integrate, and troubleshoot a complete Clerk authentication SDK for web applications**

## 📋 Table of Contents

### Part I: SDK Architecture & Development
1. [SDK Architecture Overview](#sdk-architecture-overview)
2. [Core API Client Component](#core-api-client-component)
3. [Environment Discovery Component](#environment-discovery-component)
4. [Client Manager Component](#client-manager-component)
5. [Development Browser Handler Component](#development-browser-handler-component)
6. [Authentication Flow Components](#authentication-flow-components)
7. [Session Manager Component](#session-manager-component)
8. [Token Manager Component](#token-manager-component)
9. [User Manager Component](#user-manager-component)
10. [Organization Manager Component](#organization-manager-component)

### Part II: Integration & Usage
11. [Quick Start Integration](#quick-start-integration)
12. [Authentication Examples](#authentication-examples)
13. [Session Management](#session-management-examples)
14. [Framework Integration Examples](#framework-integration-examples)

### Part III: Advanced Topics & Troubleshooting
15. [Session Persistence Troubleshooting](#session-persistence-troubleshooting)
16. [Production Best Practices](#production-best-practices)
17. [Complete SDK Integration](#complete-sdk-integration)

---

# Part I: SDK Architecture & Development

## 🏗️ SDK Architecture Overview

### How REST API Maps to SDK Components

```
┌─────────────────────────────────────────────────────────────────┐
│                        Clerk SDK                                │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    Built using    ┌───────────────────────┐ │
│  │ SDK Component   │  ───────────────► │   REST API Calls     │ │
│  └─────────────────┘                   └───────────────────────┘ │
│                                                                 │
│  Environment Discovery ──────────────► GET /environment         │
│  Client Manager ─────────────────────► GET/PUT /client          │
│  Dev Browser Handler ─────────────────► POST /dev_browser       │
│  Sign-In Flow ────────────────────────► POST /client/sign_ins   │
│  Sign-Up Flow ────────────────────────► POST /client/sign_ups   │
│  Session Manager ─────────────────────► GET/POST/DELETE session │
│  Token Manager ───────────────────────► POST /tokens            │
│  User Manager ────────────────────────► GET/PATCH /me           │
│  Organization Manager ────────────────► GET/POST /organizations │
└─────────────────────────────────────────────────────────────────┘
```

### Core Principle
**Each SDK component encapsulates specific REST API endpoints and handles their request/response patterns, state management, and error handling.**

---

## 🔧 Core API Client Component

### Purpose
The foundation that all other components use to make HTTP requests with CORS workarounds.

### REST API Foundation
The API client solves the fundamental challenge: **How to make HTTP requests to Clerk's API without triggering CORS preflight requests.**

### Implementation

```javascript
class ClerkAPIClient {
  constructor(domain, devBrowserJWT = null) {
    this.domain = domain;
    this.devBrowserJWT = devBrowserJWT;
    this.apiVersion = '2025-04-10';
    this.jsVersion = '5.88.0';
  }

  // Core URL builder - handles CORS workaround
  buildURL(path, params = {}, originalMethod = 'GET') {
    const url = new URL(`https://${this.domain}/v1${path}`);
    
    // Required Clerk parameters for all requests
    url.searchParams.set('__clerk_api_version', this.apiVersion);
    url.searchParams.set('_clerk_js_version', this.jsVersion);
    
    // CORS workaround: Use _method parameter instead of actual HTTP method
    if (originalMethod !== 'GET' && originalMethod !== 'POST') {
      url.searchParams.set('_method', originalMethod);
    }
    
    // Dev browser JWT for development instances
    if (this.devBrowserJWT && this.isDevInstance()) {
      url.searchParams.set('__clerk_db_jwt', this.devBrowserJWT);
    }
    
    // Custom parameters
    Object.entries(params).forEach(([key, value]) => {
      if (value != null) url.searchParams.set(key, value);
    });
    
    return url.toString();
  }

  // Core HTTP method - all SDK components use this
  async request(path, options = {}) {
    const { method = 'GET', body, params = {} } = options;
    
    // Convert all methods to GET/POST to avoid preflight
    const actualMethod = method === 'GET' ? 'GET' : 'POST';
    const url = this.buildURL(path, params, method);
    
    const fetchOptions = {
      method: actualMethod,
      credentials: 'include', // CRITICAL for session persistence
    };
    
    // Handle request body for POST requests
    if (actualMethod === 'POST' && body) {
      if (body instanceof FormData) {
        fetchOptions.body = body;
      } else {
        fetchOptions.headers = { 'Content-Type': 'application/x-www-form-urlencoded' };
        fetchOptions.body = new URLSearchParams(body);
      }
    }
    
    const response = await fetch(url, fetchOptions);
    const data = await response.json();
    
    if (!response.ok) {
      throw this.createError(data, response.status);
    }
    
    return { data, status: response.status };
  }

  createError(data, status, defaultCode = 'api_error') {
    const errors = data.errors || [];
    const primaryError = errors[0] || {};
    
    const error = new Error(primaryError.long_message || primaryError.message || 'Unknown error');
    error.name = 'ClerkError';
    error.code = primaryError.code || defaultCode;
    error.status = status;
    error.errors = errors;
    error.timestamp = new Date();
    
    return error;
  }
}
```

---

## 🌐 Environment Discovery Component

### Purpose
Fetch and cache instance configuration from Clerk's servers.

### REST API Foundation
**GET /environment** - Returns instance settings, available auth strategies, and UI configuration.

### Implementation

```javascript
class EnvironmentManager {
  constructor(apiClient) {
    this.client = apiClient;
    this.environment = null;
  }

  async fetchEnvironment() {
    try {
      console.log('📋 Fetching environment configuration...');
      
      // REST API Call: GET /environment
      const { data } = await this.client.request('/environment');
      
      this.environment = data.response;
      
      console.log('Environment loaded:', {
        instance_type: this.environment.instance_type,
        auth_strategies: this.environment.user_settings?.enabled_strategies,
        sign_up_mode: this.environment.display_config?.sign_up_mode
      });
      
      return this.environment;
    } catch (error) {
      console.error('❌ Failed to fetch environment:', error);
      throw error;
    }
  }

  get authStrategies() {
    return this.environment?.user_settings?.enabled_strategies || [];
  }

  get signUpMode() {
    return this.environment?.display_config?.sign_up_mode || 'public';
  }

  get isDevelopment() {
    return this.environment?.instance_type === 'development';
  }
}
```

---

## 🔌 Client Manager Component

### Purpose
Establish and maintain connection with Clerk's client infrastructure.

### REST API Foundation
**PUT /client** - Creates or updates client session, **GET /client** - Retrieves current client state.

### Implementation

```javascript
class ClientManager {
  constructor(apiClient) {
    this.client = apiClient;
    this.clientData = null;
  }

  async createClient() {
    try {
      console.log('🔗 Creating/updating client...');
      
      // REST API Call: PUT /client - Establishes client connection
      const { data } = await this.client.request('/client', {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        }
      });
      
      this.clientData = data.response;
      
      console.log('Client ready:', {
        id: this.clientData.id,
        sessions: this.clientData.sessions?.length || 0,
        last_active_session: this.clientData.last_active_session_id
      });
      
      return this.clientData;
    } catch (error) {
      // Fallback: Try to get existing client
      if (error.message.includes('authenticate this browser')) {
        console.warn('⚠️ Browser auth required, trying to get existing client...');
        return await this.getExistingClient();
      }
      throw error;
    }
  }

  async getExistingClient() {
    try {
      // REST API Call: GET /client - Gets existing client data
      const { data } = await this.client.request('/client');
      this.clientData = data.response;
      return this.clientData;
    } catch (error) {
      throw new Error(
        'Unable to authenticate with Clerk development instance. ' +
        'Please visit your Clerk dashboard to establish authentication cookies.'
      );
    }
  }

  get activeSessions() {
    return this.clientData?.sessions?.filter(s => s.status === 'active') || [];
  }

  get lastActiveSessionId() {
    return this.clientData?.last_active_session_id;
  }
}
```

---

## 🔐 Development Browser Handler Component

### Purpose
Handle development instance authentication requirements.

### REST API Foundation
**POST /dev_browser** - Authenticates browser for development instances.

### Implementation

```javascript
class DevBrowserHandler {
  constructor(apiClient) {
    this.client = apiClient;
    this.devBrowserJWT = null;
  }

  isDevInstance() {
    return this.client.domain.includes('.clerk.accounts.dev') || 
           this.client.domain.includes('.lclclerk.com');
  }

  async setupDevBrowser() {
    if (!this.isDevInstance()) {
      console.log('📝 Production instance - skipping dev browser setup');
      return;
    }

    console.log('🔧 Setting up development browser authentication...');

    // Step 1: Check URL for JWT (from dashboard redirect)
    const jwtFromUrl = this.getDevBrowserJWTFromURL();
    if (jwtFromUrl) {
      this.setDevBrowserJWTCookie(jwtFromUrl);
      this.cleanupURL();
      return;
    }

    // Step 2: Check existing cookie
    const jwtFromCookie = this.getDevBrowserJWTFromCookie();
    if (jwtFromCookie) {
      this.devBrowserJWT = jwtFromCookie;
      return;
    }

    // Step 3: Request new JWT
    await this.requestDevBrowserJWT();
  }

  async requestDevBrowserJWT() {
    try {
      // REST API Call: POST /dev_browser - Request browser authentication
      const { data } = await this.client.request('/dev_browser', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: new URLSearchParams({
          redirect_url: window.location.href
        })
      });

      if (data.response?.redirect_url) {
        console.log('🔄 Redirecting to authenticate browser...');
        window.location.href = data.response.redirect_url;
      }
    } catch (error) {
      console.error('❌ Dev browser authentication failed:', error);
      throw error;
    }
  }

  getDevBrowserJWTFromURL() {
    try {
      const url = new URL(window.location.href);
      return url.searchParams.get('__clerk_db_jwt');
    } catch {
      return null;
    }
  }

  getDevBrowserJWTFromCookie() {
    try {
      const cookies = document.cookie.split(';');
      for (let cookie of cookies) {
        const [name, value] = cookie.trim().split('=');
        if (name === '__clerk_db_jwt') {
          return decodeURIComponent(value);
        }
      }
    } catch {
      return null;
    }
  }

  setDevBrowserJWTCookie(jwt) {
    try {
      document.cookie = `__clerk_db_jwt=${encodeURIComponent(jwt)}; path=/; SameSite=strict`;
      this.devBrowserJWT = jwt;
      this.client.devBrowserJWT = jwt;
      console.log('✅ Dev browser JWT stored');
    } catch (error) {
      console.warn('Failed to set dev browser JWT cookie:', error);
    }
  }

  cleanupURL() {
    try {
      const url = new URL(window.location.href);
      url.searchParams.delete('__clerk_db_jwt');
      window.history.replaceState({}, '', url.toString());
    } catch (error) {
      console.warn('Failed to clean up URL:', error);
    }
  }
}
```

---

## 🔑 Authentication Flow Components

### Sign-In Flow Component

Handles multi-step sign-in process with various authentication strategies.

### REST API Foundation
- `POST /client/sign_ins` - Initiate sign-in
- `POST /client/sign_ins/{id}/attempt_first_factor` - Submit credentials
- `POST /client/sign_ins/{id}/prepare_first_factor` - Prepare verification

### Implementation

```javascript
class SignInFlow {
  constructor(apiClient) {
    this.client = apiClient;
    this.signInAttempt = null;
  }

  async create(identifier) {
    try {
      console.log('🔄 Creating sign-in attempt for:', identifier);
      
      // REST API Call: POST /client/sign_ins
      const { data } = await this.client.request('/client/sign_ins', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: new URLSearchParams({ identifier })
      });
      
      this.signInAttempt = data.response;
      
      console.log('✅ Sign-in attempt created:', {
        id: this.signInAttempt.id,
        supportedFactors: this.signInAttempt.supported_first_factors?.map(f => f.strategy)
      });
      
      return this.signInAttempt;
    } catch (error) {
      console.error('❌ Failed to create sign-in:', error);
      throw error;
    }
  }

  async attemptFirstFactor(params) {
    if (!this.signInAttempt) {
      throw new Error('Must create sign-in attempt first');
    }

    try {
      console.log('🔄 Attempting first factor authentication...');
      
      // REST API Call: POST /client/sign_ins/{id}/attempt_first_factor
      const body = new URLSearchParams(params);
      const { data } = await this.client.request(
        `/client/sign_ins/${this.signInAttempt.id}/attempt_first_factor`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded'
          },
          body
        }
      );
      
      this.signInAttempt = data.response;
      
      if (this.signInAttempt.status === 'complete') {
        console.log('🎉 Authentication successful!');
        // Session will be available in data.client.sessions
        return { success: true, session: data.client.sessions.find(s => 
          s.id === this.signInAttempt.created_session_id
        )};
      }
      
      return { success: false, attempt: this.signInAttempt };
    } catch (error) {
      console.error('❌ First factor attempt failed:', error);
      throw error;
    }
  }

  // Convenience methods
  async authenticateWithPassword(identifier, password) {
    await this.create(identifier);
    return this.attemptFirstFactor({ strategy: 'password', password });
  }

  async authenticateWithEmailCode(identifier) {
    await this.create(identifier);
    return this.prepareFirstFactor({ strategy: 'email_code' });
  }

  async prepareFirstFactor(params) {
    if (!this.signInAttempt) {
      throw new Error('Must create sign-in attempt first');
    }

    try {
      // REST API Call: POST /client/sign_ins/{id}/prepare_first_factor
      const { data } = await this.client.request(
        `/client/sign_ins/${this.signInAttempt.id}/prepare_first_factor`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded'
          },
          body: new URLSearchParams(params)
        }
      );
      
      this.signInAttempt = data.response;
      console.log('✅ First factor prepared:', params.strategy);
      return this.signInAttempt;
    } catch (error) {
      console.error('❌ Failed to prepare first factor:', error);
      throw error;
    }
  }
}
```

### Sign-Up Flow Component

```javascript
class SignUpFlow {
  constructor(apiClient) {
    this.client = apiClient;
    this.signUpAttempt = null;
  }

  async create(userData) {
    try {
      console.log('🔄 Creating sign-up attempt...');
      
      // REST API Call: POST /client/sign_ups
      const { data } = await this.client.request('/client/sign_ups', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: new URLSearchParams(userData)
      });
      
      this.signUpAttempt = data.response;
      
      console.log('✅ Sign-up attempt created:', {
        id: this.signUpAttempt.id,
        status: this.signUpAttempt.status,
        unverifiedFields: this.signUpAttempt.unverified_fields
      });
      
      return this.signUpAttempt;
    } catch (error) {
      console.error('❌ Failed to create sign-up:', error);
      throw error;
    }
  }

  async attemptVerification(params) {
    if (!this.signUpAttempt) {
      throw new Error('Must create sign-up attempt first');
    }

    try {
      // REST API Call: POST /client/sign_ups/{id}/attempt_verification
      const { data } = await this.client.request(
        `/client/sign_ups/${this.signUpAttempt.id}/attempt_verification`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded'
          },
          body: new URLSearchParams(params)
        }
      );
      
      this.signUpAttempt = data.response;
      
      if (this.signUpAttempt.status === 'complete') {
        console.log('🎉 Sign-up successful!');
        return { success: true, session: data.client.sessions.find(s => 
          s.id === this.signUpAttempt.created_session_id
        )};
      }
      
      return { success: false, attempt: this.signUpAttempt };
    } catch (error) {
      console.error('❌ Verification attempt failed:', error);
      throw error;
    }
  }

  // Convenience method for email sign-up
  async signUpWithEmail(emailAddress, password, options = {}) {
    const userData = { 
      email_address: emailAddress, 
      password, 
      ...options 
    };
    
    await this.create(userData);
    
    if (this.signUpAttempt.unverified_fields?.includes('email_address')) {
      await this.prepareVerification({ strategy: 'email_code' });
    }
    
    return this.signUpAttempt;
  }
}
```

---

## 🎯 Session Manager Component

### Purpose
Manage session lifecycle including validation, refresh, and termination.

### REST API Foundation
- `GET /client/sessions/{id}` - Get session details
- `POST /client/sessions/{id}/touch` - Refresh session
- `DELETE /client/sessions/{id}` - Sign out session

### Implementation

```javascript
class SessionManager {
  constructor(apiClient, onSessionChange) {
    this.client = apiClient;
    this.onSessionChange = onSessionChange;
    this.currentSession = null;
    this.refreshTimer = null;
  }

  setSession(session) {
    this.currentSession = session;
    this.startAutoRefresh();
    this.onSessionChange('created', session);
    console.log('Session set:', {
      id: session.id,
      userId: session.user.id,
      email: session.user.email_addresses[0]?.email_address
    });
  }

  clearSession() {
    if (this.currentSession) {
      this.stopAutoRefresh();
      const oldSession = this.currentSession;
      this.currentSession = null;
      this.onSessionChange('destroyed', oldSession);
      console.log('Session cleared');
    }
  }

  async validateSession(sessionId = this.currentSession?.id) {
    if (!sessionId) return { isValid: false, error: 'No session ID' };

    try {
      // REST API Call: GET /client/sessions/{id}
      const { data } = await this.client.request(`/client/sessions/${sessionId}`, {
        params: { _clerk_session_id: sessionId }
      });

      const session = data.response;
      const isValid = session.status === 'active' && new Date(session.expire_at) > new Date();

      console.log('Session validation:', { isValid, status: session.status });
      return { isValid, session };
    } catch (error) {
      console.error('Session validation failed:', error);
      return { isValid: false, error: error.message };
    }
  }

  async refreshSession(sessionId = this.currentSession?.id) {
    if (!sessionId) return false;

    try {
      // REST API Call: POST /client/sessions/{id}/touch
      const { data } = await this.client.request(`/client/sessions/${sessionId}/touch`, {
        method: 'POST',
        params: { _clerk_session_id: sessionId }
      });

      // Update current session if it was refreshed
      if (sessionId === this.currentSession?.id) {
        this.currentSession = { ...this.currentSession, ...data.response };
      }

      console.log('Session refreshed:', data.response.id);
      return true;
    } catch (error) {
      console.error('Session refresh failed:', error);
      if (error.message.includes('session_invalid')) {
        this.clearSession();
      }
      return false;
    }
  }

  async signOut(sessionId = this.currentSession?.id) {
    if (!sessionId) return;

    try {
      // REST API Call: DELETE /client/sessions/{id}
      await this.client.request(`/client/sessions/${sessionId}`, {
        method: 'DELETE',
        params: { _clerk_session_id: sessionId }
      });

      // Clear session if it was the current one
      if (sessionId === this.currentSession?.id) {
        this.clearSession();
      }

      console.log('Session signed out:', sessionId);
    } catch (error) {
      console.error('Sign out failed:', error);
      throw error;
    }
  }

  async signOutAll() {
    try {
      // REST API Call: DELETE /client/sessions
      await this.client.request('/client/sessions', {
        method: 'DELETE'
      });

      this.clearSession();
      console.log('All sessions signed out');
    } catch (error) {
      console.error('Sign out all failed:', error);
      throw error;
    }
  }

  startAutoRefresh() {
    this.stopAutoRefresh();
    this.refreshTimer = setInterval(async () => {
      if (this.currentSession) {
        await this.refreshSession();
      }
    }, 5 * 60 * 1000); // Every 5 minutes
  }

  stopAutoRefresh() {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer);
      this.refreshTimer = null;
    }
  }

  get isSignedIn() {
    return !!this.currentSession && this.currentSession.status === 'active';
  }
}
```

### 🔄 Session Persistence and Restoration

**Critical Component**: How users stay logged in when they return to your application.

#### REST API Foundation for Session Persistence

The session persistence system is built on two key REST API patterns:

1. **Session Discovery** - `GET /client` - Discovers existing active sessions
2. **Session Storage** - Browser cookies + LocalStorage caching

#### Implementation: Automatic Session Restoration

```javascript
class SessionPersistence {
  constructor(apiClient, sessionManager) {
    this.client = apiClient;
    this.sessionManager = sessionManager;
    this.storage = {
      get: (key) => {
        try {
          return JSON.parse(localStorage.getItem(key));
        } catch {
          return null;
        }
      },
      set: (key, value) => localStorage.setItem(key, JSON.stringify(value)),
      remove: (key) => localStorage.removeItem(key)
    };
  }

  // Called during SDK initialization
  async restoreSession() {
    try {
      console.log('🔄 Checking for existing session...');
      
      // First, check if we have a cached session in localStorage
      const cachedData = this.storage.get('clerk_session_cache');
      
      if (cachedData?.session) {
        console.log('📦 Found cached session, validating...');
        
        // Check session expiry first
        const sessionExpiry = new Date(cachedData.session.expire_at);
        if (sessionExpiry <= new Date()) {
          this.storage.remove('clerk_session_cache');
          console.log('⚠️ Cached session expired');
        } else {
          // For recent sessions, trust the cache directly
          const cacheAge = Date.now() - cachedData.timestamp;
          const recentCacheTime = 6 * 60 * 60 * 1000; // 6 hours
          
          if (cacheAge < recentCacheTime) {
            console.log('🚀 Using cached session directly (development mode)');
            this._restoreSession(cachedData.session, 'cache-direct');
            return cachedData.session;
          }
        }
      }
      
      // No valid cached session, try to get sessions from server
      console.log('🌐 Checking server for active sessions...');
      const { data } = await this.client.request('/client');
      const client = data.response;
      const activeSessions = client.sessions.filter(s => s.status === 'active');
      
      if (activeSessions.length > 0) {
        const currentSession = activeSessions.find(s => 
          s.id === client.last_active_session_id
        ) || activeSessions[0];
        
        this._restoreSession(currentSession, 'server-fresh');
        return currentSession;
      } else {
        console.log('ℹ️ No active sessions found');
        return null;
      }
    } catch (error) {
      console.warn('⚠️ Failed to restore session:', error.message);
      return null;
    }
  }

  _restoreSession(session, source) {
    // Set session state
    this.sessionManager.setSession(session);
    
    // Cache session for next time
    this.storage.set('clerk_session_cache', {
      session,
      timestamp: Date.now()
    });
    
    console.log(`✅ Session restored from ${source}:`, {
      userId: session.user?.id,
      email: session.user?.email_addresses[0]?.email_address
    });
  }
}
```

---

## 🎟️ Token Manager Component

### Purpose
Generate and cache JWT tokens for API authentication.

### REST API Foundation
**POST /client/sessions/{id}/tokens** - Generate JWT token with optional template.

### Implementation

```javascript
class TokenManager {
  constructor(apiClient) {
    this.client = apiClient;
    this.tokenCache = new Map();
  }

  async getToken(sessionId, template = '') {
    if (!sessionId) {
      throw new Error('Session ID required for token generation');
    }

    // Check cache first (with 5-minute buffer before expiry)
    const cacheKey = `${sessionId}-${template}`;
    const cached = this.tokenCache.get(cacheKey);
    
    if (cached && cached.expiresAt > new Date(Date.now() + 5 * 60 * 1000)) {
      console.log('Using cached token');
      return cached.jwt;
    }

    try {
      console.log('🎟️ Generating fresh token...');
      
      // REST API Call: POST /client/sessions/{id}/tokens
      const { data } = await this.client.request(
        `/client/sessions/${sessionId}/tokens`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded'
          },
          body: new URLSearchParams({ template }),
          params: { _clerk_session_id: sessionId }
        }
      );

      const jwt = data.response.jwt;
      
      // Decode to get expiry and cache
      const payload = this.decodeJWT(jwt);
      if (payload?.exp) {
        this.tokenCache.set(cacheKey, {
          jwt,
          expiresAt: new Date(payload.exp * 1000)
        });
      }

      console.log('✅ Token generated successfully');
      return jwt;
    } catch (error) {
      console.error('❌ Token generation failed:', error);
      throw error;
    }
  }

  decodeJWT(token) {
    try {
      const parts = token.split('.');
      if (parts.length !== 3) return null;
      
      const payload = atob(parts[1]);
      return JSON.parse(payload);
    } catch {
      return null;
    }
  }

  isTokenExpired(token) {
    const decoded = this.decodeJWT(token);
    if (!decoded?.exp) return true;
    
    return Date.now() >= decoded.exp * 1000;
  }

  clearCache() {
    this.tokenCache.clear();
    console.log('🗑️ Token cache cleared');
  }
}
```

---

## 👤 User Manager Component

### Purpose
Handle user profile operations and data management.

### REST API Foundation
- **GET /me** - Get current user data
- **PATCH /me** - Update user profile

### Implementation

```javascript
class UserManager {
  constructor(apiClient, sessionManager) {
    this.client = apiClient;
    this.sessionManager = sessionManager;
    this.currentUser = null;
  }

  async getCurrentUser() {
    const session = this.sessionManager.currentSession;
    if (!session) return null;

    try {
      console.log('👤 Fetching current user...');
      
      // REST API Call: GET /me
      const { data } = await this.client.request('/me', {
        params: { _clerk_session_id: session.id }
      });

      this.currentUser = data.response;
      
      console.log('✅ User data loaded:', {
        id: this.currentUser.id,
        email: this.currentUser.email_addresses[0]?.email_address,
        verified: this.currentUser.email_addresses[0]?.verification?.status
      });

      return this.currentUser;
    } catch (error) {
      console.error('❌ Failed to get user:', error);
      
      if (error.status === 401) {
        this.sessionManager.clearSession();
      }
      
      throw error;
    }
  }

  async updateUser(updates) {
    const session = this.sessionManager.currentSession;
    if (!session) {
      throw new Error('Authentication required');
    }

    try {
      console.log('🔄 Updating user profile...');
      
      // REST API Call: PATCH /me
      const { data } = await this.client.request('/me', {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: new URLSearchParams(updates),
        params: { _clerk_session_id: session.id }
      });

      this.currentUser = data.response;
      
      console.log('✅ User profile updated:', updates);
      return this.currentUser;
    } catch (error) {
      console.error('❌ Failed to update user:', error);
      throw error;
    }
  }

  get user() {
    return this.sessionManager.currentSession?.user || this.currentUser;
  }

  get isEmailVerified() {
    const user = this.user;
    return user?.email_addresses[0]?.verification?.status === 'verified';
  }

  get primaryEmail() {
    return this.user?.email_addresses[0]?.email_address;
  }

  get fullName() {
    const user = this.user;
    const firstName = user?.first_name || '';
    const lastName = user?.last_name || '';
    return `${firstName} ${lastName}`.trim() || null;
  }
}
```

---

## 🏢 Organization Manager Component

### Purpose
Handle organization operations including creation, listing, and management.

### REST API Foundation
- **GET /organizations** - List user's organizations
- **POST /organizations** - Create new organization
- **POST /client/sessions/{id}/touch** - Set active organization

### Implementation

```javascript
class OrganizationManager {
  constructor(apiClient, sessionManager) {
    this.client = apiClient;
    this.sessionManager = sessionManager;
    this.organizations = [];
  }

  async listOrganizations() {
    const session = this.sessionManager.currentSession;
    if (!session) {
      throw new Error('Authentication required');
    }

    try {
      console.log('🏢 Fetching organizations...');
      
      // REST API Call: GET /organizations
      const { data } = await this.client.request('/organizations', {
        params: { _clerk_session_id: session.id }
      });

      this.organizations = data.response;
      
      console.log('✅ Organizations loaded:', {
        count: this.organizations.length,
        names: this.organizations.map(org => org.name)
      });

      return this.organizations;
    } catch (error) {
      console.error('❌ Failed to list organizations:', error);
      throw error;
    }
  }

  async createOrganization(name, slug) {
    const session = this.sessionManager.currentSession;
    if (!session) {
      throw new Error('Authentication required');
    }

    try {
      console.log('🔄 Creating organization:', { name, slug });
      
      // REST API Call: POST /organizations
      const { data } = await this.client.request('/organizations', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: new URLSearchParams({ name, slug }),
        params: { _clerk_session_id: session.id }
      });

      const organization = data.response;
      this.organizations.push(organization);
      
      console.log('✅ Organization created:', organization.name);
      return organization;
    } catch (error) {
      console.error('❌ Failed to create organization:', error);
      throw error;
    }
  }

  async setActiveOrganization(organizationId) {
    const session = this.sessionManager.currentSession;
    if (!session) {
      throw new Error('Authentication required');
    }

    try {
      console.log('🔄 Setting active organization:', organizationId);
      
      // REST API Call: POST /client/sessions/{id}/touch
      const { data } = await this.client.request(`/client/sessions/${session.id}/touch`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: new URLSearchParams({ active_organization_id: organizationId }),
        params: { _clerk_session_id: session.id }
      });

      // Update current session with new organization context
      const updatedSession = data.response;
      this.sessionManager.setSession(updatedSession);
      
      console.log('✅ Active organization set');
      return updatedSession.organization;
    } catch (error) {
      console.error('❌ Failed to set active organization:', error);
      throw error;
    }
  }

  get activeOrganization() {
    return this.sessionManager.currentSession?.organization;
  }

  get userOrganizations() {
    return this.organizations.filter(org => 
      org.members.some(member => member.public_user_data.user_id === this.sessionManager.currentSession?.user?.id)
    );
  }
}
```

---

# Part II: Integration & Usage

## 🚀 Quick Start Integration

### Installation & Setup

#### 1. Include the SDK
```html
<!-- Option 1: Direct script include -->
<script src="clerk-sdk.js"></script>

<!-- Option 2: ES6 Module -->
<script type="module">
  import ClerkSDK from './clerk-sdk.js';
</script>
```

#### 2. Initialize
```javascript
const clerk = new ClerkSDK({
  domain: 'your-instance.clerk.accounts.dev' // Replace with your domain
});

// Load the SDK
await clerk.load();
```

---

## 🔐 Authentication Examples

### Sign In with Email/Password
```javascript
const signIn = clerk.signIn();
const result = await signIn.authenticateWithPassword('user@example.com', 'password123');

if (result.status === 'complete') {
  console.log('Signed in!', clerk.user);
}
```

### Sign In with Email Code
```javascript
const signIn = clerk.signIn();

// Send code
await signIn.authenticateWithEmailCode('user@example.com');

// User enters code, then verify
const result = await signIn.submitEmailCode('123456');
```

### Sign Up
```javascript
const signUp = clerk.signUp();

// Create account
await signUp.signUpWithEmail('newuser@example.com', 'password123', {
  firstName: 'John',
  lastName: 'Doe'
});

// Verify email
const result = await signUp.verifyEmail('123456');
```

---

## 🎯 Session Management Examples

### Check Authentication Status
```javascript
if (clerk.isSignedIn) {
  console.log('User is authenticated:', clerk.user.email_addresses[0].email_address);
} else {
  console.log('User not authenticated');
}
```

### Get Current User (Cached)
```javascript
// Get current user from cache (instant)
const user = clerk.getCurrentUser();
// or 
const user = clerk.user;

if (user) {
  console.log('User Info:', {
    id: user.id,
    email: user.email_addresses[0]?.email_address,
    firstName: user.first_name,
    lastName: user.last_name,
    createdAt: new Date(user.created_at).toLocaleString(),
    emailVerified: user.email_addresses[0]?.verification?.status === 'verified'
  });
}
```

### Get Fresh User Data
```javascript
// Fetch latest user data from server
const user = await clerk.getUser();

if (user) {
  console.log('Fresh user data:', user);
  // User data is automatically updated in cache
}
```

### Update User Profile
```javascript
const updatedUser = await clerk.updateUser({
  first_name: 'John',
  last_name: 'Doe'
});

console.log('User updated:', updatedUser);
```

### Get JWT Token
```javascript
const token = await clerk.getToken();
console.log('JWT:', token);

// Use token for API calls
const response = await fetch('/api/protected', {
  headers: {
    'Authorization': `Bearer ${token}`
  }
});
```

### Sign Out
```javascript
// Sign out current session
await clerk.signOut();

// Sign out all sessions
await clerk.signOutAll();
```

## 📡 Event Handling

```javascript
// Listen for authentication events
clerk.addListener('sessionCreated', (data) => {
  console.log('User signed in:', data.session);
  updateUI();
});

clerk.addListener('sessionDestroyed', (data) => {
  console.log('User signed out');
  updateUI();
});

clerk.addListener('userUpdated', (data) => {
  console.log('User profile updated:', data.user);
});
```

## ❌ Error Handling

```javascript
try {
  const signIn = clerk.signIn();
  await signIn.authenticateWithPassword(email, password);
} catch (error) {
  if (error.code === 'form_password_incorrect') {
    showError('Invalid password. Please try again.');
  } else if (error.code === 'form_identifier_not_found') {
    showError('Account not found. Please sign up first.');
  } else {
    showError(`Authentication failed: ${error.message}`);
  }
}
```

## 🏢 Organization Management

```javascript
// Create organization
const org = await clerk.createOrganization('My Company', 'my-company');

// List user's organizations
const orgs = await clerk.listOrganizations();

// Set active organization
await clerk.setActiveOrganization(orgId);
```

## 🔧 Advanced Features

### Token with Custom Template
```javascript
// Get Supabase-compatible token
const supabaseToken = await clerk.getToken({ template: 'supabase' });
```

### Session Validation
```javascript
const validation = await clerk.validateSession();
if (validation.isValid) {
  console.log('Session is valid');
} else {
  console.log('Session expired, redirecting to login...');
}
```

### Manual Session Refresh
```javascript
const refreshed = await clerk.refreshSession();
if (refreshed) {
  console.log('Session extended');
}
```

---

## 🖼️ Framework Integration Examples

### React Integration Example

```jsx
import { useState, useEffect } from 'react';

function AuthProvider({ children }) {
  const [clerk] = useState(() => new ClerkSDK({ 
    domain: 'your-instance.clerk.accounts.dev' 
  }));
  const [isLoaded, setIsLoaded] = useState(false);
  const [isSignedIn, setIsSignedIn] = useState(false);
  const [user, setUser] = useState(null);

  useEffect(() => {
    async function initClerk() {
      try {
        await clerk.load();
        setIsLoaded(true);
        setIsSignedIn(clerk.isSignedIn);
        setUser(clerk.user);

        // Listen for auth changes
        clerk.addListener('sessionCreated', () => {
          setIsSignedIn(true);
          setUser(clerk.user);
        });

        clerk.addListener('sessionDestroyed', () => {
          setIsSignedIn(false);
          setUser(null);
        });

      } catch (error) {
        console.error('Failed to initialize Clerk:', error);
      }
    }

    initClerk();
  }, [clerk]);

  if (!isLoaded) {
    return <div>Loading...</div>;
  }

  return (
    <ClerkContext.Provider value={{ clerk, isSignedIn, user }}>
      {children}
    </ClerkContext.Provider>
  );
}

// Usage in components
function LoginForm() {
  const { clerk } = useContext(ClerkContext);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');

  const handleLogin = async () => {
    try {
      const signIn = clerk.signIn();
      await signIn.authenticateWithPassword(email, password);
    } catch (error) {
      console.error('Login failed:', error);
    }
  };

  return (
    <form onSubmit={(e) => { e.preventDefault(); handleLogin(); }}>
      <input
        type="email"
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        placeholder="Email"
      />
      <input
        type="password"
        value={password}
        onChange={(e) => setPassword(e.target.value)}
        placeholder="Password"
      />
      <button type="submit">Sign In</button>
    </form>
  );
}
```

### Vue Integration Example

```vue
<template>
  <div>
    <div v-if="!isLoaded">Loading...</div>
    <div v-else-if="isSignedIn">
      <h1>Welcome, {{ user.first_name }}!</h1>
      <button @click="signOut">Sign Out</button>
    </div>
    <div v-else>
      <input v-model="email" type="email" placeholder="Email" />
      <input v-model="password" type="password" placeholder="Password" />
      <button @click="signIn">Sign In</button>
    </div>
  </div>
</template>

<script>
import ClerkSDK from './clerk-sdk.js';

export default {
  data() {
    return {
      clerk: new ClerkSDK({ domain: 'your-instance.clerk.accounts.dev' }),
      isLoaded: false,
      isSignedIn: false,
      user: null,
      email: '',
      password: ''
    };
  },

  async mounted() {
    try {
      await this.clerk.load();
      this.isLoaded = true;
      this.isSignedIn = this.clerk.isSignedIn;
      this.user = this.clerk.user;

      this.clerk.addListener('sessionCreated', () => {
        this.isSignedIn = true;
        this.user = this.clerk.user;
      });

      this.clerk.addListener('sessionDestroyed', () => {
        this.isSignedIn = false;
        this.user = null;
      });

    } catch (error) {
      console.error('Failed to initialize Clerk:', error);
    }
  },

  methods: {
    async signIn() {
      try {
        const signIn = this.clerk.signIn();
        await signIn.authenticateWithPassword(this.email, this.password);
      } catch (error) {
        console.error('Sign in failed:', error);
      }
    },

    async signOut() {
      try {
        await this.clerk.signOut();
      } catch (error) {
        console.error('Sign out failed:', error);
      }
    }
  }
};
</script>
```

---

# Part III: Advanced Topics & Troubleshooting

## 🔧 Session Persistence Troubleshooting

### Common Issues and Solutions

Based on real debugging experience, here are the most common session persistence issues and their solutions:

#### **Issue 1: Session Stored in localStorage but User Not Restored**

**Symptoms:**
```javascript
// Console shows cached session exists
📦 Found cached session data in localStorage: {...}
// But user is still not signed in
ℹ️ No existing session found - user needs to sign in
```

**Root Cause:** Over-reliance on server validation without proper fallback to cached sessions.

**Solution:** Implement multi-tier session restoration:

```javascript
async restoreSession() {
  const cachedData = this.storage.get('clerk_session_cache');
  
  if (cachedData?.session) {
    // Check session expiry first
    const sessionExpiry = new Date(cachedData.session.expire_at);
    if (sessionExpiry <= new Date()) {
      this.storage.remove('clerk_session_cache');
      return; // Session expired, don't use it
    }
    
    // For recent sessions, trust the cache directly
    const cacheAge = Date.now() - cachedData.timestamp;
    const recentCacheTime = 6 * 60 * 60 * 1000; // 6 hours
    
    if (cacheAge < recentCacheTime) {
      console.log('🚀 Using cached session directly (development mode)');
      this._restoreSession(cachedData.session, 'cache-direct');
      return; // Skip server validation for recent sessions
    }
    
    // For older sessions, validate with server but fall back to cache
    try {
      const { data } = await this.apiCall('/client');
      const serverSession = data.response.sessions.find(s => 
        s.id === cachedData.session.id && s.status === 'active'
      );
      
      if (serverSession) {
        this._restoreSession(serverSession, 'server-validated');
      } else {
        // Server doesn't have session, but cache is recent enough - use it
        this._restoreSession(cachedData.session, 'cache-fallback');
      }
    } catch (error) {
      // Server call failed, use cached session if not too old
      const maxOfflineAge = 24 * 60 * 60 * 1000; // 24 hours
      if (cacheAge < maxOfflineAge) {
        this._restoreSession(cachedData.session, 'cache-offline');
      }
    }
  }
}
```

#### **Issue 2: Development vs Production Session Behavior**

**Symptoms:** Session persistence works in production but fails in development (localhost).

**Root Cause:** Development instances have different cookie security policies and may not persist HTTP cookies between page reloads.

**Solution:** Implement development-friendly session handling:

```javascript
// In your session restoration logic
const isDevelopment = this.domain.includes('.clerk.accounts.dev') || 
                     this.domain.includes('.lclclerk.com') ||
                     location.hostname === 'localhost';

if (isDevelopment) {
  // Be more permissive with cached sessions in development
  const maxDevCacheAge = 12 * 60 * 60 * 1000; // 12 hours
  if (cacheAge < maxDevCacheAge && sessionNotExpired) {
    this._restoreSession(cachedSession, 'dev-cache-direct');
    return;
  }
}
```

#### **Issue 3: Silent Session Restoration Failures**

**Symptoms:** No console errors, but sessions aren't being restored.

**Root Cause:** Errors in restoration process are being caught and ignored without proper debugging.

**Solution:** Add comprehensive debugging:

```javascript
async restoreSession() {
  console.log('🔍 Starting session restoration...');
  
  try {
    const cachedData = this.storage.get('clerk_session_cache');
    console.log('📦 Raw cached data:', cachedData);
    
    if (cachedData?.session) {
      console.log('📋 Cached session details:', {
        id: cachedData.session.id,
        status: cachedData.session.status,
        expires: cachedData.session.expire_at,
        user: cachedData.session.user?.email_addresses[0]?.email_address
      });
      
      // ... restoration logic with detailed logging
      
    } else {
      console.log('ℹ️ No cached session found');
    }
    
    console.log('🎯 Final SDK state:', {
      isSignedIn: this.isSignedIn,
      hasSession: !!this.session,
      hasUser: !!this.user
    });
    
  } catch (error) {
    console.error('❌ Session restoration error:', error);
    throw error; // Don't silently ignore
  }
}
```

#### **Issue 4: Session State Not Updating UI**

**Symptoms:** Session is restored but UI still shows login form.

**Root Cause:** Event listeners not firing correctly after session restoration.

**Solution:** Ensure proper event emission and state updates:

```javascript
_restoreSession(session, source) {
  // Set session state
  this.session = session;
  this.user = session.user;
  
  // Update cache
  this.storage.set('clerk_session_cache', {
    session,
    timestamp: Date.now()
  });
  
  // CRITICAL: Emit session created event for UI updates
  this.emit('sessionCreated', { session });
  
  console.log(`✅ Session restored from ${source}:`, {
    isSignedIn: this.isSignedIn,
    userId: this.user?.id,
    email: this.user?.email_addresses[0]?.email_address
  });
}
```

### Debugging Checklist

When session persistence isn't working, check these in order:

1. **localStorage Content**:
   ```javascript
   console.log('Cache:', JSON.parse(localStorage.getItem('clerk_session_cache') || '{}'));
   ```

2. **Session Expiry**:
   ```javascript
   const cached = JSON.parse(localStorage.getItem('clerk_session_cache') || '{}');
   console.log('Expires:', new Date(cached.session?.expire_at));
   console.log('Now:', new Date());
   ```

3. **SDK State After Init**:
   ```javascript
   // After clerk.load()
   console.log('SDK State:', {
     isLoaded: clerk.isLoaded,
     isSignedIn: clerk.isSignedIn,
     hasSession: !!clerk.session,
     hasUser: !!clerk.user
   });
   ```

4. **Network Issues**:
   ```javascript
   // Check if /client calls are failing
   try {
     await fetch('https://your-domain.clerk.accounts.dev/v1/client?__clerk_api_version=2025-04-10');
   } catch (error) {
     console.error('Network issue:', error);
   }
   ```

### Best Practices for Production

1. **Implement Progressive Enhancement**:
   - Start with cached session for immediate UI response
   - Validate with server in background
   - Update UI if server data differs

2. **Handle Network Failures Gracefully**:
   - Always have offline fallbacks
   - Implement retry logic with exponential backoff
   - Show appropriate user feedback for persistent network issues

3. **Security Considerations**:
   - Don't cache sensitive data indefinitely
   - Implement proper session expiry checks
   - Clear cache on security-related errors

---

## 🚀 Production Best Practices

### Production Checklist

- [ ] Replace domain with your production instance
- [ ] Implement proper error handling for all auth flows
- [ ] Set up session refresh intervals
- [ ] Add loading states for better UX
- [ ] Test all authentication flows thoroughly
- [ ] Implement proper token storage and security
- [ ] Add analytics and monitoring
- [ ] Test cross-tab synchronization
- [ ] Verify mobile responsiveness
- [ ] Set up proper CORS headers

### Debugging

```javascript
// Enable debug logging
console.log('Clerk SDK State:', {
  isLoaded: clerk.isLoaded,
  isSignedIn: clerk.isSignedIn,
  user: clerk.user,
  session: clerk.session
});

// Debug session info
await clerk.debugSession();

// Debug client info
await clerk.debugClient();

// Validate current session
const validation = await clerk.validateSession();
console.log('Session validation:', validation);
```

### Common Issues & Solutions

#### 1. CORS Errors
Make sure your domain is properly configured in Clerk dashboard under "Allowed origins".

#### 2. Session Not Persisting
Check that cookies are enabled and your domain configuration is correct.

#### 3. Token Expired Errors
Implement automatic token refresh or redirect to login when tokens expire.

#### 4. Cross-Tab Issues
The SDK includes built-in cross-tab synchronization via localStorage events.

---

## 🎯 Complete SDK Integration

### Complete SDK Integration

```javascript
class ClerkSDK {
  constructor(options) {
    this.domain = options.domain;
    this.apiVersion = options.apiVersion || '2025-04-10';
    
    // Initialize all components
    this.apiClient = new ClerkAPIClient(this.domain);
    this.environmentManager = new EnvironmentManager(this.apiClient);
    this.clientManager = new ClientManager(this.apiClient);
    this.devBrowserHandler = new DevBrowserHandler(this.apiClient);
    this.sessionManager = new SessionManager(this.apiClient, this.onSessionChange.bind(this));
    this.sessionPersistence = new SessionPersistence(this.apiClient, this.sessionManager);
    this.tokenManager = new TokenManager(this.apiClient);
    this.userManager = new UserManager(this.apiClient, this.sessionManager);
    this.organizationManager = new OrganizationManager(this.apiClient, this.sessionManager);
    
    // State
    this.loaded = false;
    this.listeners = [];
  }

  async load() {
    if (this.loaded) return;

    try {
      console.log('🚀 Initializing Clerk SDK...');
      
      // Step 1: Setup development browser authentication
      await this.devBrowserHandler.setupDevBrowser();
      
      // Step 2: Initialize environment and client
      const environment = await this.environmentManager.fetchEnvironment();
      const client = await this.clientManager.createClient();
      
      // Step 3: Restore existing session
      await this.sessionPersistence.restoreSession();
      
      this.loaded = true;
      this.emit('loaded', { environment, client });
      
      console.log('✅ Clerk SDK initialized successfully');
    } catch (error) {
      console.error('❌ Failed to initialize Clerk SDK:', error);
      this.emit('error', error);
      throw error;
    }
  }

  // Authentication flows
  signIn() {
    return new SignInFlow(this.apiClient);
  }

  signUp() {
    return new SignUpFlow(this.apiClient);
  }

  // Session operations
  async signOut() {
    return this.sessionManager.signOut();
  }

  async signOutAll() {
    return this.sessionManager.signOutAll();
  }

  async validateSession() {
    return this.sessionManager.validateSession();
  }

  async refreshSession() {
    return this.sessionManager.refreshSession();
  }

  // User operations
  async getUser() {
    return this.userManager.getCurrentUser();
  }

  async updateUser(updates) {
    return this.userManager.updateUser(updates);
  }

  // Token operations
  async getToken(template = '') {
    const sessionId = this.sessionManager.currentSession?.id;
    return this.tokenManager.getToken(sessionId, template);
  }

  // Organization operations
  async listOrganizations() {
    return this.organizationManager.listOrganizations();
  }

  async createOrganization(name, slug) {
    return this.organizationManager.createOrganization(name, slug);
  }

  async setActiveOrganization(organizationId) {
    return this.organizationManager.setActiveOrganization(organizationId);
  }

  // Getters
  get isLoaded() {
    return this.loaded;
  }

  get isSignedIn() {
    return this.sessionManager.isSignedIn;
  }

  get isSignedOut() {
    return !this.isSignedIn;
  }

  get user() {
    return this.userManager.user;
  }

  get session() {
    return this.sessionManager.currentSession;
  }

  get organization() {
    return this.organizationManager.activeOrganization;
  }

  // Event system
  addListener(event, callback) {
    this.listeners.push({ event, callback });
  }

  removeListener(event, callback) {
    this.listeners = this.listeners.filter(
      listener => listener.event !== event || listener.callback !== callback
    );
  }

  emit(event, data) {
    this.listeners
      .filter(listener => listener.event === event)
      .forEach(listener => listener.callback(data));
  }

  onSessionChange(type, session) {
    if (type === 'created') {
      this.emit('sessionCreated', { session });
    } else if (type === 'destroyed') {
      this.emit('sessionDestroyed', { session });
    }
  }

  // Debugging helpers
  async debugSession() {
    console.log('🐛 Session Debug Info:', {
      hasSession: !!this.session,
      sessionId: this.session?.id,
      userId: this.session?.user?.id,
      email: this.session?.user?.email_addresses[0]?.email_address,
      status: this.session?.status,
      expiresAt: this.session?.expire_at,
      organization: this.session?.organization?.name
    });
  }

  async debugClient() {
    const client = this.clientManager.clientData;
    console.log('🐛 Client Debug Info:', {
      clientId: client?.id,
      sessionsCount: client?.sessions?.length || 0,
      activeSessions: client?.sessions?.filter(s => s.status === 'active').length || 0,
      lastActiveSession: client?.last_active_session_id
    });
  }
}
```

This comprehensive guide provides everything needed to build, integrate, and troubleshoot a complete Clerk authentication SDK for JavaScript/Web applications. The modular architecture allows for easy customization and extension while maintaining robustness and reliability.

## Support

For issues with this SDK implementation:
1. Check browser console for detailed error messages
2. Use the debug functions to inspect state
3. Verify your Clerk instance configuration
4. Test with a fresh browser session

Happy coding! 🚀