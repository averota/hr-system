// lib/supabase/client.ts
// Supabase client for Client Components (runs in the browser).
import { createBrowserClient } from "@supabase/ssr";
import type { Database } from "./database.types";
import { supabaseUrl, supabasePublishableKey } from "./env";

export function createClient() {
  return createBrowserClient<Database>(supabaseUrl, supabasePublishableKey);
}