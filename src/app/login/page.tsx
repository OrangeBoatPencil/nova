import { LoginForm } from '@/components/auth/login-form'
import { createServerSupabaseClient } from '@/utils/supabase/server'
import { redirect } from 'next/navigation'

export default async function LoginPage() {
  // Check if user is already logged in
  const supabase = await createServerSupabaseClient()
  const { data: { user } } = await supabase.auth.getUser()

  // If user is logged in, redirect to home
  if (user) {
    redirect('/')
  }

  return (
    <div className="flex flex-col items-center justify-center min-h-screen py-2 px-4">
      <div className="w-full max-w-md">
        <LoginForm />
      </div>
    </div>
  )
} 