---
contract_version: 2
kind: tool
service: terminus-plugin-test       # a public container image (quay.io/pantheon-public/terminus-plugin-test, mirrored to Docker Hub) used as a CI base image for Terminus plugins; nothing runs on Pantheon infrastructure

trigger: other                      # push to a long-lived release branch. One branch per image line: 4.x (current, GitHub Actions), 1.x (default branch, Quay build trigger), 2.x and 3.x (old). Not merge-to-default-branch: the default branch is the oldest line
merged_implies_deployed: true       # for a push to 4.x. For 1.x see the next field   # inferred for 1.x: the Quay build records show builds from 1.x pushes, last on 2024-08-30
other_paths_to_prod:
  - "a push to `4.x` runs `.github/workflows/build_and_push.yml`, which builds and PUSHES the images. The workflow file exists only on the 4.x branch, not on the default branch (1.x), so it is invisible in `gh workflow list`, `gh run list` and the Actions tab's default view"
  - "a push to `1.x` (the default branch; includes merging a dependabot PR) probably rebuilds and re-tags `1.x` and `latest` through a Quay build trigger. Quay's build list shows `1.x`/`latest` builds from commits on this branch, the last on 2024-08-30 (c40d48b). The trigger's config needs Quay admin, so this is not confirmed"   # TODO(owner): confirm the Quay trigger is still enabled, what branches it watches, and whether the 2024-08-30 build moved the tag (the tag listing still shows 2022-08-09)
  - "pushes to any other branch run `build_only.yml` (builds, no push)"
  - "re-tagging or deleting a tag in Quay or Docker Hub by hand changes what consumers pull, with no workflow run"
  # trap: every rebuild is non-reproducible. The 4.x Dockerfile uses `FROM php:${PHPVERSION}-cli`, `composer:latest` and Terminus `releases/latest`, so rebuilding the same commit gives a different image. Reverting the repo does not restore an old image: roll back by digest

pipeline:
  system: github-actions            # 4.x. 1.x/2.x/3.x: quay build trigger (other)
  workflow: ".github/workflows/build_and_push.yml (on branch 4.x only)"
  jobs_in_order: [docker]           # one job, matrix over PHP 7.4, 8.0, 8.1, 8.2
  typical_minutes: null             # TODO(verify-on-deploy): no run history exists (last push to 4.x was 2023-01-03; runs have expired). Time the next push
  minutes_by_change: {}
  watch: "`gh run list -R pantheon-systems/terminus-plugin-test --branch 4.x` (do not pass --workflow: the file isn't on the default branch). Four matrix legs, one per PHP version"
  concurrency_group: null           # none declared
  cancel_in_progress: null
  blocked_by_waiting_run: null
  approval_gate: null               # no GitHub Environment

release:
  mechanism: "push to 4.x -> build_and_push.yml builds one image per PHP version and pushes `quay.io/pantheon-public/terminus-plugin-test:4.x-php<ver>` and `pantheonpublic/terminus-plugin-test:4.x-php<ver>` (Docker Hub) with the repo's own registry secrets. Push to 1.x -> Quay build trigger rebuilds `1.x` and `latest` (inferred, see other_paths_to_prod)"
  tag_scheme: "branch-and-PHP names, mutable: `4.x-php7.4`, `4.x-php8.0`, `4.x-php8.1`, `4.x-php8.2`; `1.x`; `latest` (same digest as `1.x`). No semver"
  never: "assume a tag is immutable. Tags are re-pushed on every rebuild, and previous digests may be garbage-collected"
  procedure: "merge or push to the branch for the image line. Nothing else"

