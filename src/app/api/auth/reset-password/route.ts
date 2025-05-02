import { NextRequest, NextResponse } from "next/server";
import { createServerSupabaseClient } from "@/utils/supabase/server";

export async function POST(request: NextRequest) {
  try {
    const { password } = await request.json();
    
    // Create server-side Supabase client
    const supabase = await createServerSupabaseClient();

    // Update the user's password
    // The user session is already available via cookies
    const { data, error } = await supabase.auth.updateUser({
      password
    });

    if (error) {
      console.error("Password reset error:", error);
      return NextResponse.json(
        { error: error.message },
        { status: 400 }
      );
    }

    return NextResponse.json(
      { message: "Password updated successfully" },
      { status: 200 }
    );
  } catch (error: any) {
    console.error("Password reset server error:", error);
    return NextResponse.json(
      { error: error.message || "An error occurred" },
      { status: 500 }
    );
  }
} 