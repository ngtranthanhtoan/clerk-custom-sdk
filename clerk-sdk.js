/**
 * Custom Clerk Authentication SDK
 * A complete implementation using REST API calls
 * Version: 1.0.0
 */

class ClerkSDK {
  constructor(options = {}) {
    this.domain = options.domain || 'bright-newt-8.clerk.accounts.dev';
    this.apiVersion = options.apiVersion || '2025-04-10';
    this.jsVersion = options.jsVersion || '5.88.0';
    
    // Current state
    this.user = null;
    this.session = null;
    this.organization = null;
    this.environment = null;
    this.client = null;
    
    // Internal state
    this.loaded = false;
    this.listeners = [];
    this.tokenCache = new Map();
    this.refreshTimer = null;
    
    // Development browser JWT for dev instances
    this.devBrowserJWT = null;
    
    // Initialize storage for offline support
    this.storage = {
      get: (key) => {
        try {
          return JSON.parse(localStorage.getItem(key));
        } catch {
          return null;
        }
      },
      set: (key, value) => {
        try {
          localStorage.setItem(key, JSON.stringify(value));
        } catch (error) {
          console.warn('Failed to store data:', error);
        }
      },
      remove: (key) => {
        try {
          localStorage.removeItem(key);
        } catch (error) {
          console.warn('Failed to remove data:', error);
        }
      }
    };
  }

  // =============================================================================
  // CORE API CLIENT
  // =============================================================================

  buildUrl(path, params = {}, originalMethod = 'GET') {
    const url = new URL(`https://${this.domain}/v1${path}`);
    
    // Add required Clerk parameters
    url.searchParams.set('__clerk_api_version', this.apiVersion);
    url.searchParams.set('_clerk_js_version', this.jsVersion);
    
    // CORS workaround: Use _method query param for non-GET/POST requests
    // This avoids CORS preflight requests that can break cookie dropping
    if (originalMethod && originalMethod !== 'GET' && originalMethod !== 'POST') {
      url.searchParams.set('_method', originalMethod);
    }
    
    // Add dev browser JWT for development instances
    if (this.isDevInstance() && this.devBrowserJWT) {
      url.searchParams.set('__clerk_db_jwt', this.devBrowserJWT);
    }
    
    // Add custom parameters
    Object.entries(params).forEach(([key, value]) => {
      if (value !== null && value !== undefined) {
        url.searchParams.set(key, value);
      }
    });
    
    return url.toString();
  }

  async apiCall(path, options = {}) {
    const originalMethod = options.method || 'GET';
    
    // CORS workaround: Convert all methods to GET or POST to avoid preflight requests
    const actualMethod = originalMethod === 'GET' ? 'GET' : 'POST';
    
    const url = this.buildUrl(path, options.params, originalMethod);
    
    const fetchOptions = {
      method: actualMethod,
      credentials: 'include', // CRITICAL: Include cookies for session management
      ...options
    };
    
    // Only add headers that don't trigger CORS preflight
    // Remove 'Accept: application/json' as it triggers preflight
    if (options.headers) {
      const safeHeaders = {};
      
      // Only add Content-Type for form data (doesn't trigger preflight)
      if (options.headers['Content-Type'] === 'application/x-www-form-urlencoded') {
        safeHeaders['Content-Type'] = 'application/x-www-form-urlencoded';
      }
      
      if (Object.keys(safeHeaders).length > 0) {
        fetchOptions.headers = safeHeaders;
      }
    }
    
    // Remove params and method from fetchOptions to avoid conflicts
    delete fetchOptions.params;
    delete fetchOptions.method;
    
    // Set the actual method
    fetchOptions.method = actualMethod;
    
    console.log(`🔄 ${originalMethod} ${path} (using ${actualMethod})`);
    
    try {
      const response = await fetch(url, fetchOptions);
      const data = await response.json();
      
      console.log(`📥 Response:`, { status: response.status, data });
      
      // Check for new dev browser JWT in response headers
      if (this.isDevInstance()) {
        const newDevBrowserJWT = response.headers.get('clerk-dev-browser-jwt');
        if (newDevBrowserJWT && newDevBrowserJWT !== this.devBrowserJWT) {
          console.log('🔄 Updating dev browser JWT from response header');
          this.setDevBrowserJWTCookie(newDevBrowserJWT);
        }
      }
      
      if (!response.ok) {
        throw this.createError(data, response.status);
      }
      
      return { response, data };
    } catch (error) {
      if (error.name === 'ClerkError') {
        throw error;
      }
      throw this.createError({ message: error.message }, 0, 'network_error');
    }
  }

