"use strict";

const DEFAULT_THRESHOLD = 0.70;
const STRATEGY_NAME = "basic_weighted";
const STRATEGY_VERSION = 1;

const normalize = (value) => typeof value === "string" ? value.toLowerCase().trim() : "";

function validCoordinates({ latitude, longitude }) {
  return Number.isFinite(latitude) && Number.isFinite(longitude)
    && latitude >= -90 && latitude <= 90
    && longitude >= -180 && longitude <= 180;
}

function locationScore(lost, found) {
  const name = normalize(lost.locationName);
  if (name && name === normalize(found.locationName)) return 1;
  if (!validCoordinates(lost) || !validCoordinates(found)) return 0;

  const radians = Math.PI / 180;
  const dLat = (found.latitude - lost.latitude) * radians;
  const dLon = (found.longitude - lost.longitude) * radians;
  const a = Math.sin(dLat / 2) ** 2
    + Math.cos(lost.latitude * radians) * Math.cos(found.latitude * radians)
    * Math.sin(dLon / 2) ** 2;
  const bounded = Math.max(0, Math.min(1, a));
  const distance = 6371000 * 2 * Math.atan2(Math.sqrt(bounded), Math.sqrt(1 - bounded));
  if (distance <= 100) return 1;
  if (distance <= 300) return 0.8;
  if (distance <= 700) return 0.5;
  if (distance <= 1500) return 0.2;
  return 0;
}

function dateScore(reportedAt, createdAt) {
  // Match Flutter's Timestamp.toDate() and absolute Duration.inDays (whole days).
  let lostDate;
  let foundDate;
  try {
    lostDate = typeof reportedAt?.toDate === "function" ? reportedAt.toDate() : null;
    foundDate = typeof createdAt?.toDate === "function" ? createdAt.toDate() : null;
  } catch (_) {
    return 0;
  }
  if (!(lostDate instanceof Date) || !(foundDate instanceof Date)) return 0;
  const days = Math.floor(Math.abs(lostDate.getTime() - foundDate.getTime()) / 86400000);
  if (days <= 1) return 1;
  if (days <= 3) return 0.75;
  if (days <= 7) return 0.40;
  return 0;
}

function words(text) {
  return new Set(text.toLowerCase().replace(/[^\p{L}\p{N}\s]/gu, " ")
    .split(/\s+/u).filter((word) => word.length >= 3));
}

function textScore(lost, found) {
  const left = words(`${lost.title ?? ""} ${lost.description ?? ""}`);
  const right = words(`${found.title ?? ""} ${found.publicDescription ?? ""}`);
  const union = new Set([...left, ...right]);
  if (!union.size) return 0;
  let intersection = 0;
  for (const word of left) if (right.has(word)) intersection++;
  return intersection / union.size;
}

// Preserve Flutter's summation order, including in optimistic upper bounds.
const weightedScore = (category, location, date, text) =>
  Math.max(0, Math.min(1, category * 0.40 + location * 0.25 + date * 0.20 + text * 0.15));

// null means the pair cannot meet the threshold; viable pairs retain the exact
// full score. Both triggers always pass (lost, found), in that order.
function scorePossibleMatch(lost, found, threshold = DEFAULT_THRESHOLD) {
  const category = normalize(lost.category) === normalize(found.category) ? 1 : 0;
  if (weightedScore(category, 1, 1, 1) < threshold) return null;
  const date = dateScore(lost.reportedAt, found.createdAt);
  if (weightedScore(category, 1, date, 1) < threshold) return null;
  const location = locationScore(lost, found);
  if (weightedScore(category, location, date, 1) < threshold) return null;
  const score = weightedScore(category, location, date, textScore(lost, found));
  return score >= threshold ? score : null;
}

module.exports = {
  DEFAULT_THRESHOLD, STRATEGY_NAME, STRATEGY_VERSION,
  scorePossibleMatch,
};
