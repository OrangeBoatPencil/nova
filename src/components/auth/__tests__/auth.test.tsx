import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import '@testing-library/jest-dom';
import { LoginForm } from '../login-form';
import { RegisterForm } from '../register-form';
import { createBrowserSupabaseClient } from '@/utils/supabase/client';

// Mock the Supabase client
jest.mock('@/utils/supabase/client', () => ({
  createBrowserSupabaseClient: jest.fn(),
}));

// Mock the window.location methods
Object.defineProperty(window, 'location', {
  value: {
    href: '',
    origin: 'http://localhost:3000',
  },
  writable: true,
});

describe('Authentication Flow', () => {
  // Common variables and setup
  const mockSignInWithPassword = jest.fn();
  const mockSignUp = jest.fn();
  const mockSignInWithOAuth = jest.fn();
  
  const mockSupabaseClient = {
    auth: {
      signInWithPassword: mockSignInWithPassword,
      signUp: mockSignUp,
      signInWithOAuth: mockSignInWithOAuth,
    },
  };
  
  beforeEach(() => {
    jest.clearAllMocks();
    (createBrowserSupabaseClient as jest.Mock).mockReturnValue(mockSupabaseClient);
    window.location.href = '';
  });

  describe('Login', () => {
    test('should render login form correctly', () => {
      render(<LoginForm />);
      
      expect(screen.getByText('Login')).toBeInTheDocument();
      expect(screen.getByLabelText('Email')).toBeInTheDocument();
      expect(screen.getByLabelText('Password')).toBeInTheDocument();
      expect(screen.getByRole('button', { name: 'Sign In' })).toBeInTheDocument();
    });

    test('successful login should redirect to homepage', async () => {
      mockSignInWithPassword.mockResolvedValueOnce({ error: null });
      
      render(<LoginForm />);
      
      // Fill in the form
      fireEvent.change(screen.getByLabelText('Email'), { target: { value: 'test@example.com' } });
      fireEvent.change(screen.getByLabelText('Password'), { target: { value: 'password123' } });
      
      // Submit the form
      fireEvent.click(screen.getByRole('button', { name: 'Sign In' }));
      
      // Check if the form shows loading state
      expect(screen.getByRole('button', { name: 'Signing in...' })).toBeInTheDocument();
      
      // Wait for the redirect
      await waitFor(() => {
        expect(mockSignInWithPassword).toHaveBeenCalledWith({
          email: 'test@example.com',
          password: 'password123',
        });
        expect(window.location.href).toBe('/');
      });
    });

    test('failed login should show error message', async () => {
      mockSignInWithPassword.mockResolvedValueOnce({
        error: { message: 'Invalid login credentials' },
      });
      
      render(<LoginForm />);
      
      // Fill in the form
      fireEvent.change(screen.getByLabelText('Email'), { target: { value: 'test@example.com' } });
      fireEvent.change(screen.getByLabelText('Password'), { target: { value: 'wrongpassword' } });
      
      // Submit the form
      fireEvent.click(screen.getByRole('button', { name: 'Sign In' }));
      
      // Wait for the error message
      await waitFor(() => {
        expect(screen.getByText('Invalid login credentials')).toBeInTheDocument();
      });
      
      // Check that we didn't redirect
      expect(window.location.href).toBe('');
    });

    test('login with unexpected error should show generic error message', async () => {
      mockSignInWithPassword.mockRejectedValueOnce(new Error('Unexpected error'));
      
      render(<LoginForm />);
      
      // Fill in the form
      fireEvent.change(screen.getByLabelText('Email'), { target: { value: 'test@example.com' } });
      fireEvent.change(screen.getByLabelText('Password'), { target: { value: 'password123' } });
      
      // Submit the form
      fireEvent.click(screen.getByRole('button', { name: 'Sign In' }));
      
      // Wait for the error message
      await waitFor(() => {
        expect(screen.getByText('An unexpected error occurred')).toBeInTheDocument();
      });
    });
  });

  describe('Registration', () => {
    test('should render registration form correctly', () => {
      render(<RegisterForm />);
      
      expect(screen.getByText('Create an account')).toBeInTheDocument();
      expect(screen.getByLabelText('Email')).toBeInTheDocument();
      expect(screen.getByLabelText('Password')).toBeInTheDocument();
      expect(screen.getByRole('button', { name: 'Create account' })).toBeInTheDocument();
    });

    test('successful registration should show confirmation message', async () => {
      mockSignUp.mockResolvedValueOnce({ error: null });
      
      render(<RegisterForm />);
      
      // Fill in the form
      fireEvent.change(screen.getByLabelText('Email'), { target: { value: 'new@example.com' } });
      fireEvent.change(screen.getByLabelText('Password'), { target: { value: 'newpassword123' } });
      
      // Submit the form
      fireEvent.click(screen.getByRole('button', { name: 'Create account' }));
      
      // Check if the form shows loading state
      expect(screen.getByRole('button', { name: 'Creating account...' })).toBeInTheDocument();
      
      // Wait for the success message
      await waitFor(() => {
        expect(screen.getByText('Check your email for a confirmation link!')).toBeInTheDocument();
      });
      
      // Verify Supabase was called with correct parameters
      expect(mockSignUp).toHaveBeenCalledWith({
        email: 'new@example.com',
        password: 'newpassword123',
        options: {
          emailRedirectTo: 'http://localhost:3000/auth/callback',
        },
      });
    });

    test('failed registration should show error message', async () => {
      mockSignUp.mockResolvedValueOnce({
        error: { message: 'Email already registered' },
      });
      
      render(<RegisterForm />);
      
      // Fill in the form
      fireEvent.change(screen.getByLabelText('Email'), { target: { value: 'existing@example.com' } });
      fireEvent.change(screen.getByLabelText('Password'), { target: { value: 'password123' } });
      
      // Submit the form
      fireEvent.click(screen.getByRole('button', { name: 'Create account' }));
      
      // Wait for the error message
      await waitFor(() => {
        expect(screen.getByText('Email already registered')).toBeInTheDocument();
      });
    });

    test('registration with empty fields should be prevented by HTML validation', async () => {
      const mockSubmit = jest.fn();
      
      // Create a mock form element with the required attribute behavior
      const { container } = render(
        <RegisterForm />
      );
      
      // Get the form
      const form = container.querySelector('form');
      
      // Add a submit listener to check if the form would submit
      if (form) {
        form.onsubmit = mockSubmit;
      }
      
      // Click the submit button without filling required fields
      fireEvent.click(screen.getByRole('button', { name: 'Create account' }));
      
      // The form shouldn't be submitted due to HTML5 validation
      expect(mockSubmit).not.toHaveBeenCalled();
      
      // Supabase signUp shouldn't be called
      expect(mockSignUp).not.toHaveBeenCalled();
    });
  });

  describe('OAuth Authentication', () => {
    test('login with GitHub should call Supabase OAuth method', async () => {
      mockSignInWithOAuth.mockResolvedValueOnce({ error: null });
      
      render(<LoginForm />);
      
      // Click the GitHub button
      fireEvent.click(screen.getByRole('button', { name: /GitHub/i }));
      
      // Verify Supabase was called with correct parameters
      await waitFor(() => {
        expect(mockSignInWithOAuth).toHaveBeenCalledWith({
          provider: 'github',
          options: {
            redirectTo: 'http://localhost:3000/auth/callback',
          },
        });
      });
    });

    test('registration with Google should call Supabase OAuth method', async () => {
      mockSignInWithOAuth.mockResolvedValueOnce({ error: null });
      
      render(<RegisterForm />);
      
      // Click the Google button
      fireEvent.click(screen.getByRole('button', { name: /Google/i }));
      
      // Verify Supabase was called with correct parameters
      await waitFor(() => {
        expect(mockSignInWithOAuth).toHaveBeenCalledWith({
          provider: 'google',
          options: {
            redirectTo: 'http://localhost:3000/auth/callback',
          },
        });
      });
    });
  });
});

