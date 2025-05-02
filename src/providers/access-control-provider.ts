import { AccessControlProvider } from "@refinedev/core";
import { createBrowserSupabaseClient } from "@/utils/supabase/client";

// Helper function to safely compare IDs of any type
const safeIdCompare = (id1: any, id2: any): boolean => {
  if (id1 === undefined || id1 === null || id2 === undefined || id2 === null) {
    return false;
  }
  return String(id1) === String(id2);
};

export const accessControlProvider: AccessControlProvider = {
  can: async ({ resource, action, params }) => {
    // Get current user
    const supabase = createBrowserSupabaseClient();
    const { data } = await supabase.auth.getUser();
    if (!data.user) {
      return {
        can: false,
        reason: "Unauthorized",
      };
    }

    // Get user's role from members table
    const { data: member, error } = await supabase
      .from("members")
      .select("id, role")
      .eq("auth_id", data.user.id)
      .single();

    if (error || !member) {
      console.error("Failed to get member data:", error);
      return {
        can: false,
        reason: "User profile not found",
      };
    }

    // Check if user is an admin (has admin permissions)
    const isAdmin = member.role === "admin";
    if (isAdmin) {
      return { can: true };
    }

    // Check if user is a community leader
    const isCommunityLeader = member.role === "community_leader";
    
    // Community leader can manage teams and view profiles
    if (isCommunityLeader) {
      if (resource === "teams") {
        return { can: true };
      }
      
      if (resource === "profiles" && ["list", "show"].includes(action)) {
        return { can: true };
      }
      
      if (resource === "channels") {
        return { can: true };
      }
    }

    // Regular member permissions
    // Members can edit their own profile
    if (resource === "profiles" && action === "edit") {
      const paramsId = params && typeof params === 'object' && 'id' in params ? params.id : null;
      
      // Allow if it's the user's own profile using safe comparison
      if (safeIdCompare(paramsId, member.id)) {
        return { can: true };
      }
      
      return { 
        can: false,
        reason: "You can only edit your own profile" 
      };
    }
    
    // Members can view other profiles, teams, and channels
    if (resource && ["profiles", "teams", "channels"].includes(resource) && 
        action && ["list", "show"].includes(action)) {
      return { can: true };
    }

    // Default: deny access
    return {
      can: false,
      reason: "You don't have permission to perform this action",
    };
  },
}; 