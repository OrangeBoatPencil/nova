import { useGetIdentity, useCan, CanParams } from "@refinedev/core";
import { useMemo, useCallback } from "react";

// Types for the resources in our system
type ResourceType = "profiles" | "teams" | "channels" | "dashboard";
type ActionType = "list" | "show" | "create" | "edit" | "delete";

export const usePermission = () => {
  // Get the current user's identity
  const { data: user } = useGetIdentity<{
    id: string;
    email: string;
    role?: string;
  }>();

  // Create a memoized object of role-based checks to avoid unnecessary re-renders
  const roles = useMemo(() => {
    const isAdmin = !!user?.role && user.role === "admin";
    const isCommunityLeader = !!user?.role && user.role === "community_leader";
    const isMember = !!user && !isAdmin && !isCommunityLeader;
    
    return {
      isAdmin,
      isCommunityLeader,
      isMember,
    };
  }, [user]);

  // Ownership check function
  const isOwner = useCallback((resourceId?: string) => {
    if (!resourceId || !user?.id) return false;
    return user.id === resourceId;
  }, [user?.id]);

  // Common permission checks - pre-defined permissions that are frequently needed
  
  // Profile permissions
  const canEditProfileParams = useMemo<CanParams>(() => ({
    resource: "profiles",
    action: "edit",
    params: { id: user?.id },
  }), [user?.id]);
  const { data: canEditProfileData } = useCan(canEditProfileParams);
  
  const canViewProfilesParams = useMemo<CanParams>(() => ({
    resource: "profiles",
    action: "list",
  }), []);
  const { data: canViewProfilesData } = useCan(canViewProfilesParams);
  
  // Team permissions
  const canManageTeamsParams = useMemo<CanParams>(() => ({
    resource: "teams",
    action: "edit",
  }), []);
  const { data: canManageTeamsData } = useCan(canManageTeamsParams);
  
  const canViewTeamsParams = useMemo<CanParams>(() => ({
    resource: "teams",
    action: "list",
  }), []);
  const { data: canViewTeamsData } = useCan(canViewTeamsParams);
  
  // Channel permissions
  const canManageChannelsParams = useMemo<CanParams>(() => ({
    resource: "channels",
    action: "edit",
  }), []);
  const { data: canManageChannelsData } = useCan(canManageChannelsParams);

  // Permission check utility functions for client components
  const canEditProfile = useCallback((profileId?: string) => {
    // Direct ownership check
    if (profileId && isOwner(profileId)) return true;
    
    // Admin check
    if (roles.isAdmin) return true;
    
    // General permission check from access control provider
    return !!canEditProfileData?.can;
  }, [isOwner, roles.isAdmin, canEditProfileData?.can]);
  
  const canManageTeam = useCallback((teamId?: string) => {
    // Admin check
    if (roles.isAdmin) return true;
    
    // Community leaders can manage teams
    if (roles.isCommunityLeader) return true;
    
    // Check from access control provider
    return !!canManageTeamsData?.can;
  }, [roles.isAdmin, roles.isCommunityLeader, canManageTeamsData?.can]);
  
  const canManageChannel = useCallback((channelId?: string) => {
    // Admin check
    if (roles.isAdmin) return true;
    
    // Community leaders can manage channels
    if (roles.isCommunityLeader) return true;
    
    // Check from access control provider
    return !!canManageChannelsData?.can;
  }, [roles.isAdmin, roles.isCommunityLeader, canManageChannelsData?.can]);

  // Return all permissions and check functions
  return {
    // User data
    user,
    
    // Role checks
    ...roles,
    
    // Ownership check
    isOwner,
    
    // Resource permission checks
    canEditProfile,
    canViewProfiles: !!canViewProfilesData?.can,
    canManageTeam,
    canViewTeams: !!canViewTeamsData?.can,
    canManageChannel,
    
    // Simple helper for UI rendering based on permission
    checkPermission: (resource: ResourceType, action: ActionType, id?: string) => {
      // Special cases with custom logic
      if (resource === "profiles" && action === "edit") {
        return canEditProfile(id);
      }
      
      if (resource === "teams" && (action === "edit" || action === "create" || action === "delete")) {
        return canManageTeam(id);
      }
      
      if (resource === "channels" && (action === "edit" || action === "create" || action === "delete")) {
        return canManageChannel(id);
      }
      
      // Default role-based fallbacks
      if (roles.isAdmin) return true;
      
      if (roles.isCommunityLeader) {
        // Community leaders can view all resources
        if (action === "list" || action === "show") return true;
      }
      
      // Regular members can view most things
      if (roles.isMember && (action === "list" || action === "show")) {
        return true;
      }
      
      // Default to false for anything not explicitly allowed
      return false;
    }
  };
}; 