// Test for the auth callback route would require mocking Next.js route handlers and Request/Response objects
// This would be better suited for an integration test
// Here's an example structure of how you might approach it:

/*
describe('Auth Callback Route', () => {
  test('successful email verification should redirect to dashboard', async () => {
    // Mock the NextRequest
    const request = {
      url: 'http://localhost:3000/auth/callback?token_hash=abc123&type=email',
      searchParams: new URLSearchParams('token_hash=abc123&type=email'),
    };
    
    // Mock the Supabase verifyOtp function
    const mockVerifyOtp = jest.fn().mockResolvedValueOnce({ error: null });
    const mockSupabaseServer = {
      auth: {
        verifyOtp: mockVerifyOtp,
      },
    };
    
    // Mock the createServerSupabaseClient function
    jest.mock('@/utils/supabase/server', () => ({
      createServerSupabaseClient: jest.fn().mockResolvedValueOnce(mockSupabaseServer),
    }));
    
    // Mock NextResponse
    const mockRedirect = jest.fn();
    jest.mock('next/server', () => ({
      NextResponse: {
        redirect: mockRedirect,
      },
    }));
    
    // Call the route handler
    await GET(request as any);
    
    // Verify the redirect was called with correct URL
    expect(mockRedirect).toHaveBeenCalledWith(expect.stringContaining('/dashboard'));
  });
});
*/ 