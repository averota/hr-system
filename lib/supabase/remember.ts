import type { CookieOptions } from "@supabase/ssr";

// "Remember me" settings, shared by the server client, the proxy and the login action.
export const REMEMBER_COOKIE = "hris-remember-me";
export const REMEMBER_DAYS = 7;
export const REMEMBER_MAX_AGE = 60 * 60 * 24 * REMEMBER_DAYS; // in seconds

// Options for the small cookie that stores the user's "Remember me" choice.
export const rememberCookieOptions: CookieOptions = {
  path: "/",
  maxAge: REMEMBER_MAX_AGE,
  sameSite: "lax",
  httpOnly: true,
  secure: process.env.NODE_ENV === "production",
};

// Adjusts the options of a Supabase auth cookie before it is written:
// - remember = true  -> the cookie lasts REMEMBER_DAYS days
// - remember = false -> a session cookie (login ends when the browser is closed)
export function applyRememberMe(
  value: string,
  options: CookieOptions,
  remember: boolean
): CookieOptions {
  // Supabase is deleting this cookie (logout): leave it untouched.
  if (!value || options.maxAge === 0) return options;

  if (remember) return { ...options, maxAge: REMEMBER_MAX_AGE };

  const sessionOptions = { ...options };
  delete sessionOptions.maxAge;
  delete sessionOptions.expires;
  return sessionOptions;
}
