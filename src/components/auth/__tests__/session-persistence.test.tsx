import React from 'react';
import { render, waitFor } from '@testing-library/react';
import '@testing-library/jest-dom';
import { createBrowserSupabaseClient } from '@/utils/supabase/client';

// Create a test component that uses session information
const SessionComponent = ({ onSession }: { onSession: (session: any) => void }) => {
  const supabase = createBrowserSupabaseClient();
  
  React.useEffect(() => {
    const { data: { subscription } } = supabase.auth.onAuthStateChange((event, session) => {
      onSession(session);
    });
    
    return () => {
      subscription.unsubscribe();
    };
  }, [supabase, onSession]);
  
  return <div>Session test component</div>;
};

// Mock the Supabase client
jest.mock('@/utils/supabase/client', () => ({
  createBrowserSupabaseClient: jest.fn(),
}));

describe('Session Persistence', () => {
  // Setup variables
  const mockOnAuthStateChange = jest.fn();
  const mockGetSession = jest.fn();
  let authStateChangeCallback: (event: string, session: any) => void;
  let unsubscribeMock: jest.Mock;
  
  beforeEach(() => {
    jest.clearAllMocks();
    
    // Setup the unsubscribe mock
    unsubscribeMock = jest.fn();
    
    // Setup the auth state change mock to capture the callback function
    mockOnAuthStateChange.mockImplementation((callback) => {
      authStateChangeCallback = callback;
      return {
        data: {
          subscription: {
            unsubscribe: unsubscribeMock,
          },
        },
      };
    });
    
    // Setup the mock Supabase client
    (createBrowserSupabaseClient as jest.Mock).mockReturnValue({
      auth: {
        onAuthStateChange: mockOnAuthStateChange,
        getSession: mockGetSession,
      },
    });
  });
  
  test('should subscribe to auth state changes on mount', async () => {
    const onSessionMock = jest.fn();
    
    render(<SessionComponent onSession={onSessionMock} />);
    
    // Check that onAuthStateChange was called
    expect(mockOnAuthStateChange).toHaveBeenCalled();
  });
  
  test('should handle auth state change events correctly', async () => {
    const onSessionMock = jest.fn();
    
    render(<SessionComponent onSession={onSessionMock} />);
    
    // Simulate a signin event with session data
    const mockSession = { user: { id: 'user-123', email: 'test@example.com' } };
    authStateChangeCallback('SIGNED_IN', mockSession);
    
    // Check that the session was passed to the callback
    await waitFor(() => {
      expect(onSessionMock).toHaveBeenCalledWith(mockSession);
    });
  });
  
  test('should unsubscribe from auth changes on unmount', async () => {
    const onSessionMock = jest.fn();
    const { unmount } = render(<SessionComponent onSession={onSessionMock} />);
    
    // Unmount the component
    unmount();
    
    // Check that unsubscribe was called
    expect(unsubscribeMock).toHaveBeenCalled();
  });
  
  test('should handle session restoration on page refresh', async () => {
    // Mock the getSession to return an existing session
    const mockSession = { user: { id: 'user-123', email: 'test@example.com' } };
    mockGetSession.mockResolvedValue({ data: { session: mockSession } });
    
    const onSessionMock = jest.fn();
    
    // Create a component that checks for existing session
    const SessionRestoreComponent = () => {
      const supabase = createBrowserSupabaseClient();
      
      React.useEffect(() => {
        const checkSession = async () => {
          const { data } = await supabase.auth.getSession();
          if (data.session) {
            onSessionMock(data.session);
          }
        };
        
        checkSession();
      }, [supabase]);
      
      return <div>Session restore test</div>;
    };
    
    render(<SessionRestoreComponent />);
    
    // Check that getSession was called and the session was restored
    await waitFor(() => {
      expect(mockGetSession).toHaveBeenCalled();
      expect(onSessionMock).toHaveBeenCalledWith(mockSession);
    });
  });
}); 