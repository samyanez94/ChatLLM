import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import { handleChatRequest } from "../_shared/chat_handler.ts";

export default {
  fetch: withSupabase(
    { auth: "publishable" },
    (request) => handleChatRequest(request),
  ),
};
