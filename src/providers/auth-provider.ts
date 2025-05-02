import { AuthProvider } from "@refinedev/core";
import { createBrowserSupabaseClient } from "@/utils/supabase/client";

/**
 * Auth provider for Refine, working with Supabase Auth
 * Based on the Supabase-Refine tutorial approach
 */
export const authProvider: AuthProvider = {
  login: async ({ email, password }) => {
    const supabase = createBrowserSupabaseClient();
    const { error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });
    
    if (error) {
      return {
        success: false,
        error,
      };
    }

    return {
      success: true,
      redirectTo: "/",
    };
  },
  
  register: async ({ email, password }) => {
    const supabase = createBrowserSupabaseClient();
    const { error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        emailRedirectTo: `${window.location.origin}/auth/callback`,
      },
    });
    
    if (error) {
      return {
        success: false,
        error,
      };
    }
    
    return {
      success: true,
      redirectTo: "/login?message=Check your email to confirm registration",
    };
  },
  
  check: async () => {
    const supabase = createBrowserSupabaseClient();
    const { data } = await supabase.auth.getSession();
    
    if (data?.session) {
      return {
        authenticated: true,
      };
    }
    
    return {
      authenticated: false,
      redirectTo: "/login",
      error: {
        message: "Please login to continue",
        name: "Not authenticated",
      },
    };
  },
  
  logout: async () => {
    const supabase = createBrowserSupabaseClient();
    await supabase.auth.signOut();
    
    return {
      success: true,
      redirectTo: "/login",
    };
  },
  
  onError: async (error) => {
    console.error(error);
    return { error };
  },
  
  getIdentity: async () => {
    const supabase = createBrowserSupabaseClient();
    const { data } = await supabase.auth.getUser();
    
    if (data?.user) {
      // Also fetch profile data from profiles table
      const { data: profile } = await supabase
        .from("profiles")
        .select("*")
        .eq("id", data.user.id)
        .single();
      
      return {
        ...data.user,
        ...profile,
        name: profile?.name || data.user.email,
      };
    }
    
    return null;
  },
  
  getPermissions: async () => {
    // Simple permissions implementation - can be expanded later
    const supabase = createBrowserSupabaseClient();
    const { data } = await supabase.auth.getUser();
    
    return data?.user?.app_metadata?.role || "user";
  },

  forgotPassword: async ({ email }) => {
    const supabase = createBrowserSupabaseClient();
    try {
      const { error } = await supabase.auth.resetPasswordForEmail(
        email,
        {
          redirectTo: `${window.location.origin}/reset-password`,
        }
      );

      if (error) {
        return {
          success: false,
          error,
        };
      }

      return {
        success: true,
        redirectTo: "/login?message=Check your email for a password reset link",
      };
    } catch (error: any) {
      return {
        success: false,
        error: {
          message: error.message || "An unexpected error occurred",
          name: "ForgotPasswordError",
        }
      };
    }
  },

  updatePassword: async ({ password }) => {
    const supabase = createBrowserSupabaseClient();
    try {
      const { data, error } = await supabase.auth.updateUser({
        password,
      });

      if (error) {
        return {
          success: false,
          error,
        };
      }

      // Assuming you have a 'members' table instead of 'profiles' based on migration
      // And assuming you want to update updated_at timestamp on password change
      const user = data.user;
      if (user) {
        const { error: profileError } = await supabase
          .from("members") // Using 'members' table as seen in migration
          .update({ updated_at: new Date().toISOString() })
          .eq("auth_id", user.id); // Matching on auth_id as seen in migration

        if (profileError) {
          console.error("Error updating member profile timestamp:", profileError);
          // Decide if this should block success or just be logged
        }
      }

      return {
        success: true,
        redirectTo: "/account?message=Password updated successfully", // Redirecting to account page might be better
      };
    } catch (error: any) {
      return {
        success: false,
        error: {
          message: error.message || "An unexpected error occurred",
          name: "UpdatePasswordError",
        }
      };
    }
  },
}; 