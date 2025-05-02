"use client";

import React from "react";
import { useParams } from "next/navigation";
import { useShow } from "@refinedev/core";
import { Authenticated } from "@refinedev/core";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { usePermission } from "@/hooks/usePermission";
import Link from "next/link";

export default function TeamShow() {
  const params = useParams();
  const teamId = params.id as string;
  const { canManageTeam, isAdmin } = usePermission();
  
  const { queryResult } = useShow({
    resource: "teams",
    id: teamId,
  });
  
  const { data, isLoading } = queryResult;
  const team = data?.data;
  
  if (isLoading) {
    return <div className="flex items-center justify-center p-6">Loading...</div>;
  }
  
  if (!team) {
    return <div className="flex items-center justify-center p-6">Team not found</div>;
  }
  
  const content = (
    <div className="p-6">
      <div className="flex justify-between items-center mb-6">
        <h2 className="text-3xl font-bold">{team.name}</h2>
        
        {canManageTeam(String(team.id)) && (
          <Button asChild>
            <Link href={`/teams/${team.id}/edit`}>Edit Team</Link>
          </Button>
        )}
      </div>
      
      <div className="grid gap-6 md:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>Team Details</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              <div>
                <h3 className="text-sm font-medium text-gray-500">Description</h3>
                <p className="mt-1">{team.description || "No description provided."}</p>
              </div>
              
              <div>
                <h3 className="text-sm font-medium text-gray-500">Created</h3>
                <p className="mt-1">
                  {new Date(team.created_at).toLocaleDateString()}
                </p>
              </div>
              
              <div>
                <h3 className="text-sm font-medium text-gray-500">Status</h3>
                <div className="mt-1">
                  <Badge variant={team.active ? "success" : "destructive"}>
                    {team.active ? "Active" : "Inactive"}
                  </Badge>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>
        
        <Card>
          <CardHeader>
            <CardTitle>Team Members</CardTitle>
            {canManageTeam(String(team.id)) && (
              <Button size="sm" variant="outline" asChild className="mt-2">
                <Link href={`/teams/${team.id}/members/invite`}>
                  Invite Members
                </Link>
              </Button>
            )}
          </CardHeader>
          <CardContent>
            {team.members && team.members.length > 0 ? (
              <div className="space-y-3">
                {team.members.map((member: any) => (
                  <div key={member.id} className="flex items-center justify-between">
                    <div className="flex items-center space-x-3">
                      <div className="w-8 h-8 rounded-full bg-gray-200 flex items-center justify-center">
                        {member.name ? member.name.charAt(0).toUpperCase() : "?"}
                      </div>
                      <div>
                        <p className="font-medium">{member.name || member.email}</p>
                        <p className="text-sm text-gray-500">{member.role}</p>
                      </div>
                    </div>
                    
                    {canManageTeam(String(team.id)) && (
                      <Button variant="ghost" size="sm">
                        Remove
                      </Button>
                    )}
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-gray-500">No members in this team yet.</p>
            )}
          </CardContent>
        </Card>
      </div>
      
      {/* Delete Team - Only visible to admins */}
      {isAdmin && (
        <div className="mt-8">
          <Card className="border-red-200">
            <CardHeader>
              <CardTitle className="text-red-600">Danger Zone</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="mb-4 text-gray-600">
                Deleting this team will remove all team data permanently.
                This action cannot be undone.
              </p>
              <Button variant="destructive">
                Delete Team
              </Button>
            </CardContent>
          </Card>
        </div>
      )}
    </div>
  );
  
  return (
    <Authenticated 
      key="team-show" 
      fallback={<div>Please login to view this page</div>}
    >
      {content}
    </Authenticated>
  );
} 