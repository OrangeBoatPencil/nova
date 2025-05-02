"use client";

import React, { useState } from "react";
import { useForgotPassword } from "@refinedev/core";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import * as z from "zod";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import Link from "next/link";
import { ArrowLeft } from "lucide-react";

// Define the form schema with validation
const formSchema = z.object({
  email: z.string().email({ message: "Please enter a valid email address" }),
});

type ForgotPasswordFormValues = z.infer<typeof formSchema>;

export default function ForgotPasswordPage() {
  // State to track if we're using the API directly instead of the Refine hook
  const [isUsingApi, setIsUsingApi] = useState(false);
  const [apiSuccess, setApiSuccess] = useState(false);
  const [apiError, setApiError] = useState<string | null>(null);
  const [isApiLoading, setIsApiLoading] = useState(false);

  // Use Refine's hook to handle the forgot password flow
  const { mutate: forgotPassword, isLoading: isRefineLoading, isSuccess: isRefineSuccess, error: refineError } = useForgotPassword<ForgotPasswordFormValues>();

  // Determine loading and success states based on whether we're using the API or Refine
  const isLoading = isUsingApi ? isApiLoading : isRefineLoading;
  const isSuccess = isUsingApi ? apiSuccess : isRefineSuccess;
  const error = isUsingApi ? apiError : refineError;

  // Initialize the form with react-hook-form
  const form = useForm<ForgotPasswordFormValues>({
    resolver: zodResolver(formSchema),
    defaultValues: {
      email: "",
    },
  });

  // Direct API call implementation
  const handleApiRequest = async (email: string) => {
    setIsApiLoading(true);
    setApiError(null);
    try {
      const response = await fetch('/api/auth/forgot-password', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email }),
      });

      const data = await response.json();
      
      if (!response.ok) {
        throw new Error(data.error || 'Failed to send reset email');
      }
      
      setApiSuccess(true);
    } catch (err: any) {
      setApiError(err.message || 'An error occurred');
    } finally {
      setIsApiLoading(false);
    }
  };

  // Handle form submission
  function onSubmit(data: ForgotPasswordFormValues) {
    if (isUsingApi) {
      handleApiRequest(data.email);
    } else {
      forgotPassword(data);
    }
  }

  return (
    <div className="flex items-center justify-center min-h-screen p-4 bg-gray-50">
      <Card className="w-full max-w-md">
        <CardHeader>
          <CardTitle className="text-2xl font-bold">Forgot Password</CardTitle>
          <CardDescription>
            Enter your email address and we'll send you a link to reset your password.
          </CardDescription>
        </CardHeader>
        <CardContent>
          {error && (
            <div className="mb-4 p-3 rounded-md bg-red-50 text-red-700 border border-red-200">
              {typeof error === 'object' && error !== null && 'message' in error
                ? String(error.message)
                : typeof error === 'string' ? error : 'An error occurred. Please try again.'}
            </div>
          )}

          {isSuccess ? (
            <div className="mb-4 p-3 rounded-md bg-green-50 text-green-700 border border-green-200">
              Check your email for a password reset link. If you don't see it, check your spam folder.
            </div>
          ) : (
            <Form {...form}>
              <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
                <FormField
                  control={form.control}
                  name="email"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Email</FormLabel>
                      <FormControl>
                        <Input 
                          placeholder="your.email@example.com" 
                          type="email" 
                          disabled={isLoading} 
                          {...field} 
                        />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                <Button 
                  type="submit" 
                  className="w-full" 
                  disabled={isLoading}
                >
                  {isLoading ? "Sending..." : "Send Reset Link"}
                </Button>
              </form>
            </Form>
          )}

          {/* Toggle option to use API directly (useful for debugging) */}
          <div className="mt-4 text-center">
            <button 
              onClick={() => setIsUsingApi(!isUsingApi)}
              className="text-xs text-gray-500 hover:text-gray-700"
              type="button"
            >
              {isUsingApi ? "Use Refine Provider" : "Use Direct API"}
            </button>
          </div>
        </CardContent>
        <CardFooter className="flex justify-center">
          <Button variant="ghost" asChild>
            <Link href="/login" className="flex items-center gap-1">
              <ArrowLeft className="h-4 w-4" /> Back to Login
            </Link>
          </Button>
        </CardFooter>
      </Card>
    </div>
  );
} 