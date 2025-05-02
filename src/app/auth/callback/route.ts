import { createServerSupabaseClient } from '@/utils/supabase/server'
import { type EmailOtpType } from '@supabase/supabase-js'
import { NextRequest, NextResponse } from 'next/server'

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url)
  const token_hash = searchParams.get('token_hash')
  const type = searchParams.get('type') as EmailOtpType | null
  const code = searchParams.get('code')
  const next = searchParams.get('next') ?? '/dashboard'

  const supabase = await createServerSupabaseClient()

  // Handle email OTP verification (for email-based auth)
  if (token_hash && type) {
    const { error } = await supabase.auth.verifyOtp({
      type,
      token_hash,
    })

    if (!error) {
      return NextResponse.redirect(new URL(next, request.url))
    }
  }

  // Handle OAuth code exchange (for Google, GitHub, etc.)
  if (code) {
    const { error } = await supabase.auth.exchangeCodeForSession(code)
    
    if (!error) {
      return NextResponse.redirect(new URL(next, request.url))
    }
  }

  // Return to login page if there's an error or missing parameters
  return NextResponse.redirect(new URL('/login?error=auth-error', request.url))
} 