  createError(data, status, defaultCode = 'api_error') {
    const errors = data.errors || [];
    const primaryError = errors[0] || {};
    
    const error = new Error(primaryError.long_message || primaryError.message || data.message || 'Unknown error');
    error.name = 'ClerkError';
    error.code = primaryError.code || defaultCode;
    error.status = status;
    error.errors = errors;
    error.timestamp = new Date();
    
    return error;
  }

  // =============================================================================
  // DEVELOPMENT BROWSER JWT HANDLING
  // =============================================================================

  isDevInstance() {
    return this.domain.includes('.clerk.accounts.dev') || 
           this.domain.includes('.lclclerk.com') || 
           this.domain.includes('clerk.dev');
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
    } catch (error) {
      console.warn('Failed to read dev browser JWT from cookie:', error);
    }
    return null;
  }

  setDevBrowserJWTCookie(jwt) {
    try {
      document.cookie = `__clerk_db_jwt=${encodeURIComponent(jwt)}; path=/; SameSite=strict`;
      this.devBrowserJWT = jwt;
      console.log('✅ Dev browser JWT stored in cookie');
    } catch (error) {
      console.warn('Failed to set dev browser JWT cookie:', error);
    }
  }

  getDevBrowserJWTFromURL() {
    try {
      const url = new URL(window.location.href);
      return url.searchParams.get('__clerk_db_jwt');
    } catch (error) {
      console.warn('Failed to extract dev browser JWT from URL:', error);
      return null;
    }
  }

  async setupDevBrowser() {
    if (!this.isDevInstance()) {
      console.log('📝 Production instance - skipping dev browser setup');
      return;
    }

    console.log('🔧 Setting up development browser authentication...');

    // Step 1: Check for JWT in URL params (redirected from clerk dashboard)
    const jwtFromUrl = this.getDevBrowserJWTFromURL();
    if (jwtFromUrl) {
      console.log('✅ Found dev browser JWT in URL');
      this.setDevBrowserJWTCookie(jwtFromUrl);
      // Clean up URL without reloading page
      const url = new URL(window.location.href);
      url.searchParams.delete('__clerk_db_jwt');
      window.history.replaceState({}, '', url.toString());
      return;
    }

    // Step 2: Check for existing JWT in cookie
    const jwtFromCookie = this.getDevBrowserJWTFromCookie();
    if (jwtFromCookie) {
      console.log('✅ Found existing dev browser JWT in cookie');
      this.devBrowserJWT = jwtFromCookie;
      return;
    }

    // Step 3: Try to get a new dev browser JWT automatically
    console.log('🔄 Attempting to get new dev browser JWT...');
    try {
      await this.requestDevBrowserJWT();
    } catch (error) {
      console.warn('⚠️ Could not obtain dev browser JWT automatically:', error.message);
      console.log('💡 You may need to visit your Clerk dashboard first to authenticate this browser');
    }
  }

  async requestDevBrowserJWT() {
    try {
      const url = `https://${this.domain}/v1/dev_browser`;
      console.log('🔄 Requesting dev browser JWT from:', url);
      
      const response = await fetch(url, {
        method: 'POST',
        credentials: 'include'
      });

      if (!response.ok) {
        const errorData = await response.text();
        throw new Error(`Dev browser JWT request failed: ${response.status} ${errorData}`);
      }

      const data = await response.json();
      if (data.id) {
        console.log('✅ Successfully obtained dev browser JWT');
        this.setDevBrowserJWTCookie(data.id);
      } else {
        throw new Error('No JWT returned from dev_browser endpoint');
      }
    } catch (error) {
      console.error('❌ Failed to request dev browser JWT:', error);
      throw error;
    }
  }

  // =============================================================================
  // INITIALIZATION
  // =============================================================================

  async load() {
    if (this.loaded) return;

    try {
      console.log('🚀 Initializing Clerk SDK...');
      console.log('🌐 Domain:', this.domain);
      console.log('🔧 API Version:', this.apiVersion);
      
      // Setup development browser JWT handling first (before any API calls)
      await this.setupDevBrowser();
      
      // Initialize environment and client sequentially for better error handling
      console.log('📋 Fetching environment configuration...');
      const environment = await this.fetchEnvironment();
      console.log('✅ Environment loaded');

      console.log('🔗 Creating/getting client...');
      const client = await this.createClient();
      console.log('✅ Client ready');

      this.environment = environment;
      this.client = client;

      // Try to restore existing session
      console.log('🔄 Checking for existing session...');
      await this.restoreSession();

      // Debug: Check SDK state after restoration attempt
      console.log('🎯 SDK state after restore attempt:', {
        'this.session': !!this.session,
        'this.user': !!this.user,
        'isSignedIn': this.isSignedIn,
        'session.status': this.session?.status,
        'user.email': this.user?.email_addresses[0]?.email_address
      });

      this.loaded = true;
      this.emit('loaded', { environment, client });
      
      console.log('✅ Clerk SDK initialized successfully');
    } catch (error) {
      console.error('❌ Failed to initialize Clerk SDK:', error);
      
      // Provide helpful error messages based on the error
      if (error.message.includes('authenticate this browser')) {
        console.log('💡 Possible solutions:');
        console.log('   1. Visit https://dashboard.clerk.com and navigate to your instance');
        console.log('   2. Make sure you\'re using the correct domain');
        console.log('   3. Try refreshing the page after visiting the dashboard');
      }
      
      this.emit('error', error);
      throw error;
    }
  }

  async fetchEnvironment() {
    const { data } = await this.apiCall('/environment');
    return data.response;
  }

  async createClient() {
    try {
      const { data } = await this.apiCall('/client', {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        }
      });
      return data.response;
    } catch (error) {
      // If client creation fails, try GET to see if client already exists
      if (error.message.includes('authenticate this browser')) {
        console.warn('⚠️ Development instance requires browser authentication. Trying to get existing client...');
        
        try {
          const { data } = await this.apiCall('/client');
          console.log('✅ Using existing client instead of creating new one');
          return data.response;
        } catch (getError) {
          console.error('❌ Cannot access client:', getError.message);
          throw new Error(
            'Unable to authenticate with your Clerk development instance. ' +
            'Please ensure you have the correct domain and that your browser is authorized. ' +
            'Try visiting your Clerk dashboard first to establish authentication cookies.'
          );
        }
      }
      throw error;
    }
  }

  async restoreSession() {
    try {
      // First, check if we have a cached session in localStorage
      const cachedData = this.storage.get('clerk_session_cache');
      console.log('🔍 Checking localStorage for cached session...');
      console.log('📦 Raw cached data:', cachedData);
      
      if (cachedData && cachedData.session) {
        console.log('📦 Found cached session, validating with server...');
        console.log('📋 Cached session details:', {
          id: cachedData.session.id,
          status: cachedData.session.status,
          user: cachedData.session.user?.email_addresses[0]?.email_address,
          expires: cachedData.session.expire_at,
          cached_at: new Date(cachedData.timestamp).toLocaleString()
        });
        const cachedSession = cachedData.session;
        
        // Quick validation: check if cached session hasn't expired according to its expiry date
        const sessionExpiry = new Date(cachedSession.expire_at);
        const now = new Date();
        
        if (sessionExpiry <= now) {
          console.log('⚠️ Cached session has expired according to its expiry date, clearing cache');
          this.storage.remove('clerk_session_cache');
          // Continue to server-only check
        } else {
          console.log('✅ Cached session not expired, expiry:', sessionExpiry.toLocaleString());
          
          // For development/testing: trust the cached session if it's not expired
          // This helps with localhost/development issues where cookies might not persist
          const cacheAge = Date.now() - cachedData.timestamp;
          const recentCacheTime = 6 * 60 * 60 * 1000; // 6 hours
          
          if (cacheAge < recentCacheTime) {
            console.log('🚀 Using cached session directly (development mode)');
            this._restoreSession(cachedSession, 'cache-direct');
            return; // Skip server validation for recent sessions
          }
        }
        
        // Try to validate the cached session with the server
        try {
          console.log('🌐 Calling /client to validate cached session...');
          const { data } = await this.apiCall('/client');
          const client = data.response;
          console.log('📊 Server client response:', {
            sessions_count: client.sessions?.length || 0,
            active_sessions: client.sessions?.filter(s => s.status === 'active').length || 0,
            last_active_session_id: client.last_active_session_id
          });
          
          const activeSessions = client.sessions.filter(s => s.status === 'active');
          
          // Check if our cached session is still valid on the server
          const serverSession = activeSessions.find(s => s.id === cachedSession.id);
          console.log('🔍 Looking for cached session ID on server:', cachedSession.id);
          console.log('🔍 Server session found:', !!serverSession);
          
          if (serverSession) {
            // Session is still valid on server, use the server version (most up to date)
            this._restoreSession(serverSession, 'server-validated');
            return;
          } else if (activeSessions.length > 0) {
            // Cached session not valid, but other active sessions exist
            const currentSession = activeSessions.find(s => 
              s.id === client.last_active_session_id
            ) || activeSessions[0];
            this._restoreSession(currentSession, 'server-alternate');
            return;
          } else {
            // No active sessions on server, clear cache
            console.log('⚠️ Cached session no longer valid, clearing cache');
            this.storage.remove('clerk_session_cache');
          }
        } catch (serverError) {
          // Server call failed, use cached session if not too old
          const cacheAge = Date.now() - cachedData.timestamp;
          const maxCacheAge = 24 * 60 * 60 * 1000; // 24 hours
          
          console.log(`🔍 Server validation failed: ${serverError.message}`);
          console.log(`🔍 Cache age: ${Math.round(cacheAge / 1000 / 60)} minutes (max: ${Math.round(maxCacheAge / 1000 / 60)} minutes)`);
          
          if (cacheAge < maxCacheAge) {
            console.log('🔄 Server unavailable, using cached session (offline mode)');
            this._restoreSession(cachedSession, 'cache-offline');
            return;
          } else {
            console.log('⚠️ Cached session too old and server unavailable');
            this.storage.remove('clerk_session_cache');
          }
        }
      } else {
        console.log('ℹ️ No cached session found in localStorage');
      }
      
      // No valid cached session, try to get sessions from server only
      console.log('🌐 No cached session, checking server for active sessions...');
      const { data } = await this.apiCall('/client');
      const client = data.response;
      const activeSessions = client.sessions.filter(s => s.status === 'active');
      
      if (activeSessions.length > 0) {
        const currentSession = activeSessions.find(s => 
          s.id === client.last_active_session_id
        ) || activeSessions[0];
        this._restoreSession(currentSession, 'server-fresh');
      } else {
        console.log('ℹ️ No active sessions found on server');
      }
    } catch (error) {
      console.warn('⚠️ Failed to restore session:', error.message);
      // Clear any invalid cached data
      this.storage.remove('clerk_session_cache');
    }
  }

  // =============================================================================
  // AUTHENTICATION FLOWS
  // =============================================================================

  signIn() {
    return new SignInFlow(this);
  }

  signUp() {
    return new SignUpFlow(this);
  }

  async signOut(options = {}) {
    const { sessionId = this.session?.id, callback } = options;
    
    if (!sessionId) {
      console.warn('No session to sign out from');
      return;
    }

    try {
      console.log('🔄 Signing out...');
      
      await this.apiCall(`/client/sessions/${sessionId}`, {
        method: 'DELETE',
        params: { _clerk_session_id: sessionId }
      });
      
      if (sessionId === this.session?.id) {
        this.clearSession();
      }
      
      if (callback) {
        await callback();
      }
      
      this.emit('sessionDestroyed', { sessionId });
      console.log('✅ Signed out successfully');
    } catch (error) {
      console.error('❌ Sign out failed:', error);
      throw error;
    }
  }

  async signOutAll() {
    try {
      await this.apiCall('/client/sessions', {
        method: 'DELETE'
      });
      
      this.clearSession();
      this.emit('sessionDestroyed', { sessionId: 'all' });
      console.log('✅ Signed out from all sessions');
    } catch (error) {
      console.error('❌ Sign out all failed:', error);
      throw error;
    }
  }

  // =============================================================================
  // SESSION MANAGEMENT
  // =============================================================================

  setSession(session) {
    this.session = session;
    this.user = session.user;
    this.organization = session.organization || null;
    
    // Cache session for offline support
    this.storage.set('clerk_session_cache', {
      session,
      timestamp: Date.now()
    });
    
    // Start session refresh timer
    this.startSessionRefresh();
    
    this.emit('sessionCreated', { session });
  }

  // Internal method for session restoration that doesn't trigger caching
  _restoreSession(session, source = 'unknown') {
    console.log(`🔄 Restoring session from ${source}:`, {
      sessionId: session.id,
      userId: session.user?.id,
      email: session.user?.email_addresses[0]?.email_address,
      status: session.status,
      expires: session.expire_at
    });
    
    console.log('📋 Full session object:', session);
    
    this.session = session;
    this.user = session.user;
    this.organization = session.organization || null;
    
    console.log('✅ Session variables set:', {
      'this.session': !!this.session,
      'this.user': !!this.user,
      'this.session.status': this.session?.status,
      'isSignedIn': this.isSignedIn
    });
    
    // Update cache timestamp without overwriting
    const existingCache = this.storage.get('clerk_session_cache');
    if (existingCache) {
      existingCache.timestamp = Date.now();
      existingCache.session = session; // Update with fresh data
      this.storage.set('clerk_session_cache', existingCache);
    } else {
      // First time caching
      this.storage.set('clerk_session_cache', {
        session,
        timestamp: Date.now()
      });
    }
    
    // Start session refresh timer
    this.startSessionRefresh();
    
    // Emit session created event
    this.emit('sessionCreated', { session });
  }

  clearSession() {
    this.session = null;
    this.user = null;
    this.organization = null;
    
    this.tokenCache.clear();
    this.stopSessionRefresh();
    this.storage.remove('clerk_session_cache');
    
    this.emit('sessionCleared');
  }

  async getCurrentSession() {
    try {
      const { data } = await this.apiCall('/client');
      const client = data.response;
      const activeSessions = client.sessions.filter(s => s.status === 'active');
      const currentSession = activeSessions.find(s => s.id === client.last_active_session_id);
      
      return currentSession || null;
    } catch (error) {
      console.error('Failed to get current session:', error);
      return null;
    }
  }

  async validateSession(sessionId = this.session?.id) {
    if (!sessionId) return { isValid: false, error: 'No session ID' };

    try {
      const { data } = await this.apiCall(`/client/sessions/${sessionId}`, {
        params: { _clerk_session_id: sessionId }
      });
      
      const session = data.response;
      const isValid = session.status === 'active' && new Date(session.expire_at) > new Date();
      
      return { isValid, session };
    } catch (error) {
      return { isValid: false, error: error.message };
    }
  }

  async refreshSession(sessionId = this.session?.id) {
    if (!sessionId) return false;

    try {
      await this.apiCall(`/client/sessions/${sessionId}/touch`, {
        method: 'POST',
        params: { _clerk_session_id: sessionId }
      });
      
      console.log('✅ Session refreshed');
      return true;
    } catch (error) {
      console.error('Failed to refresh session:', error);
      return false;
    }
  }

  startSessionRefresh() {
    // Refresh session every 5 minutes
    this.refreshTimer = setInterval(async () => {
      if (this.session) {
        await this.refreshSession(this.session.id);
      }
    }, 5 * 60 * 1000);
  }

  stopSessionRefresh() {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer);
      this.refreshTimer = null;
    }
  }

  // =============================================================================
  // TOKEN MANAGEMENT
  // =============================================================================

  async getToken(options = {}) {
    const { template = '', sessionId = this.session?.id } = options;
    
    if (!sessionId) {
      throw new Error('No active session');
    }

    const cacheKey = `${sessionId}-${template}`;
    const cached = this.tokenCache.get(cacheKey);
    
    // Return cached token if still valid (with 5 minute buffer)
    if (cached && cached.expiresAt > new Date(Date.now() + 5 * 60 * 1000)) {
      return cached.jwt;
    }

    try {
      const { data } = await this.apiCall(`/client/sessions/${sessionId}/tokens`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: new URLSearchParams({ template }),
        params: { _clerk_session_id: sessionId }
      });

      const jwt = data.response.jwt;
      const decoded = this.decodeJWT(jwt);
      
      // Cache the token
      this.tokenCache.set(cacheKey, {
        jwt,
        expiresAt: new Date(decoded.exp * 1000),
        issuedAt: new Date(decoded.iat * 1000)
      });

      return jwt;
    } catch (error) {
      console.error('Failed to get token:', error);
      throw error;
    }
  }

  decodeJWT(token) {
    try {
      const parts = token.split('.');
      const payload = JSON.parse(atob(parts[1]));
      return payload;
    } catch (error) {
      throw new Error('Invalid JWT token');
    }
  }

  isTokenExpired(token) {
    try {
      const decoded = this.decodeJWT(token);
      return decoded.exp * 1000 <= Date.now();
    } catch (error) {
      return true;
    }
  }

  // =============================================================================
  // USER MANAGEMENT
  // =============================================================================

  async getUser() {
    if (!this.session) {
      return null;
    }

    try {
      const { data } = await this.apiCall('/me', {
        params: { _clerk_session_id: this.session.id }
      });

      // Update cached user data
      this.user = data.response;
      if (this.session) {
        this.session.user = this.user;
      }

      this.emit('userUpdated', { user: this.user });
      return this.user;
    } catch (error) {
      console.error('Failed to get user:', error);
      
      // If user fetch fails, might be session issue
      if (error.status === 401) {
        this.clearSession();
      }
      
      return null;
    }
  }

  async updateUser(userData) {
    if (!this.session) throw new Error('Authentication required');

    try {
      const { data } = await this.apiCall('/me', {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: new URLSearchParams(userData),
        params: { _clerk_session_id: this.session.id }
      });

      this.user = data.response;
      if (this.session) {
        this.session.user = this.user;
      }
      
      this.emit('userUpdated', { user: this.user });
      return this.user;
    } catch (error) {
      console.error('Failed to update user:', error);
      throw error;
    }
  }

  async uploadProfileImage(file) {
    if (!this.session) throw new Error('Authentication required');

    try {
      const formData = new FormData();
      formData.append('file', file);

      const { data } = await this.apiCall('/me/profile_image', {
        method: 'PUT',
        body: formData,
        params: { _clerk_session_id: this.session.id }
      });

      this.user = data.response;
      this.emit('userUpdated', { user: this.user });
      return this.user;
    } catch (error) {
      console.error('Failed to upload profile image:', error);
      throw error;
    }
  }

  // =============================================================================
  // ORGANIZATION MANAGEMENT
  // =============================================================================

  async createOrganization(name, slug) {
    if (!this.session) throw new Error('Authentication required');

    try {
      const { data } = await this.apiCall('/organizations', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: new URLSearchParams({ name, slug }),
        params: { _clerk_session_id: this.session.id }
      });

      const organization = data.response;
      this.emit('organizationCreated', { organization });
      return organization;
    } catch (error) {
      console.error('Failed to create organization:', error);
      throw error;
    }
  }

  async listOrganizations() {
    if (!this.session) throw new Error('Authentication required');

    try {
      const { data } = await this.apiCall('/organizations', {
        params: { _clerk_session_id: this.session.id }
      });

      return data.response;
    } catch (error) {
      console.error('Failed to list organizations:', error);
      throw error;
    }
  }

  async setActiveOrganization(organizationId) {
    if (!this.session) throw new Error('Authentication required');

    try {
      const { data } = await this.apiCall(`/client/sessions/${this.session.id}/touch`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: new URLSearchParams({ active_organization_id: organizationId }),
        params: { _clerk_session_id: this.session.id }
      });

      // Update current session with new organization
      const updatedSession = data.response;
      this.setSession(updatedSession);
      
      return this.organization;
    } catch (error) {
      console.error('Failed to set active organization:', error);
      throw error;
    }
  }

  // =============================================================================
  // UTILITY METHODS
  // =============================================================================

  get isLoaded() {
    return this.loaded;
  }

  get isSignedIn() {
    return !!this.session && this.session.status === 'active';
  }

  get isSignedOut() {
    return !this.isSignedIn;
  }

  // Helper method to get current user info
  getCurrentUser() {
    return this.user;
  }

  // Check if user data is available
  hasUser() {
    return !!this.user;
  }

  // Event system
  addListener(event, callback) {
    this.listeners.push({ event, callback });
    return () => {
      this.listeners = this.listeners.filter(l => l.callback !== callback);
    };
  }

  emit(event, data) {
    this.listeners
      .filter(l => l.event === event)
      .forEach(l => {
        try {
          l.callback(data);
        } catch (error) {
          console.error('Event listener error:', error);
        }
      });
  }

  // Debugging helpers
  async debugSession() {
    console.group('🔍 Session Debug Info');
    console.log('Current Session:', this.session);
    console.log('Current User:', this.user);
    console.log('Current Organization:', this.organization);
    
    if (this.session) {
      const validation = await this.validateSession();
      console.log('Session Validation:', validation);
    }
    
    console.groupEnd();
  }

  async debugClient() {
    console.group('🔍 Client Debug Info');
    
    try {
      const { data } = await this.apiCall('/client');
      const client = data.response;
      
      console.log('Client ID:', client.id);
      console.log('Total Sessions:', client.sessions.length);
      console.log('Active Sessions:', client.sessions.filter(s => s.status === 'active').length);
      console.log('Last Active Session ID:', client.last_active_session_id);
      console.log('All Sessions:', client.sessions.map(s => ({
        id: s.id,
        status: s.status,
        userEmail: s.user?.email_addresses?.[0]?.email_address,
        expiresAt: new Date(s.expire_at).toLocaleString()
      })));
    } catch (error) {
      console.error('Failed to get client debug info:', error);
    }
    
    console.groupEnd();
  }
}

