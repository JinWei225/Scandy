// Reading a receipt when the device cannot.
//
// The phone does this itself with ML Kit -- free, offline, and usually under a
// second. This is the fallback: the web build, which has no ML Kit at all, and
// a phone scan that came back missing a field.
//
// It exists as a server-side function for one reason: the Gemini API key. A key
// shipped inside the app is readable by anyone who opens the web bundle or
// decompiles the APK, and it bills to the person who shipped it. So the key
// lives here as a function secret, the caller proves who they are with their
// Supabase JWT, and the number of scans per person is capped.
//
// Deploy:
//   supabase secrets set GEMINI_API_KEY=...
//   supabase functions deploy scan-receipt
//
// The request body is the raw image bytes -- not base64, not multipart. The
// client posts Uint8List and this encodes once, here, for Gemini.

import { createClient } from "jsr:@supabase/supabase-js@2";

import {
  normaliseAmount,
  normaliseDate,
  normaliseTime,
  readAtMost,
} from "./normalise.ts";

// One constant, so changing model is a one-line edit -- which it already had
// to be: 2.5-flash-lite answered 404 with "no longer available to new users,
// use models/gemini-3.5-flash-lite". Flash-Lite is the cheapest vision-capable
// tier and reads a receipt perfectly well; the job is finding three fields on
// a page, not reasoning.
const MODEL = "gemini-3.5-flash-lite";

// Per user, over a rolling 24 hours rather than a calendar day, which avoids
// the question of whose midnight. Generous enough that a day of shopping never
// hits it, low enough to bound a runaway loop.
const SCANS_PER_DAY = 30;

// Gemini takes images up to 20 MB inline, but a phone photo that large says the
// client forgot to downscale. The app's own upload limit was 10 MB.
const MAX_BYTES = 10 * 1024 * 1024;