consumers:                          # `gh search code --owner pantheon-systems "pantheon-public/terminus-plugin-test"`, observed 2026-11-10 (cap 30 hits; only these are real consumers)
  - {repo: terminus-composer-plugin, pin: "quay.io/pantheon-public/terminus-plugin-test:4.x-php8.2 (mutable tag)", file: ".circleci/config.yml", picked_up_by: "its next CircleCI run pulls whatever the tag points at"}
  - {repo: docker-php-ci, pin: "none (README only)", picked_up_by: "tells readers to use this image for plugin tests"}
  - {repo: terminus-plugin-example, pin: "none (README only)", picked_up_by: "documentation link"}
  - {repo: "external plugin authors", pin: "the README's `:1.x` on the default branch, or `:4.x-php*`", picked_up_by: "public image on Quay and Docker Hub; unknown count"}

repo_properties:
  observed_at: 2026-11-10
  trust_level: TL4
  ccb_status: in-ccb
  owner: developer-experience
  repo_type: tool

gating_checks:                      # `gh api repos/pantheon-systems/terminus-plugin-test/rules/branches/1.x`
  required: ["Wiz IaC Scanner", "Wiz Vulnerability Scanner", "Wiz Data Scanner"]   # org ruleset 'TL4 - Low', on the default branch 1.x
  approvals: {required: 1, code_owner: true, last_push_approval: false, strict_up_to_date: false, merge_queue: false}   # org ruleset; the repo has no ruleset of its own
  run_but_not_required: ["build_only (non-release branches): builds the images without pushing"]
  conditional: []
  release_gate: "TODO(owner): which rules apply to pushes to the 4.x branch, which is the one that publishes? The rules above were read for 1.x only"

environments:
  - {name: quay, target: "quay.io/pantheon-public/terminus-plugin-test", gates_prod: true}
  - {name: dockerhub, target: "pantheonpublic/terminus-plugin-test", gates_prod: false}   # same job; the Quay login and push happen in the same build step

artifact:
  image: quay.io/pantheon-public/terminus-plugin-test
  tag_scheme: fixed
  tag_mutable: true                 # roll back by DIGEST
  retention: "TODO(owner): Quay tag history / garbage-collection window (needs Quay admin)"
  version_signal: "digest of the pulled tag; `curl -s 'https://quay.io/api/v1/repository/pantheon-public/terminus-plugin-test/tag/?limit=20&onlyActiveTags=true'`"
  tag_to_sha: "no label ties an image to a commit. Compare the tag's `last_modified` with the 4.x push time"   # inferred: no OCI revision label in the Dockerfile

runtime: []                         # a CI base image; runs in consumers' pipelines

deployed_when:                      # ALL must hold
  - "the push's build_and_push run (4.x) or Quay build (1.x) succeeded for every matrix leg"
  - "the Quay tag listing shows the tag's `last_modified` at or after the push, with a new `manifest_digest`"
  - "the image runs: `docker run --rm quay.io/pantheon-public/terminus-plugin-test:<tag> terminus --version`"   # TODO(verify-on-deploy): not run for this draft

health:
  soak_minutes: 0
  baseline: "the tag listing as of 2026-11-10 (below)"
  checks:
    - name: tags and digests
      kind: command
      run: "curl -s 'https://quay.io/api/v1/repository/pantheon-public/terminus-plugin-test/tag/?limit=20&onlyActiveTags=true' | python3 -c \"import json,sys;[print(t['name'],t['last_modified'],t['manifest_digest']) for t in json.load(sys.stdin)['tags']]\""
      healthy: "the pushed tag's last_modified is new. Baseline 2026-11-10: 4.x-php8.2 d80f0c92eefa (2023-01-03), 4.x-php8.1 8dbdba8e85ae, 4.x-php8.0 4c222445ef43, 4.x-php7.4 7294c23a52d5, latest/1.x 6a5d00160705 (2022-08-09)"
    - name: image starts and has Terminus
      kind: command
      run: "docker run --rm quay.io/pantheon-public/terminus-plugin-test:<tag> sh -c 'terminus --version && php -v | head -1 && bats --version'"
      healthy: "prints a Terminus version, the expected PHP version, and a bats version"   # TODO(verify-on-deploy): command not run for this draft
    - name: consumers still build
      kind: delegate
      run: "the next CircleCI run of terminus-composer-plugin (pulls :4.x-php8.2)"
      healthy: "green"
  known_baseline_errors: []
  dashboards: []
  alerts: []