// =============================================================================
// SIGN-IN FLOW
// =============================================================================

class SignInFlow {
  constructor(sdk) {
    this.sdk = sdk;
    this.signInAttempt = null;
  }

  async create(params) {
    const { identifier } = params;
    
    try {
      const { data } = await this.sdk.apiCall('/client/sign_ins', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: new URLSearchParams({ identifier })
      });

      this.signInAttempt = data.response;
      console.log('✅ Sign-in created:', {
        id: this.signInAttempt.id,
        status: this.signInAttempt.status,
        supportedFactors: this.signInAttempt.supported_first_factors?.map(f => f.strategy)
      });
      
      return this.signInAttempt;
    } catch (error) {
      console.error('❌ Failed to create sign-in:', error);
      throw error;
    }
  }

  async prepareFirstFactor(params) {
    if (!this.signInAttempt) {
      throw new Error('Must create sign-in attempt first');
    }

    const { strategy, ...otherParams } = params;
    const body = new URLSearchParams({ strategy, ...otherParams });

    try {
      const { data } = await this.sdk.apiCall(
        `/client/sign_ins/${this.signInAttempt.id}/prepare_first_factor`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded'
          },
          body
        }
      );

      this.signInAttempt = data.response;
      console.log('✅ First factor prepared:', strategy);
      
      return this.signInAttempt;
    } catch (error) {
      console.error('❌ Failed to prepare first factor:', error);
      throw error;
    }
  }

  async attemptFirstFactor(params) {
    if (!this.signInAttempt) {
      throw new Error('Must create sign-in attempt first');
    }

    const { strategy, ...otherParams } = params;
    const body = new URLSearchParams({ strategy, ...otherParams });

    try {
      const { data } = await this.sdk.apiCall(
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

      // If sign-in is complete, set the session
      if (this.signInAttempt.status === 'complete') {
        const session = data.client.sessions.find(s => 
          s.id === this.signInAttempt.created_session_id
        );
        if (session) {
          this.sdk.setSession(session);
          console.log('🎉 Authentication successful!');
        }
      }

      return this.signInAttempt;
    } catch (error) {
      console.error('❌ Failed to attempt first factor:', error);
      throw error;
    }
  }

  // Convenience methods for common flows
  async authenticateWithPassword(identifier, password) {
    await this.create({ identifier });
    return this.attemptFirstFactor({ strategy: 'password', password });
  }

  async authenticateWithEmailCode(identifier) {
    await this.create({ identifier });
    
    // Find email code factor
    const emailFactor = this.signInAttempt.supported_first_factors?.find(
      f => f.strategy === 'email_code'
    );
    
    if (!emailFactor) {
      throw new Error('Email code authentication not supported for this user');
    }
    
    await this.prepareFirstFactor({
      strategy: 'email_code',
      email_address_id: emailFactor.email_address_id
    });
    
    // Return the sign-in attempt - user needs to call submitEmailCode next
    return this.signInAttempt;
  }

  async submitEmailCode(code) {
    if (!this.signInAttempt || !this.signInAttempt.first_factor_verification) {
      throw new Error('Must prepare email code first');
    }
    
    return this.attemptFirstFactor({ strategy: 'email_code', code });
  }

  async authenticateWithPhoneCode(identifier) {
    await this.create({ identifier });
    
    // Find phone code factor
    const phoneFactor = this.signInAttempt.supported_first_factors?.find(
      f => f.strategy === 'phone_code'
    );
    
    if (!phoneFactor) {
      throw new Error('Phone code authentication not supported for this user');
    }
    
    await this.prepareFirstFactor({
      strategy: 'phone_code',
      phone_number_id: phoneFactor.phone_number_id
    });
    
    return this.signInAttempt;
  }

  async submitPhoneCode(code) {
    if (!this.signInAttempt || !this.signInAttempt.first_factor_verification) {
      throw new Error('Must prepare phone code first');
    }
    
    return this.attemptFirstFactor({ strategy: 'phone_code', code });
  }
}

