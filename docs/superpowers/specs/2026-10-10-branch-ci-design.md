# Branch CI

Run GitHub Actions on every branch push and pull request, with manual dispatch
available for diagnosis. Build and run the full deterministic suite on Ubuntu
24.04 and macOS 14 using public, checksum-pinned let-go 1.13.0 and lgx 0.3.2
release binaries. Include the shipped JavaScript interaction probe. No provider
credentials or local configuration are needed.

Use read-only workflow permissions, pinned action revisions, bounded job time,
and cancellation of superseded runs. Keep stable check names for branch
protection. Do not upload application ledgers, local configuration, or test
artifacts; failures are visible in ordinary Actions logs.

After successful hosted runs, require both platform checks against the current
base on main. Require pull requests, but no extra reviewer count. Apply the
checks to administrators too; disallow force pushes and branch deletion. Bootstrap
the workflow onto main before enabling protection so the initial rollout does
not need a bypass.
