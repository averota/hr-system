// lib/supabase/server.ts
// Supabase client for Server Components, Server Actions and Route Handlers.
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import { connection } from "next/server";
import type { Database } from "./database.types";
import { supabaseUrl, supabasePublishableKey } from "./env";

export async function createClient() {
  // With cacheComponents enabled in Next.js 16, mark execution as request-time
  // before createServerClient initializes GoTrueClient (which calls Date.now()).
  await connection();
  const cookieStore = await cookies();

  return createServerClient<Database>(supabaseUrl, supabasePublishableKey, {
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(cookiesToSet) {
        try {
          cookiesToSet.forEach(({ name, value, options }) =>
            cookieStore.set(name, value, options)
          );
        } catch {
          // Called from a Server Component, where cookies are read-only.
          // Safe to ignore: the session refresh is handled by proxy.ts.
        }
      },
    },
  });
}