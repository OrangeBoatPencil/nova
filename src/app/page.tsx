import { redirect } from 'next/navigation';
import { createServerSupabaseClient } from '@/utils/supabase/server';
import { AppLayout } from "@/components/layout/app-layout";
import { DashboardPage } from "@/components/dashboard/dashboard-page";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { MembersList } from "@/components/members/members-list";

export default async function HomePage() {
  // Check if user is logged in
  const supabase = await createServerSupabaseClient();
  const { data: { user } } = await supabase.auth.getUser();

  // Redirect to dashboard if logged in, otherwise to login page
  if (user) {
    redirect('/dashboard');
  } else {
    redirect('/login');
  }

  // This won't be reached due to redirects, but needed for TypeScript
  return null;
}
