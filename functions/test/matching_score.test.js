"use strict";

const { test } = require("node:test");
const assert = require("node:assert/strict");
const { scorePossibleMatch } = require("../matching_score");

const timestamp = (days) => ({ toDate: () => new Date(days * 86400000) });
const lost = (fields = {}) => ({
  category: "electronics", title: "", description: "", locationName: "",
  reportedAt: timestamp(0), ...fields,
});
const found = (fields = {}) => ({
  category: "clothing", title: "", publicDescription: "", locationName: "",
  createdAt: timestamp(30), ...fields,
});
const close = (actual, expected) => assert.ok(Math.abs(actual - expected) < 1e-12,
  `${actual} differs from ${expected}`);

test("matches Flutter's scientific-calculator example (0.95)", () => {
  const report = lost({ title: "Scientific calculator", locationName: "ML" });
  const item = found({ category: "electronics", title: "Casio scientific calculator",
    locationName: "ML", createdAt: timestamp(0) });
  close(scorePossibleMatch(report, item), 0.95);
});

test("category uses lowercase/trim and retains its exact 0.40 contribution", () => {
  close(scorePossibleMatch(lost({ category: " Electronics " }),
    found({ category: "ELECTRONICS" }), 0), 0.4);
});

test("different category is rejected before dates, location or text are read", () => {
  const report = lost();
  for (const field of ["reportedAt", "locationName", "title", "description"]) {
    Object.defineProperty(report, field, { get() { assert.fail(`read ${field}`); } });
  }
  assert.equal(scorePossibleMatch(report, found()), null);
});

test("date bound stops before location/text; location bound stops before text", () => {
  const report = lost();
  Object.defineProperty(report, "locationName", { get() { assert.fail("read location"); } });
  assert.equal(scorePossibleMatch(report, found({ category: "electronics" }), 0.9), null);
  const noText = lost();
  Object.defineProperty(noText, "title", { get() { assert.fail("read text"); } });
  assert.equal(scorePossibleMatch(noText, found({ category: "electronics" })), null);
});

test("location name overrides coordinates; blanks do not count", () => {
  close(scorePossibleMatch(lost({ locationName: " ML ", latitude: 0, longitude: 0 }),
    found({ locationName: "ml", latitude: 30, longitude: 30 }), 0), 0.25);
  assert.equal(scorePossibleMatch(lost({ locationName: " " }), found(), 0), 0);
});

test("all Haversine distance bands match Flutter", () => {
  for (const [latitude, score] of [[0, 1], [0.00045, 1], [0.0018, 0.8],
    [0.0045, 0.5], [0.009, 0.2], [0.018, 0]]) {
    close(scorePossibleMatch(lost({ latitude: 0, longitude: 0 }),
      found({ latitude, longitude: 0 }), 0), score * 0.25);
  }
});

test("invalid/missing coordinates and antipodes remain finite", () => {
  for (const [latitude, longitude] of [[null, 0], [0, undefined], [91, 0], [-91, 0],
    [0, 181], [0, -181], [NaN, 0], [0, Infinity], ["0", 0]]) {
    assert.equal(scorePossibleMatch(lost({ latitude, longitude }),
      found({ latitude: 0, longitude: 0 }), 0), 0);
    assert.equal(scorePossibleMatch(lost({ latitude: 0, longitude: 0 }),
      found({ latitude, longitude }), 0), 0);
  }
  assert.equal(scorePossibleMatch(lost({ latitude: 90, longitude: 0 }),
    found({ latitude: -90, longitude: 180 }), 0), 0);
});

test("date bands are absolute whole days, including fractional-day boundaries", () => {
  for (const [days, score] of [[0, 1], [1, 1], [1.99, 1], [2, 0.75], [3.99, 0.75],
    [4, 0.4], [7.99, 0.4], [8, 0], [30, 0]]) {
    for (const sign of [-1, 1]) {
      close(scorePossibleMatch(lost(), found({ createdAt: timestamp(days * sign) }), 0), score * 0.2);
    }
  }
});

test("Unicode word-set Jaccard uses both descriptions and ignores short words", () => {
  close(scorePossibleMatch(lost({ title: "LÁPIZ, azul azul a!" }),
    found({ publicDescription: "lápiz azul de" }), 0), 0.15);
  close(scorePossibleMatch(lost({ title: "Casio", description: "calculator black" }),
    found({ title: "calculator", publicDescription: "black" }), 0), 0.1);
  assert.equal(scorePossibleMatch(lost({ title: "a an !" }), found({ title: "to of ?" }), 0), 0);
});

test("progressive bounds preserve full scores and inclusive threshold boundaries", () => {
  // Independently tabulated components exercise every date/location band and
  // text overlap. Also test the exact full score as a threshold (no false pruning).
  for (const [days, date] of [[0, 1], [2, 0.75], [4, 0.4], [8, 0]]) {
    for (const [latitude, location] of [[0, 1], [0.0018, 0.8], [0.0045, 0.5],
      [0.009, 0.2], [0.018, 0]]) {
      for (const [title, text] of [["calculator", 1], ["calculator black", 0.5], ["keys", 0]]) {
        const report = lost({ title: "calculator", latitude: 0, longitude: 0 });
        const item = found({ category: "electronics", title, latitude, longitude: 0,
          createdAt: timestamp(days) });
        const full = Math.min(1, 0.4 + location * 0.25 + date * 0.2 + text * 0.15);
        for (const threshold of [0, 0.6, 0.7, 0.9, 1, full, full + 1e-10]) {
          const score = scorePossibleMatch(report, item, threshold);
          if (full >= threshold) assert.equal(score, full);
          else assert.equal(score, null);
        }
      }
    }
  }
});

test("malformed timestamps contribute zero without throwing", () => {
  const invalid = [null, undefined, "date", 123, {}, { toDate: true },
    { toDate: () => "not a Date" }, { toDate: () => new Date(NaN) },
    { toDate: () => { throw new Error("invalid timestamp"); } }];
  for (const value of invalid) {
    close(scorePossibleMatch(lost({ reportedAt: value }),
      found({ category: "electronics", createdAt: timestamp(0) }), 0), 0.4);
    close(scorePossibleMatch(lost(),
      found({ category: "electronics", createdAt: value }), 0), 0.4);
  }
});
