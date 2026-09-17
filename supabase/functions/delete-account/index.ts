// // Follow this setup guide to integrate the Deno language server with your editor:
// // https://deno.land/manual/getting_started/setup_your_environment
// // This enables autocomplete, go to definition, etc.
//
// // Setup type definitions for built-in Supabase Runtime APIs
// import "@supabase/functions-js/edge-runtime.d.ts";
// import { withSupabase } from "@supabase/server";
//
// console.log("Hello from Functions!");
//
// // This endpoint uses 'publishable' | 'secret' access, apiKey is required.
// // Use publishable for Client-facing, key-validated endpoints
// // Use secret for Server-to-server, internal calls
// export default {
//   fetch: withSupabase({ auth: ["publishable", "secret"] }, async (req, ctx) => {
//     // Called by another service with a secret key
//     // ctx.supabaseAdmin bypasses RLS — use for privileged operations
//     /*
//     if (ctx.authMode === "secret") {
//       const { user_id } = await req.json();
//       const { data } = await ctx.supabaseAdmin.auth.admin.getUserById(user_id);
//
//       return Response.json({
//         email: data?.user?.email,
//       });
//     }
//     */
//
//     const { name } = await req.json();
//
//     return Response.json({
//       message: `Hello ${name}!`,
//     });
//   }),
// };
//
// /* To invoke locally:
//
//   1. Run `supabase start` (see: https://supabase.com/docs/reference/cli/supabase-start)
//   2. Make an HTTP request:
//
//   curl -i --location --request POST 'http://127.0.0.1:54321/functions/v1/delete-account' \
//     --header 'apiKey: sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH' \
//     --data '{"name":"Functions"}'
//
// */

import { createClient } from 'jsr:@supabase/supabase-js@2';

Deno.serve(async (req) => {
  try {
    // 1. Verify the request has a valid user JWT (the caller's own token)
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response('Missing auth header', { status: 401 });
    }

    // Client scoped to the CALLER — used only to verify who they are
    const userClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData.user) {
      return new Response('Invalid session', { status: 401 });
    }

    const userId = userData.user.id;

    // 2. Admin client — uses the service role key, ONLY available
    // inside Edge Functions, never shipped to the app
    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    // 3. Delete the user — cascades to profiles + tracked_routes
    const { error: deleteError } = await adminClient.auth.admin.deleteUser(userId);
    if (deleteError) {
      return new Response(deleteError.message, { status: 500 });
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    });
  } catch (err) {
    return new Response('Unexpected error', { status: 500 });
  }
});
