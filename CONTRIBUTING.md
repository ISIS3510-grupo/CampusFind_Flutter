# Contributing to CampusFind

This guide describes how the team works in this repository. Following it is part of the course grade (repository management and collaboration multipliers), so please read it once.

## 1. Workflow

```
feat/12-admin-login ──PR (squash)──▶ dev ──PR (merge commit)──▶ main
```

| Branch | Purpose | How changes get in |
|---|---|---|
| `main` | Stable version that is graded and demoed | Only through a PR **from `dev`**, merge commit |
| `dev` | Integration branch (default branch) | Only through a PR from a work branch, squash merge |
| `feat/…`, `fix/…`, etc. | One branch per issue | Direct pushes |

1. **Pick or create an issue.** Every change starts from an issue created with one of the templates. Assign yourself, add it to the current milestone (e.g. `Sprint 2`) and to the project board.
2. **Create a branch from `dev`** using the naming convention below.
3. **Commit often** with Conventional Commits.
4. **Open a pull request into `dev`** using the template. Link the issue with `Closes #<number>`.
5. **Get one approval** from a teammate and make sure CI is green.
6. **Squash and merge.** The branch is deleted automatically.
7. **Release to `main`:** when `dev` is stable (at least before each deadline), someone opens a PR `dev → main`, it gets one approval and is merged with a merge commit.

Both `main` and `dev` are protected: nobody (not even admins) can push to them directly, force-push them or delete them. A PR into `main` from any branch other than `dev` fails the "Source branch is dev" check and cannot be merged.

## 2. Branch names

```
<type>/<issue-number>-<short-description>
```

| Type | Use it for |
|---|---|
| `feat` | New functionality or view |
| `fix` | Bug fix |
| `refactor` | Code change without new behavior |
| `chore` | Setup, dependencies, configuration |
| `docs` | Documentation |
| `test` | Tests only |

Examples: `feat/12-admin-login`, `fix/20-camera-permission-crash`.

## 3. Commit messages (Conventional Commits)

```
<type>(<scope>): <what changed, in imperative mood>

<optional body: why the change was needed>
```

Examples:

```
feat(auth): add admin login with role validation
fix(reports): keep draft when the connection drops
refactor(repository): move Firestore queries out of the ViewModel
```

Write verbose commits: the message should explain the change without opening the diff.

## 4. Pull requests

- Keep PRs small and focused on one issue.
- Fill in every section of the template, including how you tested it.
- Add screenshots when the UI changes.
- Resolve all review conversations before merging.
- Keep your branch updated with `dev` (use the "Update branch" button or `git merge origin/dev`).
- PRs into `dev` use **squash merge**, so the PR title becomes the commit on `dev`: write it as a Conventional Commit.
- PRs `dev → main` use a **merge commit**, so `dev` and `main` keep a shared history.

## 5. Reviews

- Review within the same day when possible, especially close to a deadline.
- Approve only after reading the code and checking the acceptance criteria of the linked issue.
- Use "Request changes" for anything that blocks the merge, and comments for suggestions.

## 6. Labels

| Group | Labels |
|---|---|
| Type | `type: feature`, `type: bug`, `type: chore`, `type: refactor`, `type: docs` |
| Sprint category | `cat: sensor`, `cat: bq-type2`, `cat: context-aware`, `cat: smart-feature`, `cat: auth`, `cat: external-service`, `cat: view`, `cat: pattern` |
| Priority | `priority: high`, `priority: medium`, `priority: low` |
| Status | `blocked`, `needs-review` |

## 7. Secrets

Never commit API keys, tokens or passwords (Twilio, email services, Maps keys with billing, etc.). Use local configuration files listed in `.gitignore` and share them privately with the team.

## 8. Deadlines

Deadlines are in GMT-5, but GitHub records timestamps in UTC. Commits or wiki edits after the deadline are not graded, and a wiki edit after the deadline gives the deliverable a 0.