rollback:
  options:
    - when: "a new 4.x image breaks consumers' pipelines"
      kind: retract-and-repin
      steps: |
        1. Before the push, record the digests of the tags about to change (capture_before_merge).
        2. Put the old digest back on the tag. In Quay: tag history -> revert the tag to the previous manifest (needs write access to the quay.io/pantheon-public org). Or, from any machine that can pull both: `docker pull quay.io/pantheon-public/terminus-plugin-test@sha256:<old>` then `docker tag` and `docker push` to the tag. Docker Hub is a separate copy: do the same there.
        3. Tell affected consumers to pin the digest meanwhile (`image: quay.io/pantheon-public/terminus-plugin-test@sha256:<old>`).
        4. Fix on 4.x. Do NOT just revert and push: the rebuild pulls current PHP, Composer and Terminus and may reproduce the problem.
      time_to_rollback_minutes: 15  # inferred
    - when: otherwise
      kind: roll-forward
      steps: "fix on 4.x and push; the image rebuilds"
      time_to_rollback_minutes: null  # TODO(verify-on-deploy): needs a timed build
  not_restored:
    - "consumer pipelines that already ran on the bad image"
    - "anything an old digest no longer exists for (retention unknown)"
  one_way_changes: []               # checked: an image carries no state
  currently_blocked: null
  last_exercised: null
  capture_before_merge: "the tag listing command under health, saved to a file, before pushing to 4.x or 1.x"
  who_can: ["TODO(owner): who has write access to the quay.io/pantheon-public organization and the pantheonpublic Docker Hub org. Reverting a tag needs it. The repo's own secrets (QUAY_*, DOCKERHUB_*) are what the workflow uses"]
  verify: "the tag listing shows the old digest on the tag; `docker pull` of the tag gives the old image ID; a consumer pipeline is green"

escalation:
  slack: "#ask-hosting"
  owner_team: developer-experience
  paged: false                      # inferred: no alerts exist
  issues: "https://github.com/pantheon-systems/terminus-plugin-test/issues"

preflight:
  - "gh auth status (read; write to push to the release branch)"
  - "curl (the Quay tag API is public)"
  - "docker, with access to pull and push quay.io/pantheon-public/terminus-plugin-test (only for rollback)"

automation_blockers:
  - blocker: "tags are mutable and every rebuild is non-reproducible (floating PHP base image, `composer:latest`, Terminus `releases/latest`), so a revert does not restore the old image and the rollback target is a digest that may not be retained"
    clears_when: "images are tagged per commit or with a date, previous digests are retained, and consumers pin digests"
  - blocker: "the publishing workflow lives only on the 4.x branch and has no retained run history, so a deploy can't be watched through the usual `--workflow` queries"
    clears_when: "the workflow moves to the default branch, or 4.x becomes the default"
  - blocker: "the 1.x (default branch) publish path is a Quay build trigger that can't be read without Quay admin, and the default branch's Dockerfile (PHP 7.1, Terminus 1.9.0) is not the image consumers use"
    clears_when: "the owners confirm what the trigger does, or retire the 1.x/2.x/3.x lines"
  - blocker: "no health signal beyond a smoke run of the image"
    clears_when: "a CI job that pulls the new tag and runs a sample plugin's tests"

verified: null                      # TODO(verify-on-deploy): pass 2 fills it from a real push to 4.x
---

# Deployment

This repo builds a public CI base image for testing Terminus plugins. "Deploying" it means pushing new image tags to Quay (and Docker Hub). Nothing runs on Pantheon infrastructure.

The repo has one branch per image line, and the **default branch (`1.x`) is the oldest line**: PHP 7.1 and Terminus 1.9.0. The live line is **`4.x`**, whose Dockerfile builds PHP 7.4 to 8.2 images with the latest Terminus PHAR. The 4.x images were last pushed on 2023-01-03.

