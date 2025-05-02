import { createClient } from '@supabase/supabase-js';
import { NextResponse } from 'next/server';

// This endpoint is for testing purposes only and should be disabled in production
export async function GET() {
  // Only allow this in development and test environments
  if (process.env.NODE_ENV === 'production') {
    return NextResponse.json({ error: 'Not available in production' }, { status: 403 });
  }
  
  try {
    // Import the setup function and run it
    const { setupTestData } = await import('../../../../../tests/setupTestData');
    await setupTestData();
    
    return NextResponse.json({ message: 'Test setup complete' }, { status: 200 });
  } catch (error) {
    console.error('Error in test setup endpoint:', error);
    return NextResponse.json({ error: 'Test setup failed' }, { status: 500 });
  }
} 