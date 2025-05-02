import { NextRequest, NextResponse } from "next/server";
import { createServerSupabaseClient } from "@/utils/supabase/server";

export async function POST(request: NextRequest) {
  try {
    const { email } = await request.json();
    
    // Create server-side Supabase client
    const supabase = await createServerSupabaseClient();

    // Send password reset email
    const { error } = await supabase.auth.resetPasswordForEmail(
      email,
      {
        redirectTo: `${request.nextUrl.origin}/reset-password`,
      }
    );

    if (error) {
      console.error("Forgot password error:", error);
      return NextResponse.json(
        { error: error.message },
        { status: 400 }
      );
    }

    return NextResponse.json(
      { message: "Password reset email sent successfully" },
      { status: 200 }
    );
  } catch (error: any) {
    console.error("Forgot password server error:", error);
    return NextResponse.json(
      { error: error.message || "An error occurred" },
      { status: 500 }
    );
  }
} 