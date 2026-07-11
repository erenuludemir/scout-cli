import { existsSync, mkdirSync, readFileSync, writeFileSync, cpSync, rmSync } from "node:fs";
import { join } from "node:path";
import { $ } from "bun";

const ROOT = "/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3";
const IOS_DIR = join(ROOT, "ios", "QuantumAIMobile");
const APP_DIR = join(IOS_DIR, "QuantumAIMobile", "AppShell");
const PROJECT = join(IOS_DIR, "QuantumAIMobileHost.xcodeproj");
const PBXPROJ = join(PROJECT, "project.pbxproj");
const ROOTVIEW = join(APP_DIR, "RootView.swift");
const DERIVED_DATA = join(IOS_DIR, ".DerivedData_QuantumAIMobileHost");
const SPM_CACHE = join(IOS_DIR, ".swiftpm-cache");
const LOG_DIR = join(IOS_DIR, "_bun_agent_logs");
const BACKUP_DIR = join(IOS_DIR, "_bun_agent_backups");
const TS = new Date().toISOString().replace(/[-:TZ.]/g, "").slice(0, 14);

for (const p of [LOG_DIR, BACKUP_DIR, SPM_CACHE]) mkdirSync(p, { recursive: true });

const must = (p: string) => { if (!existsSync(p)) throw new Error(`YOK:${p}`); };
must(IOS_DIR); must(PROJECT); must(PBXPROJ); must(ROOTVIEW);

const log = (name: string, content: string) => writeFileSync(join(LOG_DIR, `${TS}_${name}`), content);

const rootViewBefore = readFileSync(ROOTVIEW, "utf8");
const pbxBefore = readFileSync(PBXPROJ, "utf8");

cpSync(ROOTVIEW, join(BACKUP_DIR, `RootView.swift.${TS}.bak`));
cpSync(PBXPROJ, join(BACKUP_DIR, `project.pbxproj.${TS}.bak`));

const backupRefs = [...pbxBefore.matchAll(/.*RootView\.swift\.bak[^\n]*\n?/g)].map(m => m[0]);
log("01_detect_backup_refs.log", backupRefs.length ? backupRefs.join("") : "NO_BACKUP_REF_FOUND\n");

let pbxAfter = pbxBefore
  .replace(/^.*RootView\.swift\.bak.*$\n?/gm, "")
  .replace(/\n{3,}/g, "\n\n");

if (pbxAfter !== pbxBefore) {
  writeFileSync(PBXPROJ, pbxAfter, "utf8");
}

let rootViewAfter = rootViewBefore;
const deprecatedOneArg = ".onChange(of: scenePhase) { phase in";
const acceptedTwoArgA = ".onChange(of: scenePhase) { _, phase in";
const acceptedTwoArgB = ".onChange(of: scenePhase) { oldPhase, newPhase in";

if (rootViewAfter.includes(deprecatedOneArg)) {
  rootViewAfter = rootViewAfter.replace(deprecatedOneArg, acceptedTwoArgA);
}

writeFileSync(ROOTVIEW, rootViewAfter, "utf8");

const rootViewCheck = readFileSync(ROOTVIEW, "utf8");
const hasDeprecated = rootViewCheck.includes(deprecatedOneArg);
const hasAcceptedTwoArg = rootViewCheck.includes(acceptedTwoArgA) || rootViewCheck.includes(acceptedTwoArgB);

log(
  "02_rootview_check.log",
  [
    `HAS_DEPRECATED=${hasDeprecated}`,
    `HAS_ACCEPTED_TWO_ARG=${hasAcceptedTwoArg}`,
    `MATCH_LINE=${(rootViewCheck.match(/.*onChange$begin:math:text$of\: scenePhase$end:math:text$.*$/m) || ["NOT_FOUND"])[0]}`,
    ""
  ].join("\n")
);

if (hasDeprecated) throw new Error("DEPRECATED_ONCHANGE_DEVAM");
if (!hasAcceptedTwoArg) throw new Error("IKI_PARAMETRELI_ONCHANGE_BULUNAMADI");

rmSync(DERIVED_DATA, { recursive: true, force: true });
mkdirSync(DERIVED_DATA, { recursive: true });

const resolveCmd = [
  "xcodebuild",
  "-project", PROJECT,
  "-resolvePackageDependencies",
  "-clonedSourcePackagesDirPath", SPM_CACHE
];

const buildCmd = [
  "xcodebuild",
  "-project", PROJECT,
  "-scheme", "QuantumAIMobileHost",
  "-configuration", "Debug",
  "-destination", "generic/platform=iOS Simulator",
  "-derivedDataPath", DERIVED_DATA,
  "-clonedSourcePackagesDirPath", SPM_CACHE,
  "-disableAutomaticPackageResolution",
  "build"
];

const resolveOut = await $`${resolveCmd}`.quiet().nothrow();
const resolveText = `${resolveOut.stdout.toString()}${resolveOut.stderr.toString()}`;
log("03_resolve.log", resolveText);

const buildOut = await $`${buildCmd}`.quiet().nothrow();
const buildText = `${buildOut.stdout.toString()}${buildOut.stderr.toString()}`;
log("04_build.log", buildText);

const failPatterns = [
  /no rule to process file .*RootView\.swift\.bak/mi,
  /'onChange\(of:perform:\)' was deprecated in iOS 17\.0/mi,
  /Missing package product 'QuantumAIMobile'/mi,
  /\*\* BUILD FAILED \*\*/mi
];

const hits = failPatterns
  .map((r) => ({ pattern: r.source, hit: r.test(buildText) }))
  .filter((x) => x.hit);

const summary = [
  `PBXPROJ_BACKUP=${join(BACKUP_DIR, `project.pbxproj.${TS}.bak`)}`,
  `ROOTVIEW_BACKUP=${join(BACKUP_DIR, `RootView.swift.${TS}.bak`)}`,
  `REMOVED_BACKUP_REFS=${backupRefs.length}`,
  `ROOTVIEW_LINE=${(rootViewCheck.match(/.*onChange$begin:math:text$of\: scenePhase$end:math:text$.*$/m) || ["NOT_FOUND"])[0]}`,
  `BUILD_SUCCEEDED=${/\*\* BUILD SUCCEEDED \*\*/.test(buildText)}`,
  `FAIL_HITS=${hits.length}`,
  `LOG_DIR=${LOG_DIR}`,
  ""
].join("\n");

log("05_summary.log", summary);

if (hits.length) {
  console.log(summary.trim());
  console.log("HATALAR=");
  for (const h of hits) console.log(h.pattern);
  process.exit(1);
}

console.log(summary.trim());
console.log("SONUC=BUN_AGENT_FIX_OK");