// =============================================================================
// SIGN-UP FLOW
// =============================================================================

class SignUpFlow {
  constructor(sdk) {
    this.sdk = sdk;
    this.signUpAttempt = null;
  }

  async create(params) {
    try {
      const { data } = await this.sdk.apiCall('/client/sign_ups', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: new URLSearchParams(params)
      });

      this.signUpAttempt = data.response;
      console.log('✅ Sign-up created:', {
        id: this.signUpAttempt.id,
        status: this.signUpAttempt.status
      });
      
      return this.signUpAttempt;
    } catch (error) {
      console.error('❌ Failed to create sign-up:', error);
      throw error;
    }
  }

  async prepareVerification(params) {
    if (!this.signUpAttempt) {
      throw new Error('Must create sign-up attempt first');
    }

    const { strategy, ...otherParams } = params;
    const body = new URLSearchParams({ strategy, ...otherParams });

    try {
      const { data } = await this.sdk.apiCall(
        `/client/sign_ups/${this.signUpAttempt.id}/prepare_verification`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded'
          },
          body
        }
      );

      this.signUpAttempt = data.response;
      console.log('✅ Verification prepared:', strategy);
      
      return this.signUpAttempt;
    } catch (error) {
      console.error('❌ Failed to prepare verification:', error);
      throw error;
    }
  }

  async attemptVerification(params) {
    if (!this.signUpAttempt) {
      throw new Error('Must create sign-up attempt first');
    }

    const { strategy, ...otherParams } = params;
    const body = new URLSearchParams({ strategy, ...otherParams });

    try {
      const { data } = await this.sdk.apiCall(
        `/client/sign_ups/${this.signUpAttempt.id}/attempt_verification`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded'
          },
          body
        }
      );

      this.signUpAttempt = data.response;

      // If sign-up is complete, set the session
      if (this.signUpAttempt.status === 'complete') {
        const session = data.client.sessions.find(s => 
          s.id === this.signUpAttempt.created_session_id
        );
        if (session) {
          this.sdk.setSession(session);
          console.log('🎉 Sign-up successful!');
        }
      }

      return this.signUpAttempt;
    } catch (error) {
      console.error('❌ Failed to attempt verification:', error);
      throw error;
    }
  }

  // Convenience method for email sign-up
  async signUpWithEmail(emailAddress, password, options = {}) {
    const { firstName, lastName } = options;
    
    const params = {
      email_address: emailAddress,
      password,
      ...(firstName && { first_name: firstName }),
      ...(lastName && { last_name: lastName })
    };
    
    await this.create(params);
    
    // Prepare email verification
    await this.prepareVerification({ strategy: 'email_code' });
    
    // Return sign-up attempt - user needs to verify email
    return this.signUpAttempt;
  }

  async verifyEmail(code) {
    if (!this.signUpAttempt) {
      throw new Error('Must create sign-up attempt first');
    }
    
    return this.attemptVerification({ strategy: 'email_code', code });
  }
}

// =============================================================================
// EXPORT FOR USE
// =============================================================================

// Make it available globally or for module systems
if (typeof module !== 'undefined' && module.exports) {
  module.exports = ClerkSDK;
} else if (typeof window !== 'undefined') {
  window.ClerkSDK = ClerkSDK;
}