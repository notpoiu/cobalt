const fs = require("fs");
const path = require("path");
const { spawn } = require("child_process");

const BASE_DIR = path.resolve(__dirname, "..");
const SRC_DIR = path.join(BASE_DIR, "Src");
const OUTPUT_FILE = path.join(BASE_DIR, "Distribution", "Script.luau");

const DEBOUNCE_MS = 300;
let debounceTimer;
let building = false;
let buildQueued = false;

function build() {
    if (building) {
        buildQueued = true;
        return;
    }

    building = true;
    const startTime = Date.now();
    console.log("\x1b[36m[watch]\x1b[0m Rebuilding Cobalt...");

    const child = spawn("lune", [
        "run",
        "Build",
        "bundle",
        "header=Build/Header.luau",
        "minify=false",
        "ci-mode=true",
        "verbose=false",
        "output=Distribution/Script.luau",
        "temp-dir-base=Distribution",
    ], {
        cwd: BASE_DIR,
        stdio: "pipe",
        env: process.env,
    });

    let output = "";
    child.stdout.on("data", (chunk) => { output += chunk.toString(); });
    child.stderr.on("data", (chunk) => { output += chunk.toString(); });

    child.on("close", (exitCode) => {
        const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
        const failed = exitCode !== 0 || !fs.existsSync(OUTPUT_FILE);

        if (failed) {
            console.log(`\x1b[31m[watch]\x1b[0m Cobalt build failed (${elapsed}s)`);
            if (output.length > 0) process.stdout.write(output.endsWith("\n") ? output : `${output}\n`);
        } else {
            console.log(`\x1b[32m[watch]\x1b[0m Cobalt rebuilt in ${elapsed}s`);
        }

        building = false;

        if (buildQueued) {
            buildQueued = false;
            build();
        }
    });
}

console.log("\x1b[36m[watch]\x1b[0m Watching Src for Luau changes");
console.log("\x1b[36m[watch]\x1b[0m Running initial build...");
build();

fs.watch(SRC_DIR, { recursive: true }, (_event, filename) => {
    if (!filename || !filename.endsWith(".luau")) return;

    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(build, DEBOUNCE_MS);
});

console.log("\x1b[36m[watch]\x1b[0m Waiting for changes...\n");
