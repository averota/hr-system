// proxy.ts (project root)
// Refreshes the Supabase auth session on every request and protects routes.
import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";
import type { Database } from "@/lib/supabase/database.types";
import { supabaseUrl, supabasePublishableKey } from "@/lib/supabase/env";
import { DEFAULT_MODULE_PATH } from "@/lib/supabase/post-login";
import {
  applyRememberMe,
  REMEMBER_COOKIE,
  rememberCookieOptions,
} from "@/lib/supabase/remember";

export async function proxy(request: NextRequest) {
  let supabaseResponse = NextResponse.next({
    request,
  });
  const remember = request.cookies.has(REMEMBER_COOKIE);

  const supabase = createServerClient<Database>(
    supabaseUrl,
    supabasePublishableKey,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) =>
            request.cookies.set(name, value)
          );
          supabaseResponse = NextResponse.next({
            request,
          });
          cookiesToSet.forEach(({ name, value, options }) =>
            supabaseResponse.cookies.set(
              name,
              value,
              applyRememberMe(value, options, remember)
            )
          );
          // Keep the "remember me" window in step with the refreshed login.
          if (remember) {
            supabaseResponse.cookies.set(REMEMBER_COOKIE, "1", rememberCookieOptions);
          }
        },
      },
    }
  );

  // Refresh the auth token and validate the user session
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { pathname } = request.nextUrl;
  const isLoginRoute = pathname.startsWith("/login");
  // "/" is the public landing page.
  const isPublicRoute = pathname === "/" || isLoginRoute;

  if (!user && !isPublicRoute) {
    const loginUrl = request.nextUrl.clone();
    loginUrl.pathname = "/login";
    return NextResponse.redirect(loginUrl);
  }

  if (user && isLoginRoute) {
    const homeUrl = request.nextUrl.clone();
    homeUrl.pathname = DEFAULT_MODULE_PATH;
    return NextResponse.redirect(homeUrl);
  }

  return supabaseResponse;
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)",
  ],
};
