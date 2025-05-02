import { createClient } from '@supabase/supabase-js';
import { testUsers } from './e2e/testData';

// This script creates test users and data in the Supabase database for testing
export async function setupTestData() {
  // Use test environment Supabase URL and service role key
  // In a real setup, these would come from environment variables
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || '';
  const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY || '';
  
  if (!supabaseUrl || !supabaseServiceKey) {
    console.error('Missing Supabase credentials for test setup');
    return;
  }
  
  // Create admin client with service role for direct operations
  const supabase = createClient(supabaseUrl, supabaseServiceKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false
    }
  });
  
  try {
    // Create existing user (if not exists)
    const { error: existingUserError } = await supabase.auth.admin.createUser({
      email: testUsers.existingUser.email,
      password: testUsers.existingUser.password,
      email_confirm: true, // Auto-confirm email
    });
    
    if (existingUserError && !existingUserError.message.includes('already exists')) {
      console.error('Error creating existing test user:', existingUserError);
    }
    
    // Create admin user (if not exists)
    const { data: adminUserData, error: adminUserError } = await supabase.auth.admin.createUser({
      email: testUsers.adminUser.email,
      password: testUsers.adminUser.password,
      email_confirm: true,
    });
    
    if (adminUserError && !adminUserError.message.includes('already exists')) {
      console.error('Error creating admin test user:', adminUserError);
    }
    
    // If admin user was created, give them admin role
    if (adminUserData?.user) {
      // Update user metadata to include admin role
      await supabase.auth.admin.updateUserById(adminUserData.user.id, {
        app_metadata: { role: 'admin' },
      });
      
      // Add user to appropriate tables based on your schema
      // This depends on your specific database schema
      await supabase.from('profiles').upsert({
        id: adminUserData.user.id,
        role: 'admin',
        first_name: 'Admin',
        last_name: 'User',
        status: 'Admin_Active'
      });
    }
    
    console.log('Test data setup complete');
  } catch (error) {
    console.error('Error setting up test data:', error);
  }
}

// Run setup if called directly
if (require.main === module) {
  setupTestData()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error('Failed to set up test data:', error);
      process.exit(1);
    });
} 