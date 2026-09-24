// The scan-receipt function's pure helpers. The function itself needs a
// Supabase project and a Gemini key; these need neither.
//
//   deno test supabase/functions/tests/
//
// What Gemini returns goes straight into the transaction form, so every
// normaliser here must answer null rather than guess: a blank field is fixed
// in seconds, a plausible wrong one is not noticed until the balance is off.

import { assertEquals } from "jsr:@std/assert@1";

import {
  normaliseAmount,
  normaliseDate,
  normaliseTime,
  readAtMost,
} from "../scan-receipt/normalise.ts";

// Pinned, so the "not in the future" bound does not move with the clock.
const NOW = new Date(Date.UTC(2026, 8, 24));

Deno.test("normaliseDate: day-first, padded, any common separator", () => {
  assertEquals(normaliseDate("05/09/2026", NOW), "05/09/2026");
  assertEquals(normaliseDate("5-9-2026", NOW), "05/09/2026");
  assertEquals(normaliseDate(" 25.10.25 ", NOW), "25/10/2025");
});

Deno.test("normaliseDate: rejects dates a receipt cannot have printed", () => {
  for (
    const raw of [
      "31/02/2026", // no such day
      "31/04/2026",
      "00/01/2026",
      "12/13/2026", // month-first
      "01/01/1999", // before MIN_YEAR
      "01/01/70", // two digits, read as 1970
      "01/01/2028", // more than a year ahead
      "2026-09-05", // ISO: the schema asks for DD/MM/YYYY
      "",
    ]
  ) {
    assertEquals(normaliseDate(raw, NOW), null, raw);
  }
  assertEquals(normaliseDate(null, NOW), null);
  assertEquals(normaliseDate(20260905, NOW), null);
});

Deno.test("normaliseDate: 29 February only in a leap year", () => {
  assertEquals(normaliseDate("29/02/2024", NOW), "29/02/2024");
  assertEquals(normaliseDate("29/02/2026", NOW), null);
});

Deno.test("normaliseTime: 24-hour with seconds, from either clock", () => {
  assertEquals(normaliseTime("19:16:30"), "19:16:30");
  assertEquals(normaliseTime("9:05"), "09:05:00");
  assertEquals(normaliseTime("7:35 PM"), "19:35:00");
  assertEquals(normaliseTime("12:30 am"), "00:30:00");
  assertEquals(normaliseTime("12:30 PM"), "12:30:00");
  assertEquals(normaliseTime("10:28AM"), "10:28:00");
});

Deno.test("normaliseTime: rejects impossible times and non-strings", () => {
  for (const raw of ["24:00", "10:60", "10:00:60", "noon", "10", ""]) {
    assertEquals(normaliseTime(raw), null, raw);
  }
  assertEquals(normaliseTime(null), null);
  assertEquals(normaliseTime(1930), null);
});

Deno.test("normaliseAmount: two decimals with the app's currency prefix", () => {
  assertEquals(normaliseAmount("45.2"), "RM 45.20");
  assertEquals(normaliseAmount(45.2), "RM 45.20");
  assertEquals(normaliseAmount("RM 1,234.50"), "RM 1234.50");
  assertEquals(normaliseAmount("68.44 MYR"), "RM 68.44");
});

// Both cases below are pinned the same way in receipt_rules_test.dart.
Deno.test("normaliseAmount: a debit's sign is dropped", () => {
  assertEquals(normaliseAmount("-10.60"), "RM 10.60");
  assertEquals(normaliseAmount("-RM10.60"), "RM 10.60");
  assertEquals(normaliseAmount(-10.6), "RM 10.60");
});

Deno.test("normaliseAmount: the last separator is the decimal mark", () => {
  assertEquals(normaliseAmount("1.234,56"), "RM 1234.56");
  assertEquals(normaliseAmount("12,50"), "RM 12.50");
  // Three digits after a lone comma: grouping, not a decimal mark.
  assertEquals(normaliseAmount("1,500"), "RM 1500.00");
});

Deno.test("normaliseAmount: nothing, zero and garbage are null", () => {
  for (const raw of [null, undefined, "", "0", "0.00", "-0.00", "RM", "n/a"]) {
    assertEquals(normaliseAmount(raw), null, String(raw));
  }
  // Two dots leave no decimal mark to trust; parseFloat alone reads 1.234.
  assertEquals(normaliseAmount("1.234.567"), null);
});

function streamOf(...chunks: number[]): ReadableStream<Uint8Array> {
  return new ReadableStream({
    start(controller) {
      for (const size of chunks) controller.enqueue(new Uint8Array(size).fill(7));
      controller.close();
    },
  });
}

Deno.test("readAtMost: joins the chunks of an upload under the limit", async () => {
  const got = await readAtMost(streamOf(3, 4, 3), 10);
  assertEquals(got?.byteLength, 10, "exactly the limit is allowed");
  assertEquals(got?.every((b) => b === 7), true);
});

Deno.test("readAtMost: gives up with null once the limit is passed", async () => {
  let cancelled = false;
  const body = new ReadableStream<Uint8Array>({
    pull(controller) {
      controller.enqueue(new Uint8Array(6));
    },
    cancel() {
      cancelled = true;
    },
  });
  // An endless upload: the read has to stop on its own.
  assertEquals(await readAtMost(body, 10), null);
  assertEquals(cancelled, true, "the rest of the upload is not read");
});

Deno.test("readAtMost: no body is an empty image, not an error", async () => {
  assertEquals((await readAtMost(null, 10))?.byteLength, 0);
});
