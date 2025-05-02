import { test, expect, Page } from '@playwright/test';
import { testUsers } from './testData';

// Helper functions
async function login(page: Page, email: string, password: string) {
  await page.goto('/login');
  await page.fill('input[type="email"]', email);
  await page.fill('input[type="password"]', password);
  await page.click('button[type="submit"]');
}

async function approveApplication(page: Page, email: string) {
  // This function simulates admin approval of a new application
  await login(page, testUsers.adminUser.email, testUsers.adminUser.password);
  await page.goto('/admin/applications');
  
  // Find and approve the application by email
  await page.fill('input[placeholder="Search applications"]', email);
  await page.click('button:has-text("Search")');
  
  // Click the approve button for this application
  await page.click(`tr:has-text("${email}") button:has-text("Approve")`);
  
  // Confirm approval
  await page.click('button:has-text("Confirm")');
  
  // Wait for confirmation message
  await page.waitForSelector('text=Application approved successfully');
  
  // Logout from admin account
  await page.click('button:has-text("Logout")');
}

test.describe('Authentication Flow End-to-End', () => {
  test.beforeEach(async ({ page }) => {
    // Start with a clean state for each test
    await page.goto('/');
  });
  
  test('Complete registration and login flow with email', async ({ page, browser }) => {
    // 1. Submit application
    await page.goto('/register');
    await page.fill('input[name="email"]', testUsers.newUser.email);
    await page.fill('input[name="firstName"]', testUsers.newUser.firstName);
    await page.fill('input[name="lastName"]', testUsers.newUser.lastName);
    await page.fill('input[name="company"]', testUsers.newUser.company);
    await page.click('button[type="submit"]');
    
    // 2. Verify application submitted page
    await expect(page.locator('h1:has-text("Application Submitted")')).toBeVisible();
    
    // 3. Admin approves the application (in a new browser context)
    const adminContext = await browser.newContext();
    const adminPage = await adminContext.newPage();
    await approveApplication(adminPage, testUsers.newUser.email);
    await adminContext.close();
    
    // 4. In a real test, we'd use a test email service to intercept emails
    // Here we'll simulate by directly accessing the token verification page
    // with a valid token (in a real test, we'd extract this from the email)
    const simulatedToken = 'valid-test-token';
    await page.goto(`/verify-token?token=${simulatedToken}&email=${testUsers.newUser.email}`);
    
    // 5. Set password page
    await expect(page.locator('h1:has-text("Set Your Password")')).toBeVisible();
    await page.fill('input[name="password"]', testUsers.newUser.password);
    await page.fill('input[name="confirmPassword"]', testUsers.newUser.password);
    await page.click('button[type="submit"]');
    
    // 6. Payment page (assuming test environment bypasses actual payment)
    await expect(page.locator('h1:has-text("Complete Your Registration")')).toBeVisible();
    await page.click('button:has-text("Complete Registration")'); // Simulate successful payment
    
    // 7. Verify redirect to dashboard after registration complete
    await expect(page).toHaveURL('/dashboard');
    await expect(page.locator('text=Welcome, New User')).toBeVisible();
    
    // 8. Logout
    await page.click('button:has-text("Logout")');
    await expect(page).toHaveURL('/login');
    
    // 9. Login with newly created account
    await login(page, testUsers.newUser.email, testUsers.newUser.password);
    
    // 10. Verify successful login
    await expect(page).toHaveURL('/dashboard');
    await expect(page.locator('text=Welcome, New User')).toBeVisible();
    
    // 11. Access protected page
    await page.click('a:has-text("Settings")');
    await expect(page).toHaveURL('/settings');
    
    // 12. Verify that user-specific content is displayed
    await expect(page.locator(`text=${testUsers.newUser.email}`)).toBeVisible();
  });
  
  test('Login with existing user and access control', async ({ page }) => {
    // 1. Login with existing user
    await login(page, testUsers.existingUser.email, testUsers.existingUser.password);
    
    // 2. Verify successful login
    await expect(page).toHaveURL('/dashboard');
    
    // 3. Regular member should not see admin features
    await expect(page.locator('a:has-text("Admin Panel")')).not.toBeVisible();
    
    // 4. Access member-accessible page
    await page.click('a:has-text("My Profile")');
    await expect(page).toHaveURL('/profile');
    
    // 5. Try to access admin page directly (should be redirected)
    await page.goto('/admin');
    await expect(page).not.toHaveURL('/admin');
    await expect(page.locator('text=Access Denied')).toBeVisible();
    
    // 6. Logout
    await page.click('button:has-text("Logout")');
    await expect(page).toHaveURL('/login');
  });
  
  test('Magic link authentication flow', async ({ page, browser }) => {
    // 1. Go to login page
    await page.goto('/login');
    
    // 2. Click on magic link tab
    await page.click('button:has-text("Magic Link")');
    
    // 3. Enter email
    await page.fill('input[type="email"]', testUsers.existingUser.email);
    await page.click('button[type="submit"]');
    
    // 4. Verify confirmation page
    await expect(page.locator('text=Check your email')).toBeVisible();
    
    // 5. In a real test, intercept the email and extract the magic link
    // Here we'll simulate by directly accessing a magic link page
    // with a valid token (in a real test, we'd extract this from the email)
    const simulatedOtpToken = 'valid-otp-token';
    await page.goto(`/auth/callback?token_hash=${simulatedOtpToken}&type=magiclink&email=${testUsers.existingUser.email}`);
    
    // 6. Verify redirect to dashboard after magic link authentication
    await expect(page).toHaveURL('/dashboard');
    
    // 7. Verify user is logged in
    const userName = await page.locator('text=Welcome').textContent();
    expect(userName).toContain('Welcome');
  });
  
  test('Google OAuth authentication flow', async ({ page }) => {
    // 1. Go to login page
    await page.goto('/login');
    
    // 2. Mock Google OAuth by intercepting and modifying response
    await page.route('**/auth/v1/authorize**', async (route) => {
      // Extract the redirect URI from the request to Supabase
      const url = new URL(route.request().url());
      const redirectUri = url.searchParams.get('redirect_uri');
      const state = url.searchParams.get('state');
      
      // Simulate an OAuth callback with a success code
      if (redirectUri) {
        // Redirect to the callback URL with a mock code
        await route.fulfill({
          status: 302,
          headers: {
            location: `${redirectUri}?code=mock-oauth-code&state=${state}`,
          },
        });
      } else {
        await route.continue();
      }
    });
    
    // 3. Mock the code exchange response
    await page.route('**/auth/v1/token**', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          access_token: 'mock-access-token',
          refresh_token: 'mock-refresh-token',
          expires_in: 3600,
          user: {
            id: 'google-user-id',
            email: 'google-user@example.com',
            app_metadata: {
              provider: 'google',
            },
            user_metadata: {
              full_name: 'Google User',
              avatar_url: 'https://example.com/avatar.jpg',
            },
          },
        }),
      });
    });
    
    // 4. Mock the user profile request
    await page.route('**/rest/v1/profiles**', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify([{
          id: 'google-user-id',
          status: 'Member_Active',
          first_name: 'Google',
          last_name: 'User',
          avatar_url: 'https://example.com/avatar.jpg',
        }]),
      });
    });
    
    // 5. Click the Google OAuth button
    await page.click('button:has-text("Continue with Google")');
    
    // 6. Verify redirect to dashboard after OAuth authentication
    await expect(page).toHaveURL('/dashboard');
    
    // 7. Verify user is logged in
    await expect(page.locator('text=Welcome, Google User')).toBeVisible();
  });
  
  test('Password reset flow', async ({ page }) => {
    // 1. Go to forgot password page
    await page.goto('/forgot-password');
    
    // 2. Enter email
    await page.fill('input[type="email"]', testUsers.existingUser.email);
    await page.click('button[type="submit"]');
    
    // 3. Verify confirmation page
    await expect(page.locator('text=Check your email')).toBeVisible();
    
    // 4. In a real test, intercept the email and extract the reset link
    // Here we'll simulate by directly accessing the reset page
    // with a valid token (in a real test, we'd extract this from the email)
    const simulatedResetToken = 'valid-reset-token';
    await page.goto(`/reset-password?token=${simulatedResetToken}&email=${testUsers.existingUser.email}`);
    
    // 5. Enter new password
    const newPassword = 'NewPassword456!';
    await page.fill('input[name="password"]', newPassword);
    await page.fill('input[name="confirmPassword"]', newPassword);
    await page.click('button[type="submit"]');
    
    // 6. Verify success page
    await expect(page.locator('text=Password updated successfully')).toBeVisible();
    
    // 7. Login with new password
    await login(page, testUsers.existingUser.email, newPassword);
    
    // 8. Verify successful login
    await expect(page).toHaveURL('/dashboard');
  });
  
  test('Session persistence across page refreshes', async ({ page }) => {
    // 1. Login with existing user
    await login(page, testUsers.existingUser.email, testUsers.existingUser.password);
    
    // 2. Verify successful login
    await expect(page).toHaveURL('/dashboard');
    
    // 3. Reload the page
    await page.reload();
    
    // 4. Verify user is still logged in
    await expect(page).toHaveURL('/dashboard');
    
    // 5. Navigate to another protected page
    await page.click('a:has-text("Settings")');
    await expect(page).toHaveURL('/settings');
    
    // 6. Reload again
    await page.reload();
    
    // 7. Verify user is still on the protected page
    await expect(page).toHaveURL('/settings');
  });
  
  test('Role-based access control', async ({ page }) => {
    // 1. Login with admin user
    await login(page, testUsers.adminUser.email, testUsers.adminUser.password);
    
    // 2. Verify admin has access to admin panel
    await expect(page.locator('a:has-text("Admin Panel")')).toBeVisible();
    await page.click('a:has-text("Admin Panel")');
    await expect(page).toHaveURL('/admin');
    
    // 3. Verify admin can access team management
    await expect(page.locator('a:has-text("Team Management")')).toBeVisible();
    await page.click('a:has-text("Team Management")');
    await expect(page).toHaveURL('/teams/management');
    
    // 4. Logout
    await page.click('button:has-text("Logout")');
    
    // 5. Login with regular member
    await login(page, testUsers.existingUser.email, testUsers.existingUser.password);
    
    // 6. Verify regular member cannot see admin links
    await expect(page.locator('a:has-text("Admin Panel")')).not.toBeVisible();
    
    // 7. Attempt to access admin page directly
    await page.goto('/admin');
    await expect(page.locator('text=Access Denied')).toBeVisible();
    
    // 8. Attempt to access team management directly
    await page.goto('/teams/management');
    await expect(page.locator('text=Access Denied')).toBeVisible();
  });
  
  test('Handle authentication errors', async ({ page }) => {
    // 1. Try login with wrong password
    await page.goto('/login');
    await page.fill('input[type="email"]', testUsers.existingUser.email);
    await page.fill('input[type="password"]', 'WrongPassword123!');
    await page.click('button[type="submit"]');
    
    // 2. Verify error message
    await expect(page.locator('text=Invalid email or password')).toBeVisible();
    
    // 3. Try invalid reset token
    await page.goto('/reset-password?token=invalid-token&email=test@example.com');
    await expect(page.locator('text=Invalid or expired token')).toBeVisible();
    
    // 4. Test rate limiting
    // This test is simulated as actual rate limiting would require multiple attempts
    await page.route('**/auth/v1/**', async (route) => {
      if (route.request().method() === 'POST') {
        // After 3 attempts, return rate limit error
        const rateLimit = await page.evaluate(() => {
          const attempts = parseInt(localStorage.getItem('loginAttempts') || '0');
          localStorage.setItem('loginAttempts', (attempts + 1).toString());
          return attempts >= 2; // Return true for rate limit after 3 attempts
        });
        
        if (rateLimit) {
          await route.fulfill({
            status: 429,
            contentType: 'application/json',
            body: JSON.stringify({
              error: 'Too many requests',
              code: 'rate_limit_exceeded',
            }),
          });
        } else {
          await route.continue();
        }
      } else {
        await route.continue();
      }
    });
    
    // 5. Attempt login multiple times
    for (let i = 0; i < 4; i++) {
      await page.goto('/login');
      await page.fill('input[type="email"]', testUsers.existingUser.email);
      await page.fill('input[type="password"]', 'WrongPassword123!');
      await page.click('button[type="submit"]');
    }
    
    // 6. Verify rate limit error
    await expect(page.locator('text=Too many attempts')).toBeVisible();
  });
}); 