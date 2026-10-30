"use strict";

const {
  DEFAULT_THRESHOLD, STRATEGY_NAME, STRATEGY_VERSION, scorePossibleMatch,
} = require("./matching_score");

async function loadThreshold(db, logger) {
  try {
    const config = await db.doc("appConfig/general").get();
    const value = config.data()?.matchingThreshold;
    if (typeof value === "number" && Number.isFinite(value) && value >= 0 && value <= 1) {
      return value;
    }
  } catch (error) {
    logger.warn("Matching config unavailable; using default threshold", { code: error.code });
  }
  return DEFAULT_THRESHOLD;
}

function createMatchingHandlers({ db, serverTimestamp, logger = console }) {
  async function matchCreated(snapshot, isLost) {
    if (!snapshot) return;
    const source = snapshot.data();
    if (!source || source.status !== (isLost ? "reported" : "available")) return;
    if (typeof source.category !== "string" || !source.category.trim()) return;

    const threshold = await loadThreshold(db, logger);
    // Categories are shared canonical IDs. Firestore performs these filters,
    // so neither trigger loads all reports/items or recomputes all pairs.
    const candidates = await db.collection(isLost ? "foundItems" : "lostReports")
      .where("status", "==", isLost ? "available" : "reported")
      .where("category", "==", source.category)
      .get();

    for (const candidate of candidates.docs) {
      const lost = isLost ? source : candidate.data();
      const found = isLost ? candidate.data() : source;
      if (lost.status !== "reported" || found.status !== "available") continue;
      if (typeof lost.ownerUid !== "string" || !lost.ownerUid.trim()) continue;
      const score = scorePossibleMatch(lost, found, threshold);
      if (score === null) continue;
      const reportId = isLost ? snapshot.id : candidate.id;
      const foundItemId = isLost ? candidate.id : snapshot.id;
      try {
        // Atomic create prevents duplicate events or simultaneous opposite
        // triggers from overwriting the first match (including its timestamp).
        await db.collection("matches").doc(`${reportId}_${foundItemId}`).create({
          reportId,
          foundItemId,
          ownerUid: lost.ownerUid,
          score,
          strategyName: STRATEGY_NAME,
          strategyVersion: STRATEGY_VERSION,
          createdAt: serverTimestamp(),
        });
      } catch (error) {
        if (error.code !== 6 && error.code !== "already-exists") throw error;
      }
    }
  }

  return {
    onLostReportCreated: (event) => matchCreated(event.data, true),
    onFoundItemCreated: (event) => matchCreated(event.data, false),
  };
}

module.exports = { createMatchingHandlers };
