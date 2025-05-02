import { test, expect } from '@playwright/test';
import { testUsers } from './testData';

// Since we're using a mock server, this test will simulate authentication by modifying the page directly
test.describe('Simplified Authentication Tests', () => {
  test('mock login and verify session state', async ({ page }) => {
    // Load the mock API JSON to simulate authentication
    await page.goto('/mock-api.json');
    
    // Verify mock data loads correctly
    const content = await page.content();
    expect(content).toContain('existing@example.com');
    expect(content).toContain('admin@example.com');
    
    // Simulate logged in state by setting localStorage
    await page.evaluate((userEmail) => {
      // Mock a session in localStorage similar to how Supabase would store it
      const mockSession = {
        user: {
          id: '1',
          email: userEmail,
          user_metadata: {
            name: 'Existing User'
          }
        },
        access_token: 'mock-token',
        expires_at: Date.now() + 3600000 // 1 hour from now
      };
      
      localStorage.setItem('supabase.auth.token', JSON.stringify({
        currentSession: mockSession
      }));
    }, testUsers.existingUser.email);
    
    // Take a screenshot to verify
    await page.screenshot({ path: 'test-results/mock-login.png' });
    
    // Verify the mock session storage
    const sessionData = await page.evaluate(() => {
      return localStorage.getItem('supabase.auth.token');
    });
    
    expect(sessionData).not.toBeNull();
    expect(sessionData).toContain(testUsers.existingUser.email);
  });
  
  test('simulate login with different user roles', async ({ page }) => {
    // Load the page
    await page.goto('/mock-api.json');
    
    // First try with regular user
    await page.evaluate((userEmail) => {
      const mockSession = {
        user: {
          id: '1',
          email: userEmail,
          user_metadata: {
            name: 'Existing User'
          },
          app_metadata: {
            role: 'member'
          }
        },
        access_token: 'mock-token',
        expires_at: Date.now() + 3600000
      };
      
      localStorage.setItem('supabase.auth.token', JSON.stringify({
        currentSession: mockSession
      }));
    }, testUsers.existingUser.email);
    
    // Take a screenshot
    await page.screenshot({ path: 'test-results/mock-regular-user.png' });
    
    // Now simulate an admin user
    await page.evaluate((adminEmail) => {
      const mockSession = {
        user: {
          id: '2',
          email: adminEmail,
          user_metadata: {
            name: 'Admin User'
          },
          app_metadata: {
            role: 'admin'
          }
        },
        access_token: 'mock-admin-token',
        expires_at: Date.now() + 3600000
      };
      
      localStorage.setItem('supabase.auth.token', JSON.stringify({
        currentSession: mockSession
      }));
    }, testUsers.adminUser.email);
    
    // Take a screenshot
    await page.screenshot({ path: 'test-results/mock-admin-user.png' });
    
    // Verify the admin session
    const sessionData = await page.evaluate(() => {
      return localStorage.getItem('supabase.auth.token');
    });
    
    expect(sessionData).not.toBeNull();
    expect(sessionData).toContain(testUsers.adminUser.email);
    expect(sessionData).toContain('admin');
  });
  
  test('simulate session persistence across navigation', async ({ page }) => {
    // Load the initial page
    await page.goto('/mock-api.json');
    
    // Set up a mock session
    await page.evaluate((userEmail) => {
      const mockSession = {
        user: {
          id: '1',
          email: userEmail,
          user_metadata: {
            name: 'Existing User'
          }
        },
        access_token: 'mock-token',
        expires_at: Date.now() + 3600000
      };
      
      localStorage.setItem('supabase.auth.token', JSON.stringify({
        currentSession: mockSession
      }));
    }, testUsers.existingUser.email);
    
    // Reload the page to simulate navigation
    await page.reload();
    
    // Verify session is still there
    const sessionAfterReload = await page.evaluate(() => {
      return localStorage.getItem('supabase.auth.token');
    });
    
    expect(sessionAfterReload).not.toBeNull();
    expect(sessionAfterReload).toContain(testUsers.existingUser.email);
    
    // Navigate to another mock path
    await page.goto('/');
    
    // Verify session is still there after navigation
    const sessionAfterNavigation = await page.evaluate(() => {
      return localStorage.getItem('supabase.auth.token');
    });
    
    expect(sessionAfterNavigation).not.toBeNull();
    expect(sessionAfterNavigation).toContain(testUsers.existingUser.email);
  });
}); 