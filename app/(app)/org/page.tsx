// app/(app)/org/page.tsx
import { Suspense } from "react";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { OrgConfigView } from "@/modules/org/components/OrgConfigView";
import { loadOrgPageData } from "@/modules/org/serverQueries";

async function OrgContent() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  // proxy.ts already blocks signed-out visitors; this is a safety net.
  if (!user) redirect("/login");

  const data = await loadOrgPageData();

  return <OrgConfigView userEmail={user.email ?? ""} {...data} />;
}

export default function OrgPage() {
  return (
    <Suspense
      fallback={<p className="p-8 text-sm text-zinc-500">Loading organization...</p>}
    >
      <OrgContent />
    </Suspense>
  );
}