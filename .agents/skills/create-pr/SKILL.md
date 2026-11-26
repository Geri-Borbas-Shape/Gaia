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

Start with one short paragraph in simple, plain English explaining what the feature does for the user. Then add a brief Markdown checklist (`- [x]`) with only the essential technical changes and actual validation results. Keep each item short; do not mark unfinished work or unrun checks as complete.

Avoid extra prose sections, implementation narratives, and conversation history. Keep any material limitation to one short sentence or checklist item. Update the description to match the final change.

Preserve requested screenshots and video clips after the checklist, with short labels. When there are several, group them in a collapsible `<details>` section so the main description stays short. Follow the video requirements below.

## Video evidence

- Upload actual video files to GitHub's native attachments. Use a GitHub CLI version whose `gh pr create --help` or `gh pr edit --help` lists `--attach`, or GitHub's attachment UI. Prefer H.264 MP4 for playback compatibility.
- With the CLI, reference each local video as a standalone `![](path/to/clip.mp4)` paragraph in the body file and pass the same path with `--attach`. Repeat the flag for multiple clips. Read back the resulting description to obtain the real uploaded asset URLs.
- Embed each uploaded video explicitly with `<video src="UPLOADED_GITHUB_ASSET_URL" controls width="320"></video>`, using the actual `https://github.com/user-attachments/assets/...` URL returned by the upload. Replace the temporary Markdown references or bare attachment URLs with these tags before finishing.
- Do not use GIFs, GIF previews, raw repository URLs, or download links as substitutes for uploaded video players. Preserve ordinary screenshots as images.
- Verify the saved PR body and GitHub-rendered HTML contain the expected video players and working attachment sources. If native upload is unavailable, report that blocker and keep the recorded files ready; do not silently substitute another format.

Example upload command:

```bash
gh pr edit "$PR_NUMBER" --body-file "$BODY_FILE" --attach "$VIDEO_PATH"
```

[GitHub CLI attachment documentation](https://docs.github.com/en/github-cli/github-cli/attaching-files-with-github-cli).

## Publish

Commit and push the feature branch, then create the PR against the intended base. Use a connected GitHub tool when it supports the action; use the authenticated `gh` CLI when needed. Pass multiline descriptions through a structured argument or `--body-file`.

Verify the resulting PR's URL, source branch, base branch, title, and description. Report its link and validation results. Creating a PR does not imply merging it.
