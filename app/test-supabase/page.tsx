// TEMPORARY test page: delete app/test-supabase/ after the check passes.
import { Suspense } from "react";
import { createClient } from "../../lib/supabase/server";
import { supabaseUrl, supabasePublishableKey } from "../../lib/supabase/env";

// Request-time work (cookies, network) lives in its own component so it can
// sit inside <Suspense>, as required when cacheComponents is enabled.
async function ConnectionStatus() {
  const supabase = await createClient();
  const { data, error } = await supabase.auth.getUser();

  const health = await fetch(`${supabaseUrl}/auth/v1/health`, {
    headers: { apikey: supabasePublishableKey },
    cache: "no-store",
  });

  return (
    <>
      <p>Environment variables: OK</p>
      <p>Server client created: OK</p>
      <p>
        Supabase auth health: {health.status} {health.ok ? "OK" : "FAILED"}
      </p>
      <p>Current user: {data.user ? data.user.id : "none (expected, not logged in)"}</p>
      <p>getUser message: {error ? error.message : "none"}</p>
    </>
  );
}

export default function TestSupabasePage() {
  return (
    <main className="space-y-2 p-8 font-mono text-sm">
      <h1 className="text-lg font-bold">Supabase connection test (temporary)</h1>
      <Suspense fallback={<p>Checking connection...</p>}>
        <ConnectionStatus />
      </Suspense>
    </main>
  );
}