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

// One constant, so changing model is a one-line edit. Flash-Lite is the
// cheapest vision-capable tier and reads a receipt perfectly well; the job is
// finding three fields on a page, not reasoning.
const MODEL = "gemini-2.5-flash-lite";

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
  const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  const { count, error: countError } = await admin
    .from("receipt_scans")
    .select("id", { count: "exact", head: true })
    .eq("user_id", user.id)
    .gte("created_at", since);

  if (countError) {
    console.error("rate-limit check failed", countError);
    return json({ error: "Could not scan just now. Try again." }, 500);
  }
  if ((count ?? 0) >= SCANS_PER_DAY) {
    return json({
      error:
        `That is ${SCANS_PER_DAY} scans today, which is the limit. You can ` +
        `still add the transaction by hand, and scanning works again tomorrow.`,
    }, 429);
  }

  // --- the image -------------------------------------------------------------
  const bytes = new Uint8Array(await req.arrayBuffer());
  if (bytes.byteLength === 0) return json({ error: "No image was sent." }, 400);
  if (bytes.byteLength > MAX_BYTES) {
    return json({ error: "That image is too large to scan." }, 413);
  }
  const mime = req.headers.get("x-image-mime") ?? "image/jpeg";

  // btoa on a 10 MB string blows the stack if done in one call, so chunk it.
  let binary = "";
  for (let i = 0; i < bytes.length; i += 0x8000) {
    binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  }
  const base64 = btoa(binary);

  // --- ask Gemini ------------------------------------------------------------
  let extracted: Record<string, unknown>;
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
        signal: AbortSignal.timeout(45_000),
      },
    );

    if (!res.ok) {
      const detail = await res.text();
      console.error(`gemini ${res.status}: ${detail.slice(0, 500)}`);
      // The upstream status is deliberately not passed through: a 400 from
      // Google is not a 400 from this endpoint's caller.
      return json({ error: "The scanner could not read that just now." }, 502);
    }

    const payload = await res.json();
    const text = payload?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (typeof text !== "string") {
      // A safety block or an empty candidate lands here.
      console.error("gemini returned no text", JSON.stringify(payload).slice(0, 500));
      return json({ error: "Could not read anything from that image." }, 422);
    }
    extracted = JSON.parse(text);
  } catch (e) {
    console.error("gemini call failed", e);
    return json({ error: "The scanner timed out. Try again." }, 504);
  }

  // --- record and answer -----------------------------------------------------
  // After the call, so a failed scan is not charged against the cap.
  const { error: logError } = await admin
    .from("receipt_scans")
    .insert({ user_id: user.id });
  if (logError) console.error("could not log scan", logError);

  return json({
    date: normaliseDate(extracted.date),
    time: normaliseTime(extracted.time),
    amount: normaliseAmount(extracted.amount),
  });
});

// --- normalising -------------------------------------------------------------
//
// The schema asks for exact formats and temperature 0 makes them likely, but
// "likely" is not a guarantee, and a malformed date silently becomes today's
// date in the form. Everything below returns null rather than a guess: a blank
// field is corrected in seconds, a wrong one is not noticed.

const MIN_YEAR = 2000;

function normaliseDate(raw: unknown): string | null {
  if (typeof raw !== "string") return null;
  const m = raw.trim().match(/^(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})$/);
  if (!m) return null;
  let [, d, mo, y] = m;
  let year = parseInt(y, 10);
  if (y.length === 2) year += year < 70 ? 2000 : 1900;
  const day = parseInt(d, 10);
  const month = parseInt(mo, 10);
  if (day < 1 || day > 31 || month < 1 || month > 12) return null;
  if (year < MIN_YEAR || year > new Date().getFullYear() + 1) return null;
  // Rejects 31/02 and friends, which a receipt cannot have printed.
  const probe = new Date(Date.UTC(year, month - 1, day));
  if (probe.getUTCDate() !== day || probe.getUTCMonth() !== month - 1) return null;
  return `${String(day).padStart(2, "0")}/${String(month).padStart(2, "0")}/${year}`;
}

function normaliseTime(raw: unknown): string | null {
  if (typeof raw !== "string") return null;
  const m = raw.trim().match(/^(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(am|pm)?$/i);
  if (!m) return null;
  let hour = parseInt(m[1], 10);
  const min = parseInt(m[2], 10);
  const sec = m[3] ? parseInt(m[3], 10) : 0;
  const suffix = m[4]?.toLowerCase();
  if (suffix === "pm" && hour < 12) hour += 12;
  if (suffix === "am" && hour === 12) hour = 0;
  if (hour > 23 || min > 59 || sec > 59) return null;
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${pad(hour)}:${pad(min)}:${pad(sec)}`;
}

function normaliseAmount(raw: unknown): string | null {
  if (raw == null) return null;
  // Strip any currency the model included despite being asked not to, and
  // thousands separators.
  const text = String(raw).replace(/[^\d.,-]/g, "").replace(/,/g, "");
  const value = parseFloat(text);
  if (!isFinite(value) || value <= 0) return null;
  // The app's own currency prefix, matching prefillFrom() on the device path.
  return `RM ${value.toFixed(2)}`;
}