## How a change reaches production

1. **PR to the line's branch.** For `4.x`: open a PR against it. `build_only.yml` builds the four images without pushing, which is the only pre-merge test. Org rules require one code-owner approval and the three Wiz scanners on the default branch. TODO(owner): confirm what applies to `4.x`.
2. **Push or merge to `4.x`.** `build_and_push.yml` builds four images (PHP 7.4, 8.0, 8.1, 8.2) and pushes `4.x-php<ver>` to `quay.io/pantheon-public/terminus-plugin-test` and `pantheonpublic/terminus-plugin-test`. Duration unknown: TODO(verify-on-deploy).
3. **Push to `1.x`** (including merging a dependabot PR) probably triggers a Quay build that re-tags `1.x` and `latest`. [inferred] Open dependabot PR #21 bumps `drupaldocker/php` for this line.
4. **Consumers pull the mutable tag** on their next run. `terminus-composer-plugin`'s CircleCI uses `:4.x-php8.2`.

Merging this contract PR to `1.x` is itself a push to `1.x`, so it may rebuild `1.x` and `latest` from the unchanged Dockerfile.

## How to confirm it deployed

```bash
# new last_modified and manifest_digest on the tags you pushed
curl -s 'https://quay.io/api/v1/repository/pantheon-public/terminus-plugin-test/tag/?limit=20&onlyActiveTags=true' \
  | python3 -c "import json,sys;[print(t['name'],t['last_modified'],t['manifest_digest']) for t in json.load(sys.stdin)['tags']]"

# the 4.x run (the workflow isn't on the default branch, so don't filter by --workflow)
gh run list -R pantheon-systems/terminus-plugin-test --branch 4.x -L 3
```

Baseline on 2026-11-10: `4.x-php8.2` `sha256:d80f0c92…` (2023-01-03), `latest` and `1.x` `sha256:6a5d0016…` (2022-08-09).

## How to confirm it's healthy

There are no dashboards or alerts. Health is a smoke run of the image (`terminus --version`, `php -v`, `bats --version`) and the next green pipeline of a consumer (`terminus-composer-plugin`). TODO(verify-on-deploy): run the smoke command on a real build.

## Rollback

An image can't be rebuilt to an earlier state: the Dockerfile pulls the current PHP image, Composer and Terminus. Roll back by putting the previous **digest** back on the tag.

1. **Before pushing**, save the tag listing (command above).
2. Revert the tag in Quay to the previous manifest, or pull, re-tag and push the old digest. Do the same on Docker Hub, which is a separate copy. Both need write access to those organizations.
3. Consumers that can't wait pin `quay.io/pantheon-public/terminus-plugin-test@sha256:<old>`.
4. Fix on `4.x`; don't just revert and push.

**Verify:** the listing shows the old digest on the tag, and a consumer pipeline is green.

**What this doesn't restore:** pipelines that already ran on the bad image, or digests Quay has garbage-collected (retention unknown).

Rollback has never been exercised.

## Escalation

- Owner: `developer-experience` (code owners `@pantheon-systems/developer-experience`).
- Nobody is paged and there are no alerts.
- Issues: https://github.com/pantheon-systems/terminus-plugin-test/issues
- Slack: `#ask-hosting`.

## Open owner questions

- TODO(owner): is the Quay build trigger on `1.x` still enabled, and what does it watch? Did the 2024-08-30 build move `1.x`/`latest`?
- TODO(owner): which rules protect pushes to `4.x`?
- TODO(owner): who has write access to the Quay and Docker Hub organizations, and how long are old digests kept?
- TODO(owner): should `4.x` become the default branch, and the 1.x to 3.x lines be retired? The README on the default branch advertises `:1.x`.

## Suggested pipeline changes

- Make `4.x` the default branch, or move the workflow to the default branch.
- Tag images by date or commit and keep digests, so there is something to roll back to.
- Pin the base image and Terminus version, or accept that every rebuild changes the image.
