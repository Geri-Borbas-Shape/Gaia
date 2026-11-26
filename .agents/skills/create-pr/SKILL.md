---
name: create-pr
description: Create, open, or prepare a pull request in this repository using its required branch and title conventions. Use for every PR creation request, including a PR requested as the final step of implementation, and when updating PR naming or descriptions.
---

# Create PR

Use `feature/<short-kebab-case-description>` for the branch and `Feature: <concrete change>` for the PR title. These conventions apply to every PR in this repository, including documentation and tooling changes. For example: `feature/star-map` and `Feature: Add interactive 3D star map`.

## Prepare

- Inspect the working tree, target branch, and any existing PR for the work. Continue an existing feature branch when appropriate; keep unrelated requested work in separate PRs.
- Finish the requested implementation and relevant validation before publishing. Record actual check results and material limitations.
- Confirm that the proposed diff contains only the intended change. Keep user edits outside the requested scope out of the commit.

## Describe

Lead with the concrete problem and resulting user-visible behaviour. Keep detail proportional to the change, and describe the final implementation rather than the conversation history.

Include relevant validation. When screenshots or video clips are requested, include the captures in the PR description using stable GitHub URLs and label the behaviour demonstrated by each clip. Update the title and description when the scope changes.

## Publish

Commit and push the feature branch, then create the PR against the intended base. Use a connected GitHub tool when it supports the action; use the authenticated `gh` CLI when needed. Pass multiline descriptions through a structured argument or `--body-file`.

Verify the resulting PR's URL, source branch, base branch, title, and description. Report its link and validation results. Creating a PR does not imply merging it.
