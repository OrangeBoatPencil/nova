import { test, expect } from '@playwright/test';

test.describe('Basic Test', () => {
  test('basic test that should pass', async ({ page }) => {
    // Load the static mock API JSON file
    await page.goto('/mock-api.json');
    
    // Verify the content is available
    const content = await page.content();
    expect(content).toContain('success');
    
    // Take a screenshot to verify the test ran
    await page.screenshot({ path: 'test-results/basic-test.png' });
    
    // Successfully complete the test
    expect(true).toBeTruthy();
  });
}); 