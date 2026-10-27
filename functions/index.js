"use strict";

const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const { createMatchingHandlers } = require("./possible_matching");

initializeApp();
const handlers = createMatchingHandlers({
  db: getFirestore(),
  serverTimestamp: () => FieldValue.serverTimestamp(),
  logger,
});

exports.onLostReportCreated = onDocumentCreated(
  { document: "lostReports/{reportId}", retry: true },
  handlers.onLostReportCreated,
);

exports.onFoundItemCreated = onDocumentCreated(
  { document: "foundItems/{foundItemId}", retry: true },
  handlers.onFoundItemCreated,
);
