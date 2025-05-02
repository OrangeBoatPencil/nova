import { dataProvider } from "@refinedev/supabase";
import { createBrowserSupabaseClient } from "@/utils/supabase/client";

/**
 * Returns Refine's official Supabase `dataProvider` wired to a browser client.
 * All operator-mapping and meta handling are already built into the package,
 * so no additional helper code is necessary.
 */
export const supabaseProvider = () => {
  const supabase = createBrowserSupabaseClient();
  return dataProvider(supabase);
}; 