// The pure half of scan-receipt: bounding the upload and normalising what
// Gemini sends back. Kept apart from index.ts, which starts a server the moment
// it is imported, so these can be tested without one:
//
//   deno test supabase/functions/tests/

// --- reading the body ----------------------------------------------------------

/// Collects the request body, giving up -- with null -- the moment it passes
/// `limit`. Nothing beyond the first chunk over the line is ever buffered.
export async function readAtMost(
  body: ReadableStream<Uint8Array> | null,
  limit: number,
): Promise<Uint8Array | null> {
  if (body === null) return new Uint8Array(0);
  const chunks: Uint8Array[] = [];
  let total = 0;
  const reader = body.getReader();
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      total += value.byteLength;
      if (total > limit) {
        await reader.cancel();
        return null;
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const out = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    out.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return out;
}

// --- normalising -------------------------------------------------------------
//
// The schema asks for exact formats and temperature 0 makes them likely, but
// "likely" is not a guarantee, and a malformed date silently becomes today's
// date in the form. Everything below returns null rather than a guess: a blank
// field is corrected in seconds, a wrong one is not noticed.

const MIN_YEAR = 2000;

export function normaliseDate(
  raw: unknown,
  now: Date = new Date(),
): string | null {
  if (typeof raw !== "string") return null;
  const m = raw.trim().match(/^(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})$/);
  if (!m) return null;
  let [, d, mo, y] = m;
  let year = parseInt(y, 10);
  if (y.length === 2) year += year < 70 ? 2000 : 1900;
  const day = parseInt(d, 10);
  const month = parseInt(mo, 10);
  if (day < 1 || day > 31 || month < 1 || month > 12) return null;
  if (year < MIN_YEAR || year > now.getFullYear() + 1) return null;
  // Rejects 31/02 and friends, which a receipt cannot have printed.
  const probe = new Date(Date.UTC(year, month - 1, day));
  if (probe.getUTCDate() !== day || probe.getUTCMonth() !== month - 1) return null;
  return `${String(day).padStart(2, "0")}/${String(month).padStart(2, "0")}/${year}`;
}

export function normaliseTime(raw: unknown): string | null {
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

export function normaliseAmount(raw: unknown): string | null {
  if (raw == null) return null;
  // Strip any currency the model included despite being asked not to, and
  // thousands separators.
  const text = String(raw).replace(/[^\d.,-]/g, "").replace(/,/g, "");
  const value = parseFloat(text);
  if (!isFinite(value) || value <= 0) return null;
  // The app's own currency prefix, matching prefillFrom() on the device path.
  return `RM ${value.toFixed(2)}`;
}
