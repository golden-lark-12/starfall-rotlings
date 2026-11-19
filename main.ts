// Starfall Rotlings — the program that assembles the submission
// (Node 22, standard library only).
//
// It gathers the pieces the grader wants and lays them out in the
// output directory:
//   * game.rbxl — the binary place file, produced on the author's
//     machine from src/ and default.project.json with
//     `rojo build default.project.json --output game.rbxl`.
//     Binary only; a .rbxlx text place is not accepted.
//   * src/ — the place's Luau scripts, exactly as Rojo laid them out.
//   * screenshots/ — three or four captures of the game running in
//     Studio. The first file by name is the cover and is the same
//     picture as the Roblox thumbnail.
//   * PLAY.json — the published Public place: its url, place_id and
//     universe_id.
//   * dossier.json — the summary the judge reads, written by the
//     vendored make.fun library from the files above.
//
// The grader runs this program twice and demands byte-identical
// output, so the program does no network, reads no clock and rolls
// no dice: it only copies files and writes the dossier.
//
// Run it locally the same way the grader does, with out/ standing
// in for /output:
//   mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts

import { copyFileSync, cpSync, existsSync, mkdirSync, readdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { basename, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildDossier } from './vendor/makefun-roblox.ts';

// This file's directory is the repository root. The output directory
// is /output inside the grader, or MAKEFUN_OUTPUT_DIR when run by hand.
const repoRoot = fileURLToPath(new URL('.', import.meta.url));
const outputDir = process.env.MAKEFUN_OUTPUT_DIR ?? '/output';

// The grader refuses any output name that does not start with a
// letter, a digit or _, or that holds anything but letters, digits,
// . _ and -. A dotfile such as .gitkeep or .DS_Store anywhere under
// /output fails the entry, so the copy filter drops every dotted
// name at any depth.
function isAllowedOutputName(path: string): boolean {
	return !basename(path).startsWith('.');
}

function abort(message: string): never {
	throw new Error(`starfall-rotlings main.ts: ${message}`);
}

// Every screenshot must fit the gate: at most 4, each at most 256 KiB.
const MAX_SCREENSHOTS = 4;
const MAX_SCREENSHOT_BYTES = 256 * 1024;

function verifyScreenshots(dir: string): void {
	if (!existsSync(dir)) {
		abort('screenshots/ is missing');
	}
	const shots = readdirSync(dir).filter((name) => isAllowedOutputName(join(dir, name)));
	if (shots.length < 3 || shots.length > MAX_SCREENSHOTS) {
		abort(`screenshots/ holds ${shots.length} images, need 3 or 4`);
	}
	for (const name of shots) {
		const size = statSync(join(dir, name)).size;
		if (size > MAX_SCREENSHOT_BYTES) {
			abort(`screenshot ${name} is ${size} bytes, over the 256 KiB cap`);
		}
	}
}

function verifyPlace(path: string): void {
	if (!existsSync(path)) {
		abort('game.rbxl is missing — build it first: rojo build default.project.json --output game.rbxl');
	}
	if (statSync(path).size > 32 * 1024 * 1024) {
		abort('game.rbxl is over the 32 MiB cap');
	}
}

// Refuse to hand in the starter's placeholder link: the gate refuses
// it anyway, and failing here says so in plain words instead of a
// row code.
function verifyPlayLink(path: string): void {
	const play = JSON.parse(readFileSync(path, 'utf8')) as { place_id?: unknown; universe_id?: unknown };
	if (typeof play.place_id !== 'number' || play.place_id <= 0) {
		abort('PLAY.json still holds the starter place_id 0 — publish the experience first, then fill it in');
	}
	if (typeof play.universe_id !== 'number' || play.universe_id <= 0) {
		abort('PLAY.json still holds the starter universe_id 0 — publish the experience first, then fill it in');
	}
}

function main(): void {
	mkdirSync(outputDir, { recursive: true });

	verifyPlace(join(repoRoot, 'game.rbxl'));
	verifyScreenshots(join(repoRoot, 'screenshots'));
	verifyPlayLink(join(repoRoot, 'PLAY.json'));

	copyFileSync(join(repoRoot, 'game.rbxl'), join(outputDir, 'game.rbxl'));
	copyFileSync(join(repoRoot, 'PLAY.json'), join(outputDir, 'PLAY.json'));
	cpSync(join(repoRoot, 'src'), join(outputDir, 'src'), { recursive: true, filter: isAllowedOutputName });
	mkdirSync(join(outputDir, 'screenshots'), { recursive: true });
	cpSync(join(repoRoot, 'screenshots'), join(outputDir, 'screenshots'), { recursive: true, filter: isAllowedOutputName });

	// The scorer's caps, mirrored from the kit's gate: only
	// text_max_bytes shapes the dossier bytes; the rest refuse an
	// entry the scorer would refuse anyway (too many or too large
	// screenshots, too many instances, too much script source, or
	// script paths too long in total).
	writeFileSync(
		join(outputDir, 'dossier.json'),
		buildDossier(outputDir, {
			text_max_bytes: 65536,
			screenshots: { max: 4, max_bytes: 262144 },
			max_instances: 500000,
			scripts_max_source_bytes: 8388608,
			scripts_max_path_chars: 1048576,
		}),
	);
}

main();
