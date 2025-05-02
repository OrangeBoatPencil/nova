import { chromium, type FullConfig } from '@playwright/test';

// This runs once before all tests to set up the testing environment
async function globalSetup(config: FullConfig) {
  // Create a browser instance that we'll share for setup
  const browser = await chromium.launch();
  
  // Setup auth state that can be shared across all tests
  const adminContext = await browser.newContext();
  const adminPage = await adminContext.newPage();
  
  // Setup test data - create necessary users, roles, permissions
  // Note: In a real environment, you might want to use direct API calls
  // or database queries for setup rather than UI interactions
  
  // Setup an admin user if needed
  try {
    await adminPage.goto(`${config.projects[0].use.baseURL}/api/test/setup`);
    // This endpoint would set up test data in the database,
    // including the test users defined in the test file
    await adminPage.waitForSelector('text=Test setup complete');
  } catch (error) {
    console.log('Error during test setup:', error);
  }
  
  await browser.close();
  
  // You could also set up state in the database directly
  // e.g., by using the Supabase client to create test data
  
  console.log('Test environment setup complete');
}

export default globalSetup; 