# 🔐 **Clerk Authentication SDK Guide**

> **Build authentication using Clerk's REST API**  
> Version: 1.0.0 | Compatible with Clerk API Version: 2025-04-10

## **📋 Table of Contents**

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Core Methodology](#core-methodology)
- [API Endpoints](#api-endpoints)
- [Authentication Flows](#authentication-flows)
- [Implementation Examples](#implementation-examples)
- [Error Handling](#error-handling)
- [Production Considerations](#production-considerations)

---

## **🎯 Overview**

This guide shows how to build authentication using Clerk's REST API without the official SDK. The methodology is simple: make HTTP requests to Clerk's endpoints to manage authentication state.

### **What You'll Build**
- ✅ Email/password authentication
- ✅ Email code verification
- ✅ Session management
- ✅ JWT token handling
- ✅ User management

---

## **🛠️ Prerequisites**

- **Domain**: Your Clerk instance domain (e.g., `bright-light-9.clerk.accounts.dev`)
- **HTTP Client**: Any tool that can make HTTP requests (curl, fetch, axios)

---

## **🏗️ Core Methodology**

### **Basic Approach**
1. **Initialize Client**: Create client session with Clerk
2. **Authenticate User**: Use sign-in flows to authenticate
3. **Manage Sessions**: Handle session lifecycle and tokens
4. **Make Authenticated Requests**: Use session cookies or JWT tokens

### **Required Parameters**
All requests must include these query parameters:
```
__clerk_api_version=2025-04-10
_clerk_js_version=5.88.0
```

---

## **🌐 API Endpoints**

### **Base URL**
```
https://YOUR_DOMAIN.clerk.accounts.dev/v1
```

### **Core Endpoints**

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/environment` | Get app configuration |
| PUT | `/client` | Create client session |
| GET | `/client` | Get current client state |
| POST | `/client/sign_ins` | Start sign-in process |
| POST | `/client/sign_ins/{id}/attempt_first_factor` | Submit credentials |
| POST | `/client/sessions/{id}/tokens` | Generate JWT token |
| DELETE | `/client/sessions/{id}` | Sign out |

---

## **🔄 Authentication Flows**

### **1. Email + Password Flow**

```
1. Create Client → 2. Start Sign-in → 3. Submit Password → 4. Get Session
```

### **2. Email Code Flow**

```
1. Create Client → 2. Start Sign-in → 3. Prepare Email Code → 4. Submit Code → 5. Get Session
```

---

## **💻 Implementation Examples**

### **1. Initialize Client**

```bash
curl -X PUT "https://bright-light-9.clerk.accounts.dev/v1/client?__clerk_api_version=2025-04-10&_clerk_js_version=5.88.0" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --cookie-jar cookies.txt
```

### **2. Start Sign-in**

```bash
curl -X POST "https://bright-light-9.clerk.accounts.dev/v1/client/sign_ins?__clerk_api_version=2025-04-10&_clerk_js_version=5.88.0" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "identifier=user@example.com" \
  --cookie cookies.txt \
  --cookie-jar cookies.txt
```

Response:
```json
{
  "response": {
    "id": "signin_123",
    "status": "needs_first_factor",
    "identifier": "user@example.com",
    "supported_first_factors": [
      {
        "strategy": "password"
      },
      {
        "strategy": "email_code",
        "email_address_id": "email_456"
      }
    ]
  }
}
```

### **3. Authenticate with Password**

```bash
curl -X POST "https://bright-light-9.clerk.accounts.dev/v1/client/sign_ins/signin_123/attempt_first_factor?__clerk_api_version=2025-04-10&_clerk_js_version=5.88.0" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "strategy=password&password=mypassword" \
  --cookie cookies.txt \
  --cookie-jar cookies.txt
```

### **4. Authenticate with Email Code**

Prepare email code:
```bash
curl -X POST "https://bright-light-9.clerk.accounts.dev/v1/client/sign_ins/signin_123/prepare_first_factor?__clerk_api_version=2025-04-10&_clerk_js_version=5.88.0" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "strategy=email_code&email_address_id=email_456" \
  --cookie cookies.txt \
  --cookie-jar cookies.txt
```

Submit code:
```bash
curl -X POST "https://bright-light-9.clerk.accounts.dev/v1/client/sign_ins/signin_123/attempt_first_factor?__clerk_api_version=2025-04-10&_clerk_js_version=5.88.0" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "strategy=email_code&code=123456" \
  --cookie cookies.txt \
  --cookie-jar cookies.txt
```

### **5. Generate JWT Token**

```bash
curl -X POST "https://bright-light-9.clerk.accounts.dev/v1/client/sessions/sess_123/tokens?__clerk_api_version=2025-04-10&_clerk_js_version=5.88.0&_clerk_session_id=sess_123" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "template=" \
  --cookie cookies.txt
```

Response:
```json
{
  "response": {
    "jwt": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

### **6. Get Current User**

```bash
curl -X GET "https://bright-light-9.clerk.accounts.dev/v1/me?__clerk_api_version=2025-04-10&_clerk_js_version=5.88.0&_clerk_session_id=sess_123" \
  --cookie cookies.txt
```

### **7. Sign Out**

```bash
curl -X DELETE "https://bright-light-9.clerk.accounts.dev/v1/client/sessions/sess_123?__clerk_api_version=2025-04-10&_clerk_js_version=5.88.0&_clerk_session_id=sess_123" \
  --cookie cookies.txt \
  --cookie-jar cookies.txt
```

---

## **⚠️ Error Handling**

### **Common Error Codes**
- `form_identifier_not_found`: User doesn't exist
- `form_password_incorrect`: Wrong password
- `form_code_incorrect`: Wrong verification code
- `session_token_expired`: Session expired
- `rate_limit_exceeded`: Too many attempts

### **Error Response Format**
```json
{
  "errors": [
    {
      "code": "form_password_incorrect",
      "message": "Password is incorrect",
      "long_message": "The password you entered is incorrect. Please try again."
    }
  ]
}
```

### **Retry Logic**
```bash
# Retry with exponential backoff
for i in {1..3}; do
  if curl -X POST "https://example.com/api" -d "data"; then
    break
  else
    sleep $((2**i))
  fi
done
```

---

## **🔧 Common Implementation Issues**

### **1. Development Browser Issues**

When testing with curl locally, you may encounter CORS and cookie issues:

```bash
# Problem: Cookies not being set properly in dev
# Solution: Use explicit cookie handling

# Save cookies to file
curl -X PUT "https://bright-newt-8.clerk.accounts.dev/v1/client?__clerk_api_version=2025-04-10&_clerk_js_version=5.88.0" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -c cookies.txt \
  -b cookies.txt

# Always include both -c (save) and -b (load) cookies
curl -X POST "https://bright-newt-8.clerk.accounts.dev/v1/client/sign_ins?__clerk_api_version=2025-04-10&_clerk_js_version=5.88.0" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "identifier=user@example.com" \
  -c cookies.txt \
  -b cookies.txt
```

### **2. CORS Handling**

When making requests from a browser application:

```javascript
// For development, you may need to proxy requests
const proxyUrl = 'https://cors-anywhere.herokuapp.com/';
const targetUrl = 'https://bright-newt-8.clerk.accounts.dev/v1/client';

// Or set up a local proxy server
// npm install -g cors-anywhere
// cors-anywhere --port 8080

fetch('/api/clerk-proxy/client', {
  method: 'PUT',
  headers: {
    'Content-Type': 'application/x-www-form-urlencoded',
  },
  credentials: 'include' // Important for cookies
});
```

**Express.js Proxy Example:**
```javascript
// server.js
const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');

const app = express();

app.use('/api/clerk-proxy', createProxyMiddleware({
  target: 'https://bright-newt-8.clerk.accounts.dev/v1',
  changeOrigin: true,
  pathRewrite: {
    '^/api/clerk-proxy': ''
  },
  onProxyReq: (proxyReq, req, res) => {
    // Add required parameters
    const url = new URL(proxyReq.path, 'https://bright-newt-8.clerk.accounts.dev');
    url.searchParams.append('__clerk_api_version', '2025-04-10');
    url.searchParams.append('_clerk_js_version', '5.88.0');
    proxyReq.path = url.pathname + url.search;
  }
}));
```

### **3. Persistent Authentication**

Store authentication state across browser sessions:

```javascript
// Save session info to localStorage
function saveAuthState(session) {
  const authState = {
    sessionId: session.id,
    userId: session.user.id,
    expiresAt: session.expire_at,
    savedAt: Date.now()
  };
  localStorage.setItem('clerk_auth_state', JSON.stringify(authState));
}

// Restore session on page load
function restoreAuthState() {
  const saved = localStorage.getItem('clerk_auth_state');
  if (!saved) return null;
  
  const authState = JSON.parse(saved);
  const now = Date.now();
  
  // Check if session might still be valid (expires in 7 days by default)
  if (now - authState.savedAt > 6 * 24 * 60 * 60 * 1000) { // 6 days
    localStorage.removeItem('clerk_auth_state');
    return null;
  }
  
  return authState;
}

// Check if existing session is still valid
async function validateStoredSession(sessionId) {
  try {
    const response = await fetch(`/api/clerk-proxy/client/sessions/${sessionId}?__clerk_api_version=2025-04-10&_clerk_js_version=5.88.0&_clerk_session_id=${sessionId}`, {
      credentials: 'include'
    });
    
    if (response.ok) {
      const data = await response.json();
      return data.response.status === 'active';
    }
  } catch (error) {
    console.error('Session validation failed:', error);
  }
  return false;
}
```

**Using curl for session persistence:**
```bash
#!/bin/bash

DOMAIN="bright-newt-8.clerk.accounts.dev"
COOKIES_FILE="$HOME/.clerk_cookies"
AUTH_STATE_FILE="$HOME/.clerk_auth_state"

# Function to save auth state
save_auth_state() {
  local session_id=$1
  echo "SESSION_ID=${session_id}" > "$AUTH_STATE_FILE"
  echo "SAVED_AT=$(date +%s)" >> "$AUTH_STATE_FILE"
}

# Function to load auth state
load_auth_state() {
  if [ -f "$AUTH_STATE_FILE" ]; then
    source "$AUTH_STATE_FILE"
    local now=$(date +%s)
    local age=$((now - SAVED_AT))
    
    # If older than 6 days, remove
    if [ $age -gt 518400 ]; then
      rm "$AUTH_STATE_FILE" "$COOKIES_FILE" 2>/dev/null
      return 1
    fi
    
    echo "$SESSION_ID"
    return 0
  fi
  return 1
}

# Check if we have a stored session
if SESSION_ID=$(load_auth_state); then
  echo "Found stored session: $SESSION_ID"
  
  # Validate the session
  if curl -s -X GET "https://${DOMAIN}/v1/client/sessions/${SESSION_ID}?__clerk_api_version=2025-04-10&_clerk_js_version=5.88.0&_clerk_session_id=${SESSION_ID}" \
    -b "$COOKIES_FILE" >/dev/null; then
    echo "Session is still valid"
    exit 0
  else
    echo "Stored session expired, need to re-authenticate"
    rm "$AUTH_STATE_FILE" "$COOKIES_FILE" 2>/dev/null
  fi
fi

# Proceed with authentication flow...
echo "Starting new authentication..."
```

### **4. Development Environment Setup**

**Local Testing with Self-Signed Certificates:**
```bash
# Create local development certificate
openssl req -x509 -newkey rsa:4096 -keyout localhost-key.pem -out localhost-cert.pem -days 365 -nodes -subj '/CN=localhost'

# Start local HTTPS server (Node.js example)
# server.js
const https = require('https');
const fs = require('fs');
const express = require('express');

const app = express();
const options = {
  key: fs.readFileSync('localhost-key.pem'),
  cert: fs.readFileSync('localhost-cert.pem')
};

https.createServer(options, app).listen(3000, () => {
  console.log('HTTPS Server running on https://localhost:3000');
});
```

### **5. Error Recovery Patterns**

Handle common development issues:

```bash
#!/bin/bash

# Function to handle network errors
handle_request() {
  local url=$1
  local method=${2:-GET}
  local data=${3:-}
  local max_retries=3
  local retry_delay=1
  
  for i in $(seq 1 $max_retries); do
    local cmd="curl -s -w '%{http_code}' -X $method"
    
    if [ -n "$data" ]; then
      cmd="$cmd -d '$data'"
    fi
    
    cmd="$cmd '$url' -b cookies.txt -c cookies.txt"
    
    local response=$(eval $cmd)
    local http_code=${response: -3}
    local body=${response%???}
    
    case $http_code in
      200|201|204)
        echo "$body"
        return 0
        ;;
      401|403)
        echo "Authentication failed: $body"
        rm -f cookies.txt  # Clear invalid session
        return 1
        ;;
      429)
        echo "Rate limited, waiting..."
        sleep $((retry_delay * 2))
        ;;
      5*)
        echo "Server error, retrying in ${retry_delay}s..."
        sleep $retry_delay
        retry_delay=$((retry_delay * 2))
        ;;
      *)
        echo "Unexpected response: $http_code - $body"
        return 1
        ;;
    esac
  done
  
  echo "Max retries exceeded"
  return 1
}

# Usage
if ! handle_request "https://bright-newt-8.clerk.accounts.dev/v1/client?__clerk_api_version=2025-04-10&_clerk_js_version=5.88.0" "PUT"; then
  echo "Failed to initialize client"
  exit 1
fi
```

---

## **🚀 Production Considerations**

### **1. Session Management**
- Store session cookies securely
- Implement session refresh logic
- Handle session expiration gracefully

### **2. Token Handling**
- Cache JWT tokens until expiry
- Decode tokens to check expiration
- Use appropriate token templates for different services

### **3. Security**
- Always use HTTPS
- Validate all inputs
- Implement rate limiting
- Store sensitive data securely

### **4. Error Recovery**
```bash
# Check if session is still valid
curl -X GET "https://bright-light-9.clerk.accounts.dev/v1/client/sessions/sess_123?__clerk_api_version=2025-04-10&_clerk_js_version=5.88.0&_clerk_session_id=sess_123" \
  --cookie cookies.txt

# If session expired, redirect to sign-in
if [ $? -ne 0 ]; then
  echo "Session expired, redirecting to sign-in"
fi
```

---

## **📊 Complete Flow Example**

```bash
#!/bin/bash

DOMAIN="bright-light-9.clerk.accounts.dev"
EMAIL="user@example.com"
PASSWORD="mypassword"
COOKIES="cookies.txt"

# 1. Initialize client
echo "Initializing client..."
curl -X PUT "https://${DOMAIN}/v1/client?__clerk_api_version=2025-04-10&_clerk_js_version=5.88.0" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --cookie-jar $COOKIES

# 2. Start sign-in
echo "Starting sign-in..."
SIGNIN_RESPONSE=$(curl -s -X POST "https://${DOMAIN}/v1/client/sign_ins?__clerk_api_version=2025-04-10&_clerk_js_version=5.88.0" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "identifier=${EMAIL}" \
  --cookie $COOKIES \
  --cookie-jar $COOKIES)

SIGNIN_ID=$(echo $SIGNIN_RESPONSE | jq -r '.response.id')
echo "Sign-in ID: $SIGNIN_ID"

# 3. Authenticate with password
echo "Authenticating..."
AUTH_RESPONSE=$(curl -s -X POST "https://${DOMAIN}/v1/client/sign_ins/${SIGNIN_ID}/attempt_first_factor?__clerk_api_version=2025-04-10&_clerk_js_version=5.88.0" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "strategy=password&password=${PASSWORD}" \
  --cookie $COOKIES \
  --cookie-jar $COOKIES)

STATUS=$(echo $AUTH_RESPONSE | jq -r '.response.status')
SESSION_ID=$(echo $AUTH_RESPONSE | jq -r '.response.created_session_id')

if [ "$STATUS" = "complete" ]; then
  echo "Authentication successful! Session ID: $SESSION_ID"
  
  # 4. Get JWT token
  echo "Getting JWT token..."
  TOKEN_RESPONSE=$(curl -s -X POST "https://${DOMAIN}/v1/client/sessions/${SESSION_ID}/tokens?__clerk_api_version=2025-04-10&_clerk_js_version=5.88.0&_clerk_session_id=${SESSION_ID}" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "template=" \
    --cookie $COOKIES)
  
  JWT=$(echo $TOKEN_RESPONSE | jq -r '.response.jwt')
  echo "JWT: $JWT"
  
  # 5. Get user info
  echo "Getting user info..."
  USER_RESPONSE=$(curl -s -X GET "https://${DOMAIN}/v1/me?__clerk_api_version=2025-04-10&_clerk_js_version=5.88.0&_clerk_session_id=${SESSION_ID}" \
    --cookie $COOKIES)
  
  echo "User info: $USER_RESPONSE"
  
else
  echo "Authentication failed: $STATUS"
fi
```

---

## **🎯 Key Takeaways**

1. **Cookie-Based**: Clerk uses HTTP cookies for session management
2. **Stateful API**: Each request builds on previous state
3. **Error Handling**: Always check response status and handle errors
4. **Security**: Use HTTPS and secure cookie storage
5. **Session Management**: Implement proper session lifecycle handling

---

**Happy Building! 🚀**