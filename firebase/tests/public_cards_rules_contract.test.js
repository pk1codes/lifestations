/**
 * Lightweight rules-source contract for public cards + unlockContact.
 * Full emulator suite can be added when @firebase/rules-unit-testing is installed.
 */
const fs = require("fs");
const path = require("path");
const assert = require("assert");

const root = path.resolve(__dirname, "..");
const rules = fs.readFileSync(path.join(root, "firestore.rules"), "utf8");
const functions = fs.readFileSync(path.join(root, "functions/index.js"), "utf8");

assert.ok(rules.includes("keys().hasOnly(["), "public cards must use hasOnly allowlist");
assert.ok(rules.includes("publicCardImmutable"), "immutable public card identity");
assert.ok(
  rules.includes("Legacy top-level path — read-only") ||
    rules.includes("allow create, update, delete: if false;"),
  "legacy top-level public_cards writes denied",
);
assert.ok(rules.includes("Contact vault — owner-only client reads"), "vault owner-only");
assert.ok(functions.includes("exports.unlockContact"), "unlockContact callable");
assert.ok(functions.includes("phone_number"), "unlock requires phone claim");
assert.ok(functions.includes("Mutual interest required"), "same-domain mutual check");
assert.ok(
  functions.includes("domainId") && functions.includes("targetUid"),
  "unlockContact requires domain-scoped target",
);
assert.ok(
  rules.includes("match /domains/{domainId}") &&
    rules.includes("match /public_cards/{slug}") &&
    rules.includes("validPublicCard()"),
  "domain-scoped public cards",
);
assert.ok(rules.includes("'headline'") && rules.includes("'locationLabel'"), "public card allowlist fields");
assert.ok(!/allow update: if true/.test(rules), "no open update allow");

const hosting = JSON.parse(
  fs.readFileSync(path.join(root, "firebase.json"), "utf8"),
);
const rewrites = hosting.hosting?.rewrites ?? [];
assert.ok(
  rewrites.some((rule) => rule.source === "**" && rule.destination === "/index.html"),
  "SPA rewrite must cover /c/{slug}",
);

console.log("public_cards_rules_contract OK");
