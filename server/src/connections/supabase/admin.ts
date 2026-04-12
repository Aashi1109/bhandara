import { createClient } from '@supabase/supabase-js';
import config from '@/config';

/**
 * Supabase admin client using the service role key.
 * Only use for privileged operations (e.g. password resets without user session).
 * Never expose this client to untrusted callers.
 */
const supabaseAdmin = createClient(config.supabase.url, config.supabaseServiceRole ?? '', {
  auth: {
    autoRefreshToken: false,
    persistSession: false,
  },
});

export default supabaseAdmin;
