// Single place that reads the Supabase environment variables.
// Fails early with a clear message if .env.local is missing or incomplete.

const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;

if (!url || !key) {
  throw new Error(
    "Missing NEXT_PUBLIC_SUPABASE_URL or NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY. " +
      "Check .env.local and restart `npm run dev`."
  );
}

export const supabaseUrl: string = url;
export const supabasePublishableKey: string = key;