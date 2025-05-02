# Authentication Testing

This directory contains comprehensive test suites for testing the email/password authentication flow with Supabase in our Next.js application.

## Test Coverage

These tests cover:

1. **Login Functionality**
   - Successful login with correct credentials
   - Failed login with incorrect credentials
   - Error handling for unexpected issues

2. **Registration Functionality**
   - Successful user registration
   - Error handling for invalid registrations
   - Form validation

3. **OAuth Authentication**
   - GitHub authentication flow
   - Google authentication flow

4. **Session Persistence**
   - Subscribing to auth state changes
   - Handling auth state events
   - Session restoration after page refresh
   - Proper cleanup on component unmount

## Running Tests

To run the authentication tests, use the following commands from the project root:

```bash
# Install dependencies if you haven't already
npm install

# Run all tests
npm test

# Run tests in watch mode (useful during development)
npm run test:watch

# Run only authentication tests
npm test -- auth

# Run with coverage report
npm test -- --coverage
```

## Understanding the Tests

### Mocking Strategy

These tests use Jest's mocking capabilities to mock the Supabase client, allowing us to test authentication flows without making actual API calls. The mocks simulate:

- Successful and failed authentication attempts
- Session management
- OAuth provider integrations

### Test Architecture

- `auth.test.tsx`: Tests for login and registration forms
- `session-persistence.test.tsx`: Tests for session management and persistence

## Extending the Tests

When adding new authentication features, consider:

1. Adding tests for the new functionality
2. Updating existing tests if the authentication flow changes
3. Maintaining high test coverage for all authentication-related components 