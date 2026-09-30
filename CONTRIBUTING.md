# Contributing to CampusFind

This guide describes how the team works in this repository. Following it is part of the course grade (repository management and collaboration multipliers), so please read it once.

## 1. Workflow

1. **Pick or create an issue.** Every change starts from an issue created with one of the templates. Assign yourself, add it to the current milestone (e.g. `Sprint 2`) and to the project board.
2. **Create a branch from `main`** using the naming convention below.
3. **Commit often** with Conventional Commits.
4. **Open a pull request** into `main` using the template. Link the issue with `Closes #<number>`.
5. **Get one approval** from a teammate and make sure CI is green.
6. **Squash and merge.** The branch is deleted automatically.

`main` is protected: nobody (not even admins) can push to it directly, force-push it or delete it. All changes go through a pull request.

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
- Only **squash merge** is enabled, so the PR title becomes the commit on `main`: write it as a Conventional Commit.

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
