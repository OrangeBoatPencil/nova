'use client';

import { Authenticated } from "@refinedev/core";
import { AccountForm } from "@/components/auth/account-form";

export default function AccountPage() {
  const content = (
    <div className="flex flex-col items-center justify-center min-h-screen py-12 px-4">
      <div className="w-full max-w-md">
        <AccountForm />
      </div>
    </div>
  );

  return (
    <Authenticated 
      fallback={<div>Redirecting to login...</div>}
      key="account"
    >
      {content}
    </Authenticated>
  );
} 