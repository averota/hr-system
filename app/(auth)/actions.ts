// app/(auth)/actions.ts
"use server";

import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { DEFAULT_MODULE_PATH } from "@/lib/supabase/post-login";
import { REMEMBER_COOKIE, rememberCookieOptions } from "@/lib/supabase/remember";

export type LoginState = { error: string | null; email?: string; remember?: boolean };

const INVALID = "Invalid email or password.";

export async function login(
  _prevState: LoginState,
  formData: FormData
): Promise<LoginState> {
  const email = String(formData.get("email") ?? "").trim();
  const password = String(formData.get("password") ?? "");
  const remember = formData.get("remember-me") === "on";

  if (!email || !password) {
    return { error: "Please enter your email and password.", email, remember };
  }

  const supabase = await createClient({ remember });
  const { data, error } = await supabase.auth.signInWithPassword({ email, password });
  if (error || !data.user) return { error: INVALID, email, remember };

  // Store the choice so later session refreshes keep the same cookie lifetime.
  const cookieStore = await cookies();
  if (remember) {
    cookieStore.set(REMEMBER_COOKIE, "1", rememberCookieOptions);
  } else {
    cookieStore.delete(REMEMBER_COOKIE);
  }

  redirect(DEFAULT_MODULE_PATH);
}

// Not wired to a button yet. Use it for the sign-out button when that exists.
export async function logout() {
  const supabase = await createClient();
  await supabase.auth.signOut();

  (await cookies()).delete(REMEMBER_COOKIE);
  redirect("/login");
}
