#!/usr/bin/env node

/**
 * Removes what prepack copied into the package directory after npm pack/publish
 * (listed in .prepack-copied.json). Run from a publishable package directory via its
 * "postpack" script.
 */

import { existsSync, readFileSync, rmSync } from 'fs';
import { join } from 'path';

const packageDir = process.cwd();
const marker = join(packageDir, '.prepack-copied.json');
const copied = existsSync(marker) ? JSON.parse(readFileSync(marker, 'utf8')) : [];
for (const entry of copied) {
  const target = join(packageDir, entry);
  if (existsSync(target)) {
    rmSync(target, { recursive: true, force: true });
    console.log(`Cleaned up ${entry}`);
  }
}
rmSync(marker, { force: true });
