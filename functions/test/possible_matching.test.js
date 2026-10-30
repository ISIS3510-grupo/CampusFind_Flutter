"use strict";

const { test } = require("node:test");
const assert = require("node:assert/strict");
const { createMatchingHandlers } = require("../possible_matching");

const timestamp = { toDate: () => new Date("2026-09-01T12:00:00Z") };
const lost = (fields = {}) => ({ ownerUid: "student-1", category: "electronics",
  title: "Scientific calculator", description: "", locationName: "ML",
  status: "reported", reportedAt: timestamp, ...fields });
const found = (fields = {}) => ({ category: "electronics", title: "Casio scientific calculator",
  publicDescription: "", locationName: "ML", status: "available", createdAt: timestamp, ...fields });
const snapshot = (id, data) => ({ id, data: () => data });

// SDK-shaped double enforces filters and atomic create, and records attempted
// reads/writes. Tests use the real scorer and the same handlers as the exports.
class Database {
  constructor(documents = {}) {
    this.documents = new Map(Object.entries(documents));
    this.queries = [];
    this.reads = [];
    this.creates = [];
    this.failPath = null;
    this.configError = false;
  }
  doc(path) {
    return {
      get: async () => {
        this.reads.push(path);
        if (this.configError) throw Object.assign(new Error("unavailable"), { code: 14 });
        return snapshot(path, this.documents.get(path));
      },
      create: async (data) => {
        this.creates.push(path);
        if (this.failPath === path) throw Object.assign(new Error("unavailable"), { code: 14 });
        if (this.documents.has(path)) throw Object.assign(new Error("exists"), { code: 6 });
        this.documents.set(path, data);
      },
    };
  }
  collection(name) {
    const filters = [];
    const query = {
      doc: (id) => this.doc(`${name}/${id}`),
      where: (field, operator, value) => {
        assert.equal(operator, "==");
        filters.push([field, value]);
        return query;
      },
      get: async () => {
        this.queries.push({ name, filters: [...filters] });
        return { docs: [...this.documents.entries()]
          .filter(([path, data]) => path.startsWith(`${name}/`)
            && filters.every(([field, value]) => data[field] === value))
          .map(([path, data]) => snapshot(path.split("/")[1], data)) };
      },
    };
    return query;
  }
}

function setup(documents) {
  const db = new Database(documents);
  const sentinel = { serverTimestamp: true };
  const warnings = [];
  const handlers = createMatchingHandlers({ db, serverTimestamp: () => sentinel,
    logger: { warn: (...args) => warnings.push(args) } });
  return { db, sentinel, warnings, ...handlers };
}

for (const direction of ["lost", "found"]) {
  test(`new ${direction} matches only opposite active same-category candidates`, async () => {
    const documents = {
      "lostReports/lost-1": lost(), "foundItems/found-1": found(),
      "lostReports/closed": lost({ status: "closed" }),
      "lostReports/claimed": lost({ status: "claimed" }),
      "foundItems/claimed": found({ status: "claimed" }),
      "foundItems/donated": found({ status: "donated" }),
      "lostReports/other": lost({ category: "clothing" }),
      "foundItems/other": found({ category: "clothing" }),
      [direction === "lost" ? "lostReports/unrelated" : "foundItems/unrelated"]:
        direction === "lost" ? lost() : found(),
    };
    // Would fail if a filtered candidate ever reaches expensive scoring.
    for (const path of ["lostReports/other", "foundItems/other"]) {
      Object.defineProperty(documents[path], "title", { get() { assert.fail("scored other category"); } });
    }
    const { db, sentinel, onLostReportCreated, onFoundItemCreated } = setup(documents);
    const source = direction === "lost" ? "lostReports/lost-1" : "foundItems/found-1";
    await (direction === "lost" ? onLostReportCreated : onFoundItemCreated)(
      { data: snapshot(source.split("/")[1], documents[source]) });
    assert.deepEqual(db.queries, [{
      name: direction === "lost" ? "foundItems" : "lostReports",
      filters: [["status", direction === "lost" ? "available" : "reported"], ["category", "electronics"]],
    }]);
    assert.deepEqual(db.reads, ["appConfig/general"]);
    assert.deepEqual(db.creates, ["matches/lost-1_found-1"]);
    const match = db.documents.get("matches/lost-1_found-1");
    assert.ok(Math.abs(match.score - 0.95) < 1e-12);
    assert.deepEqual(match, { reportId: "lost-1", foundItemId: "found-1", ownerUid: "student-1",
      score: match.score, strategyName: "basic_weighted", strategyVersion: 1, createdAt: sentinel });
    for (const [path, original] of Object.entries(documents)) assert.equal(db.documents.get(path), original);
  });
}

