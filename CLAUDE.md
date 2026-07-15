# Claude Context for This Repo

## Branch Naming
Follow Git Flow with feature/bugfix naming:
- **Feature branches**: `feature/what-it-does` (e.g. `feature/ui-new-button`, `feature/auth-flow`)
- **Bugfix branches**: `fix/what-broke` (e.g. `fix/old-button`, `fix/auth-race-condition`)
- **Release branches**: `release/version` (e.g. `release/1.0.0`)
- **Hotfix branches**: `hotfix/critical-issue` (e.g. `hotfix/crash-on-startup`)

Merge to `develop`, then `develop` → `main` for releases.

## Credits
Credit the actual author of the code or structure, not the AI agent. Not lying, but crediting without automatically pasting. "Done by Claude"

Do not credit Claude, agents, or AI systems as authors. AI output is a tool.

## Notes
- Keep commits atomic and branch names descriptive
- PR titles should match branch intent