const CORS = {
  "Access-Control-Allow-Origin": "*",
  // x-image-mime is ours and must be listed, or the browser's preflight fails
  // and the web build can never call this at all.
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-image-mime",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });

// What we ask Gemini for. Structured output rather than prose, so there is no
// parsing of "The total appears to be RM 45.20" and no chance of a preamble.
const SCHEMA = {
  type: "OBJECT",
  properties: {
    date: {
      type: "STRING",
      nullable: true,
      description:
        "The transaction date printed on the receipt, formatted DD/MM/YYYY. " +
        "Null if no date is visible. Day-first: Malaysian receipts are DD/MM.",
    },
    time: {
      type: "STRING",
      nullable: true,
      description:
        "The transaction time, 24-hour, formatted HH:MM:SS. Null if absent. " +
        "Not the time the receipt was printed or reprinted, if they differ.",
    },
    amount: {
      type: "STRING",
      nullable: true,
      description:
        "The final total actually paid, as a plain decimal with two places " +
        "and no currency symbol, e.g. 45.20. Not the subtotal, not the cash " +
        "tendered, not the change, not any single line item. Null if unsure.",
    },
  },
  required: ["date", "time", "amount"],
} as const;

const PROMPT = [
  "This is a photograph or screenshot of a receipt, bill, or payment",
  "confirmation, most likely Malaysian.",
  "",
  "Report the transaction date, the transaction time, and the final total paid.",
  "",
  "Read only what is printed. If a field is not legible or not present, return",
  "null for it rather than inferring or calculating one. A missing field is",
  "corrected by the person in two seconds; a confidently wrong total is not",
  "noticed until the balance is off.",
  "",
  "Where a payment app shows both a status-bar clock and a transaction time,",
  "the transaction time is the one on the receipt body.",
].join("\n");

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "Use POST." }, 405);

  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) {
    console.error("GEMINI_API_KEY is not set on this project");
    return json({ error: "Scanning is not configured on the server." }, 503);
  }

  // --- who is asking ---------------------------------------------------------
  const authHeader = req.headers.get("Authorization") ?? "";
  const asUser = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: { user }, error: authError } = await asUser.auth.getUser();
  if (authError || !user) {
    return json({ error: "Sign in to scan a receipt." }, 401);
  }

  // --- how many have they had ------------------------------------------------
  // Service role, so the count cannot be reset by the person being counted.
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Claim a slot first, then count -- never the other way round. Counting and
  // logging as two separate steps let every request that arrived together see
  // the same "29 so far" and all go through to Gemini. With the row written
  // first, each request's count includes every other request in flight, so
  // the cap holds. Simultaneous requests at the limit may all be turned away
  // rather than exactly one admitted; erring that way is what a cap is for.
  const { data: slot, error: slotError } = await admin
    .from("receipt_scans")
    .insert({ user_id: user.id })
    .select("id")
    .single();
  if (slotError || !slot) {
    console.error("could not reserve a scan", slotError);
    return json({ error: "Could not scan just now. Try again." }, 500);
  }

  // Gives the slot back, for the requests that end before Gemini is asked and
  // so cost nothing. Once the call has gone out the slot is kept whatever the
  // outcome: a failed read is still a metered call, and not counting those let
  // one bad photo be retried against the bill without limit.
  const release = async () => {
    const { error } = await admin.from("receipt_scans").delete().eq("id", slot.id);
    if (error) console.error("could not release scan slot", error);
  };

  const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  const { count, error: countError } = await admin
    .from("receipt_scans")
    .select("id", { count: "exact", head: true })
    .eq("user_id", user.id)
    .gte("created_at", since);

  if (countError) {
    console.error("rate-limit check failed", countError);
    await release();
    return json({ error: "Could not scan just now. Try again." }, 500);
  }
  // `>` rather than `>=`: the count includes the slot just claimed.
  if ((count ?? 0) > SCANS_PER_DAY) {
    await release();
    return json({
      error:
        `That is ${SCANS_PER_DAY} scans today, which is the limit. You can ` +
        `still add the transaction by hand, and scanning works again tomorrow.`,
    }, 429);
  }

  // --- the image -------------------------------------------------------------
  // Checked before the body is read, not after: arrayBuffer() would happily
  // hold a 150 MB upload in memory on the way to a 413, and the isolate has
  // less than that. The header is the cheap check; the bounded read below is
  // the one that holds when the header is missing or lying.
  const declared = Number(req.headers.get("content-length") ?? "0");
  if (declared > MAX_BYTES) {
    await release();
    return json({ error: "That image is too large to scan." }, 413);
  }
  let bytes: Uint8Array | null;
  try {
    bytes = await readAtMost(req.body, MAX_BYTES);
  } catch (e) {
    // A dropped upload, which would otherwise keep the slot it never used.
    console.error("could not read the upload", e);
    await release();
    return json({ error: "The image did not arrive. Try again." }, 400);
  }
  if (bytes === null) {
    await release();
    return json({ error: "That image is too large to scan." }, 413);
  }
  if (bytes.byteLength === 0) {
    await release();
    return json({ error: "No image was sent." }, 400);
  }
  const mime = req.headers.get("x-image-mime") ?? "image/jpeg";

  // btoa on a 10 MB string blows the stack if done in one call, so chunk it.
  let binary = "";
  for (let i = 0; i < bytes.length; i += 0x8000) {
    binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  }
  const base64 = btoa(binary);

  // --- ask Gemini ------------------------------------------------------------
  let modelText: string;
  try {
    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": apiKey,
        },
        body: JSON.stringify({
          contents: [{
            parts: [
              { text: PROMPT },
              { inline_data: { mime_type: mime, data: base64 } },
            ],
          }],
          generationConfig: {
            responseMimeType: "application/json",
            responseSchema: SCHEMA,
            // Reading printed characters is not a task that benefits from
            // variety.
            temperature: 0,
          },
        }),
        // Measured on the free tier: the same four receipts came back in
        // 3.2s, 36.1s, 4.5s and 8.9s. The slow one is not an outlier to
        // design around, it is the tier. The client waits longer than this,
        // so the timeout that fires is this one, with a message.
        signal: AbortSignal.timeout(75_000),
      },
    );

    if (!res.ok) {
      const detail = await res.text();
      console.error(`gemini ${res.status}: ${detail.slice(0, 500)}`);

      // Worth separating, because on the free tier this is the failure people
      // will actually meet, and "could not read that" sends them to retake a
      // photo that was never the problem.
      if (res.status === 429) {
        return json({
          error: "The scanner has hit its quota for now. Add the amount by " +
            "hand, or try again later.",
        }, 429);
      }

      // Otherwise the upstream status is deliberately not passed through: a
      // 400 from Google is not a 400 from this endpoint's caller.
      return json({ error: "The scanner could not read that just now." }, 502);
    }

    const payload = await res.json();
    const text = payload?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (typeof text !== "string") {
      // A safety block or an empty candidate lands here.
      console.error("gemini returned no text", JSON.stringify(payload).slice(0, 500));
      return json({ error: "Could not read anything from that image." }, 422);
    }
    modelText = text;
  } catch (e) {
    console.error("gemini call failed", e);
    return json({ error: "The scanner timed out. Try again." }, 504);
  }

  // Outside the try above: a reply that is not JSON is not a timeout, and
  // telling somebody to "try again" sends them into metered retries of a
  // photo that will fail the same way every time.
  let extracted: Record<string, unknown>;
  try {
    extracted = JSON.parse(modelText);
  } catch {
    console.error("gemini reply was not JSON", modelText.slice(0, 500));
    return json({ error: "Could not read anything from that image." }, 422);
  }

  // --- answer ----------------------------------------------------------------
  // Already counted: the slot claimed above stands for this scan.
  return json({
    date: normaliseDate(extracted.date),
    time: normaliseTime(extracted.time),
    amount: normaliseAmount(extracted.amount),
  });
});
