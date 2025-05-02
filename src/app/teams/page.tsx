"use client";

import React from "react";
import { useTable } from "@refinedev/core";
import { Authenticated } from "@refinedev/core";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { usePermission } from "@/hooks/usePermission";
import Link from "next/link";

export default function TeamsList() {
  const { checkPermission } = usePermission();
  const canCreateTeam = checkPermission("teams", "create");
  
  const { tableQueryResult } = useTable({
    resource: "teams",
    pagination: {
      mode: 'server',
      current: 1,
      pageSize: 10,
    },
  });
  
  const { data, isLoading } = tableQueryResult;
  const teams = data?.data || [];
  
  const content = (
    <div className="p-6">
      <div className="flex justify-between items-center mb-6">
        <h2 className="text-3xl font-bold">Teams</h2>
        
        {canCreateTeam && (
          <Button asChild>
            <Link href="/teams/create">Create Team</Link>
          </Button>
        )}
      </div>
      
      <Card>
        <CardHeader>
          <CardTitle>All Teams</CardTitle>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <div className="text-center py-4">Loading...</div>
          ) : teams.length === 0 ? (
            <div className="text-center py-4 text-gray-500">
              No teams found. Create your first team to get started.
            </div>
          ) : (
            <div className="space-y-4">
              {teams.map((team: any) => (
                <div 
                  key={team.id}
                  className="border rounded-lg p-4 flex justify-between items-center hover:bg-gray-50 transition-colors"
                >
                  <div>
                    <Link 
                      href={`/teams/${team.id}`}
                      className="text-lg font-medium hover:underline"
                    >
                      {team.name}
                    </Link>
                    <p className="text-sm text-gray-500 mt-1">
                      {team.description || "No description provided."}
                    </p>
                    <div className="mt-2">
                      <Badge variant={team.active ? "success" : "destructive"}>
                        {team.active ? "Active" : "Inactive"}
                      </Badge>
                      {team.members && (
                        <span className="text-sm text-gray-500 ml-2">
                          {team.members.length} {team.members.length === 1 ? "member" : "members"}
                        </span>
                      )}
                    </div>
                  </div>
                  
                  <div className="flex items-center space-x-2">
                    {checkPermission("teams", "edit", String(team.id)) && (
                      <Button variant="outline" size="sm" asChild>
                        <Link href={`/teams/${team.id}/edit`}>
                          Edit
                        </Link>
                      </Button>
                    )}
                    <Button variant="outline" size="sm" asChild>
                      <Link href={`/teams/${team.id}`}>
                        View
                      </Link>
                    </Button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
  
  return (
    <Authenticated 
      key="teams-list" 
      fallback={<div>Please login to view this page</div>}
    >
      {content}
    </Authenticated>
  );
} 