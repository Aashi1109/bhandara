import { createClient } from "@supabase/supabase-js";
import config from "@/config";
import { RequestContext } from "@/contexts";

const sessionIgnorePaths = ["/auth/.*"];

const supabase = createClient(config.supabase.url, config.supabase.key, {
  auth: {
    detectSessionInUrl: true,
    flowType: "pkce",
    persistSession: false,
    autoRefreshToken: false,
  },
  global: {
    fetch: (input: string, init: RequestInit) => {
      const pathname = new URL(input).pathname;
      const isSessionIgnorePath = sessionIgnorePaths.some((path) =>
        new RegExp(path).test(pathname)
      );

      if (isSessionIgnorePath) return fetch(input, init);

      const context = RequestContext.getContext();
      const session = context?.session;

      if (!session?.accessToken) return fetch(input, init);

      const defaultHeaders: Record<string, string> = {};
      // @ts-ignore
      for (let [key, value] of init.headers.entries()) {
        defaultHeaders[key] = value;
      }

      const opts = {
        ...init,
        headers: {
          ...defaultHeaders,
          authorization: `Bearer ${session.accessToken}`,
        },
      };

      return fetch(input, opts);
    },
  },
});

export default supabase;
