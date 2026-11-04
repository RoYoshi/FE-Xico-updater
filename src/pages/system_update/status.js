// SPDX-FileCopyrightText: 2026 RoYoshi
// SPDX-License-Identifier: GPL-2.0-or-later
.pragma library

// Dashboard state, derived only from facts the native backend has verified.
//
// facts = {
//     updateRunning, rollbackRunning,   // AppState operation flags
//     operation,                        // "status" | "check" | "upgrade" | "rollback"
//     outcome,                          // last verified outcome, "failed", or ""
//     lastCheckOutcome,                 // outcome of the last successful check/upgrade, or ""
//     host                              // last verified `bootc status --json`, or {}
// }
//
// Never reports "up-to-date" unless a check or upgrade actually returned
// that outcome and the host still shows nothing newer or pending.

function bootedEntry(host) {
    const status = host && host.status;
    return status && status.booted ? status.booted : null;
}

// True when the last `bootc upgrade --check` cached a different image digest.
function updateCached(booted) {
    if (!booted)
        return false;
    const cached = booted.cachedUpdate;
    const digest = booted.image && booted.image.imageDigest;
    return !!(cached && cached.imageDigest && digest && cached.imageDigest !== digest);
}

function dashboardState(facts) {
    if (facts.rollbackRunning)
        return "rolling-back";
    if (facts.updateRunning) {
        if (facts.operation === "check")
            return "checking";
        if (facts.operation === "upgrade")
            return "updating";
        return "reading";
    }
    if (facts.outcome === "failed")
        return "failed";
    const booted = bootedEntry(facts.host);
    if (!booted)
        return "unknown";
    const status = facts.host.status;
    if (status.rollbackQueued)
        return "rollback-staged";
    if (status.staged)
        return status.staged.downloadOnly ? "download-only" : "staged";
    if (updateCached(booted))
        return "update-available";
    if (facts.lastCheckOutcome === "up-to-date")
        return "up-to-date";
    return "unchecked";
}

// The one action the dashboard offers first in each state.
function primaryAction(state) {
    switch (state) {
    case "checking":
    case "updating":
    case "reading":
    case "rolling-back":
        return "progress";
    case "update-available":
        return "update";
    case "staged":
    case "rollback-staged":
        return "restart";
    case "failed":
        return "review-error";
    case "download-only":
        return "review-deployments";
    default: // unknown, unchecked, up-to-date
        return "check";
    }
}

// Visual tone: positive, active, attention, negative or neutral.
function tone(state) {
    switch (state) {
    case "up-to-date":
        return "positive";
    case "update-available":
    case "checking":
    case "updating":
    case "reading":
    case "rolling-back":
        return "active";
    case "staged":
    case "rollback-staged":
    case "download-only":
        return "attention";
    case "failed":
        return "negative";
    default:
        return "neutral";
    }
}

function isBusy(state) {
    return primaryAction(state) === "progress";
}
