"use client";

import { useForm } from "@refinedev/react-hook-form";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Controller } from "react-hook-form";
import Avatar from "./avatar";
import { useEffect } from "react";

export function AccountForm() {
  const {
    refineCore: { onFinish, formLoading, queryResult },
    register,
    handleSubmit,
    control,
    formState: { errors },
    setValue,
  } = useForm({
    refineCoreProps: {
      resource: "profiles",
      action: "edit",
      redirect: false,
      id: undefined, // Will be set based on user session
    },
  });

  // Set ID when user data is available
  useEffect(() => {
    const fetchUser = async () => {
      try {
        // Get user ID from identity hook
        const session = queryResult?.data?.data;
        if (session?.id) {
          setValue("id", session.id);
        }
      } catch (error) {
        console.error("Error fetching user:", error);
      }
    };

    fetchUser();
  }, [queryResult?.data?.data, setValue]);

  const onSubmit = async (data: any) => {
    await onFinish(data);
  };

  return (
    <Card className="w-full max-w-md mx-auto">
      <CardHeader className="space-y-1">
        <CardTitle className="text-2xl font-bold">Your Profile</CardTitle>
        <CardDescription>View and edit your account details</CardDescription>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
          <Controller
            control={control}
            name="avatar_url"
            render={({ field }) => {
              return (
                <div className="flex justify-center mb-6">
                  <Avatar
                    url={field.value}
                    size={150}
                    onUpload={(filePath: string) => {
                      onFinish({
                        ...queryResult?.data?.data,
                        avatar_url: filePath,
                      });
                      field.onChange(filePath);
                    }}
                  />
                </div>
              );
            }}
          />
          
          <div className="space-y-2">
            <Label htmlFor="email">Email</Label>
            <Input
              id="email"
              type="text"
              disabled
              value={queryResult?.data?.data?.email || ""}
            />
            <p className="text-sm text-muted-foreground">
              Your email address cannot be changed
            </p>
          </div>
          
          <div className="space-y-2">
            <Label htmlFor="name">Full Name</Label>
            <Input
              id="name"
              type="text"
              {...register("name")}
              placeholder="Your name"
            />
            {errors?.name && (
              <p className="text-sm text-destructive">{errors.name.message?.toString()}</p>
            )}
          </div>
          
          <div className="space-y-2">
            <Label htmlFor="website">Website</Label>
            <Input
              id="website"
              type="url"
              {...register("website")}
              placeholder="https://example.com"
            />
            {errors?.website && (
              <p className="text-sm text-destructive">{errors.website.message?.toString()}</p>
            )}
          </div>
          
          <Button 
            type="submit" 
            className="w-full" 
            disabled={formLoading}
          >
            {formLoading ? "Saving..." : "Update Profile"}
          </Button>
        </form>
      </CardContent>
    </Card>
  );
} 