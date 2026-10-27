"use strict";

const { test } = require("node:test");
const assert = require("node:assert/strict");
const functions = require("../index");

test("both real SDK exports target creation events with retries enabled", () => {
  assert.deepEqual(Object.keys(functions).sort(), ["onFoundItemCreated", "onLostReportCreated"]);
  for (const [name, document] of [
    ["onLostReportCreated", "lostReports/{reportId}"],
    ["onFoundItemCreated", "foundItems/{foundItemId}"],
  ]) {
    const endpoint = functions[name].__endpoint;
    assert.equal(endpoint.platform, "gcfv2");
    assert.equal(endpoint.eventTrigger.eventType, "google.cloud.firestore.document.v1.created");
    assert.equal(endpoint.eventTrigger.eventFilterPathPatterns.document, document);
    assert.equal(endpoint.eventTrigger.retry, true);
  }
});
