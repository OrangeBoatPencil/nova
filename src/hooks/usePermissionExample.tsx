"use client";

import React from 'react';
import { usePermission } from './usePermission';
import { Button } from '@/components/ui/button';

interface PermissionExampleProps {
  profileId?: string;
  teamId?: string;
}

export const PermissionExample: React.FC<PermissionExampleProps> = ({
  profileId,
  teamId,
}) => {
  // Use our custom permission hook
  const {
    // User role checks
    isAdmin,
    isCommunityLeader,
    isMember,
    
    // Ownership check
    isOwner,
    
    // Resource permission checks
    canEditProfile,
    canViewProfiles,
    canManageTeam,
    canViewTeams,
    
    // Generic permission check
    checkPermission,
  } = usePermission();

  return (
    <div className="space-y-6">
      <div className="bg-gray-50 p-4 rounded-lg">
        <h3 className="text-lg font-medium mb-2">User Role Information</h3>
        <div className="space-y-1">
          <p>Admin: {isAdmin ? 'Yes' : 'No'}</p>
          <p>Community Leader: {isCommunityLeader ? 'Yes' : 'No'}</p>
          <p>Member: {isMember ? 'Yes' : 'No'}</p>
          {profileId && <p>Profile Owner: {isOwner(profileId) ? 'Yes' : 'No'}</p>}
        </div>
      </div>

      <div className="bg-gray-50 p-4 rounded-lg">
        <h3 className="text-lg font-medium mb-2">Profile Permissions</h3>
        <div className="space-y-2">
          {profileId ? (
            <Button 
              disabled={!canEditProfile(profileId)} 
              variant={canEditProfile(profileId) ? "default" : "outline"}
            >
              Edit Profile
            </Button>
          ) : (
            <Button 
              disabled={!canViewProfiles} 
              variant={canViewProfiles ? "default" : "outline"}
            >
              View All Profiles
            </Button>
          )}
        </div>
      </div>

      <div className="bg-gray-50 p-4 rounded-lg">
        <h3 className="text-lg font-medium mb-2">Team Permissions</h3>
        <div className="space-y-2">
          {teamId ? (
            <>
              <Button 
                disabled={!canManageTeam(teamId)} 
                variant={canManageTeam(teamId) ? "default" : "outline"}
                className="mr-2"
              >
                Edit Team
              </Button>
              <Button 
                disabled={!checkPermission("teams", "delete", teamId)} 
                variant="destructive"
              >
                Delete Team
              </Button>
            </>
          ) : (
            <>
              <Button 
                disabled={!canViewTeams} 
                variant={canViewTeams ? "default" : "outline"}
                className="mr-2"
              >
                View Teams
              </Button>
              <Button 
                disabled={!checkPermission("teams", "create")} 
                variant={checkPermission("teams", "create") ? "default" : "outline"}
              >
                Create Team
              </Button>
            </>
          )}
        </div>
      </div>

      <div className="bg-gray-50 p-4 rounded-lg">
        <h3 className="text-lg font-medium mb-2">Channel Permissions</h3>
        <div className="space-y-2">
          <Button 
            disabled={!checkPermission("channels", "list")} 
            variant={checkPermission("channels", "list") ? "default" : "outline"}
            className="mr-2"
          >
            View Channels
          </Button>
          <Button 
            disabled={!checkPermission("channels", "create")} 
            variant={checkPermission("channels", "create") ? "default" : "outline"}
          >
            Create Channel
          </Button>
        </div>
      </div>
    </div>
  );
}; 