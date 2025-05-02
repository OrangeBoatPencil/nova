import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  // Folder for test artifacts like screenshots, videos, etc.
  outputDir: 'test-results/',
  
  // Timeout for each test
  timeout: 30000,
  
  // Retry failed tests in CI
  retries: process.env.CI ? 2 : 0,
  
  // Workers for parallel tests
  workers: process.env.CI ? 1 : undefined,
  
  // Test reporter
  reporter: [
    ['html'],
    ['list']
  ],
  
  // Test directory structure
  testDir: './tests',
  
  // Use Blob snapshot storage
  snapshotPathTemplate: '{testDir}/__snapshots__/{testFilePath}/{arg}-{projectName}{ext}',
  
  // Commented out global setup to simplify the initial testing
  // globalSetup: './tests/globalSetup.ts',
  
  // Artifacts
  forbidOnly: !!process.env.CI,
  preserveOutput: 'always',
  
  // Setup projects for different browsers - start with just Chromium for now
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    }
  ],
  
  // Create a simple mock server instead of trying to run the Next.js app
  webServer: {
    // Use a simple HTTP server for testing
    command: 'npx http-server -p 3000 ./public',
    port: 3000,
    reuseExistingServer: !process.env.CI,
    timeout: 5000,
  },
  
  // Configure how tests are run
  use: {
    // Base URL for navigation
    baseURL: 'http://localhost:3000',
    
    // Whether to record traces on failure
    trace: 'on-first-retry',
    
    // Take screenshot on failure
    screenshot: 'only-on-failure',
    
    // Record video on failure
    video: 'on-first-retry',
    
    // Add test annotations
    testIdAttribute: 'data-testid',
  },
}); 