test("below-threshold candidate creates no match", async () => {
  const { db, onLostReportCreated } = setup({ "foundItems/weak": found({
    locationName: "W", createdAt: { toDate: () => new Date("2026-10-01") },
  }) });
  await onLostReportCreated({ data: snapshot("lost-1", lost()) });
  assert.deepEqual(db.creates, []);
});

test("repeated and simultaneous opposite triggers preserve one original match", async () => {
  const report = lost();
  const item = found();
  const { db, onLostReportCreated, onFoundItemCreated } = setup({
    "lostReports/lost-1": report, "foundItems/found-1": item,
  });
  const lostEvent = { data: snapshot("lost-1", report) };
  const foundEvent = { data: snapshot("found-1", item) };
  await Promise.all([onLostReportCreated(lostEvent), onFoundItemCreated(foundEvent)]);
  const first = db.documents.get("matches/lost-1_found-1");
  await onLostReportCreated(lostEvent);
  await onFoundItemCreated(foundEvent);
  assert.equal(db.documents.get("matches/lost-1_found-1"), first);
  assert.equal([...db.documents.keys()].filter((p) => p.startsWith("matches/")).length, 1);
});

test("partial failure propagates for retry without overwriting earlier matches", async () => {
  const { db, onLostReportCreated } = setup({ "foundItems/a": found(), "foundItems/b": found() });
  db.failPath = "matches/lost-1_b";
  const event = { data: snapshot("lost-1", lost()) };
  await assert.rejects(onLostReportCreated(event), { code: 14 });
  const first = db.documents.get("matches/lost-1_a");
  db.failPath = null;
  await onLostReportCreated(event);
  assert.equal(db.documents.get("matches/lost-1_a"), first);
  assert.ok(db.documents.has("matches/lost-1_b"));
});

test("threshold is read from appConfig/general for both directions", async () => {
  const { db, onLostReportCreated, onFoundItemCreated } = setup({
    "appConfig/general": { matchingThreshold: 0.96 },
    "lostReports/lost-1": lost(), "foundItems/found-1": found(),
  });
  await onLostReportCreated({ data: snapshot("lost-1", lost()) });
  await onFoundItemCreated({ data: snapshot("found-1", found()) });
  assert.deepEqual(db.creates, []);
  db.documents.set("appConfig/general", { matchingThreshold: 0.95 });
  await onFoundItemCreated({ data: snapshot("found-1", found()) });
  assert.deepEqual(db.creates, ["matches/lost-1_found-1"]);
});

test("missing/invalid/unavailable threshold falls back to 0.70", async () => {
  for (const value of [undefined, null, "0.9", NaN, Infinity, -0.1, 1.1]) {
    const { db, warnings, onLostReportCreated } = setup({
      "appConfig/general": { matchingThreshold: value }, "foundItems/found-1": found(),
      "foundItems/weak": found({ locationName: "W", title: "keys",
        createdAt: { toDate: () => new Date("2026-10-01") } }),
    });
    await onLostReportCreated({ data: snapshot("lost-1", lost()) });
    assert.equal(db.creates.length, 1);
    db.configError = true;
    await onLostReportCreated({ data: snapshot("lost-2", lost()) });
    assert.equal(db.creates.length, 2);
    assert.equal(warnings.length, 1);
  }
});

test("threshold endpoints 0 and 1 are valid; category remains a query constraint", async () => {
  for (const threshold of [0, 1]) {
    const { db, onLostReportCreated } = setup({
      "appConfig/general": { matchingThreshold: threshold },
      "foundItems/same": found(), "foundItems/other": found({ category: "clothing" }),
    });
    await onLostReportCreated({ data: snapshot("lost-1", lost()) });
    assert.equal(db.creates.length, threshold === 0 ? 1 : 0);
  }
});

test("inactive sources, missing events, and invalid owners cannot create matches", async () => {
  const { db, onLostReportCreated, onFoundItemCreated } = setup({ "foundItems/found-1": found() });
  await onLostReportCreated({});
  await onFoundItemCreated({});
  await onLostReportCreated({ data: snapshot("lost-1", lost({ status: "closed" })) });
  await onFoundItemCreated({ data: snapshot("found-1", found({ status: "claimed" })) });
  assert.deepEqual(db.queries, []);
  await onLostReportCreated({ data: snapshot("lost-1", lost({ ownerUid: "" })) });
  assert.deepEqual(db.creates, []);
});
