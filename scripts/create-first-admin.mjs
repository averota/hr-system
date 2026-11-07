// Creates the login of the first administrator of a tenant (PLT Stage 1, PLT-T012).
// Run on your own machine only. Never run it in the browser or on Vercel.
//
//   node --env-file=.env.local scripts/create-first-admin.mjs admin@example.com
//
// Needs in .env.local:
//   NEXT_PUBLIC_SUPABASE_URL
//   SUPABASE_SECRET_KEY        (server-only secret key, never a NEXT_PUBLIC_ name)
//
// It prints a temporary password ONCE. Then run the setup in the SQL editor:
//   select private.create_tenant_setup('Tenant name', 'Company name', 'admin@example.com');
//
// The forced password change at first sign-in is built in PLT Stage 4.

import { randomBytes } from 'node:crypto';
import { createClient } from '@supabase/supabase-js';

const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const secretKey = process.env.SUPABASE_SECRET_KEY;
const email = (process.argv[2] ?? '').trim().toLowerCase();

if (!url || !secretKey) {
  console.error('Missing NEXT_PUBLIC_SUPABASE_URL or SUPABASE_SECRET_KEY in .env.local');
  process.exit(1);
}
if (!email || !email.includes('@')) {
  console.error('Usage: node --env-file=.env.local scripts/create-first-admin.mjs <email>');
  process.exit(1);
}

// 18 random bytes -> 24 characters, letters and digits only
const password = randomBytes(18).toString('base64url').replace(/[-_]/g, 'x');

const supabase = createClient(url, secretKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});

const { data, error } = await supabase.auth.admin.createUser({
  email,
  password,
  email_confirm: true,
});

if (error) {
  console.error('Could not create the login:', error.message);
  process.exit(1);
}

console.log('Login created for', data.user.email);
console.log('Temporary password (shown once, copy it now):', password);
