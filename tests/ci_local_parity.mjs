// tests/ci_local_parity.mjs
// Keeps `pnpm exec ci-local` (ci-local.config.sh) equal to the CI workflow:
// the project name is pinned and the package's own parity checks pass (every
// workflow `run:` step is a box step with the same commands, in order, or is
// named with ci_not_mirrored; nothing publishes a port; .nvmrc is exact).
// Called from tests/ci_local_parity.bats; no Docker needed.
//
// usage: node tests/ci_local_parity.mjs [repo-dir]   (default: this repo)
// exit:  0 no problem; 1 problems, one per line on stderr.
import { loadPlan, parityProblems } from '@jals1212/ci-local/parity'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const EXPECTED_PROJECT = 'dotfiles-ci'

const cwd = resolve(process.argv[2] ?? resolve(dirname(fileURLToPath(import.meta.url)), '..'))

const problems = []
const plan = await loadPlan({ cwd })
if (plan.project !== EXPECTED_PROJECT) {
  problems.push(`plan.project is "${plan.project}", expected "${EXPECTED_PROJECT}"`)
}
problems.push(...(await parityProblems({ cwd })))

if (problems.length > 0) {
  for (const problem of problems) console.error(problem)
  process.exit(1)
}
console.log(`ci-local parity ok: project ${plan.project}, jobs ${plan.jobs.join(' ')}`)
