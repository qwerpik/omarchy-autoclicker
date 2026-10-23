# Contributing

Bug reports and pull requests are welcome.

1. Fork and branch from `main`.
2. Run `make check` — it builds the worker with `-Werror`, runs the unit and
   install tests, and lints the shell scripts with `shellcheck`.
3. Keep it dependency-free: the worker links only `libwayland-client`, the
   menu needs only Python's standard library and `rofi`.
4. If you change timing or input behaviour, test it on a real compositor with
   `autoclicker check` and a short run, and say what you measured in the PR.

Please use [Conventional Commits](https://www.conventionalcommits.org/)
(`feat:`, `fix:`, `docs:` …) for commit messages.
