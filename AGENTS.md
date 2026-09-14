# Project work rules

## Mandatory build storage policy

- This is a Godot 4 PC game with macOS Universal and Windows Desktop presets.
  Check `project.godot`, `export_presets.cfg`, and existing tooling before adding platforms.
- All automated build/export/package work must use `python3 tools/build.py` and
  its owned job/lease lifecycle. New capture, validation, and build tools must
  reuse it or implement and test the same ownership, locking, cleanup, and atomic
  publication guarantees before use. GUI export is only a manual exception;
  never export over an existing release or rollback package.
- Temporary source copies, import/export intermediates, extraction trees, and
  tool temporary files belong in `builds/.managed/work/<job-id>/`. Clean on
  success, failure, SIGINT/SIGTERM/SIGHUP; reclaim crash leftovers only after
  validating ownership and acquiring the lease. Never delete another live job.
- Development exports: keep the latest 2 successes **per target**; raw build logs:
  latest 10 jobs, at most 1 MiB per file. Publish only after validation; keep the
  previous working output if a new build or publication fails.
- Release archives, patch baselines, rollback packages, crash symbols/mappings,
  credentials, signing keys, user saves, original assets/configuration, Git, and
  shared dependency caches are outside generic retention. Never use `git clean`
  or broad recursive deletion as project cleanup.
- Do not accumulate date/number copies of packages or extracted trees without a
  specific need. Debug retention exceptions must record purpose, exact location,
  owner, and deletion/review deadline in `docs/BUILD_STORAGE.md`; remove them when
  that purpose ends. An unknown file is not disposable because it is ignored.
- Cleanup errors must report a warning and the exact retained path. Test cleanup
  lifecycle changes with `python3 -m unittest discover -s tests -p 'test_build_cleanup.py'`.
- See `docs/BUILD_STORAGE.md` for commands, preserved data, host support, and exceptions.
