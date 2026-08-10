Process the following meeting transcript: create a formatted Apple Note summary, then walk through GitHub issue creation one at a time.

Transcript:
$ARGUMENTS

---

## Step 1 — Summarize

Extract from the transcript:
- **Participants** and their roles
- **User context** — who they are, how they use the product
- **Feedback & use cases** discussed
- **Bugs** — numbered list
- **Feature requests** — numbered list
- **Follow-ups / action items**

Show the summary to the user.

## Step 2 — Create Apple Note (automatic, no confirmation needed)

Write the summary as HTML to `/tmp/meeting_summary_note.html` using `h1`, `h2`, `ul`, `ol`, `li`, `b` tags for structure. Then create the note via osascript:

```
osascript <<'APPLESCRIPT'
set noteContent to do shell script "cat /tmp/meeting_summary_note.html"
tell application "Notes"
    tell account "iCloud"
        if not (exists folder "Intel") then
            make new folder with properties {name:"Intel"}
        end if
        set intelFolder to folder "JLL"
        set matchingNotes to notes of intelFolder whose name is "NOTE_TITLE"
        if (count of matchingNotes) > 0 then
            set body of (item 1 of matchingNotes) to noteContent
        else
            make new note at intelFolder with properties {name:"NOTE_TITLE", body:noteContent}
        end if
    end tell
end tell
APPLESCRIPT
```

Name the note: `Meeting Summary — [brief topic] ([YYYY-MM-DD])`. Replace `NOTE_TITLE` in the script with the actual title.

Tell the user the note was created and its title.

## Step 3 — GitHub Issues, one at a time

For each bug and feature request you identified, ask the user individually — **do not batch them**:

> Should I create this GitHub issue?
>
> **[Issue title]**
> [1–2 sentence description of the issue]
>
> `yes` / `no`

Wait for their answer before moving to the next issue. If they say yes, immediately run:

```
gh issue create --title "TITLE" --body "BODY"
```

Use a clear body with context from the meeting. Then confirm it was created (show the URL) and move on to the next issue.

If they say no, skip it and move on.

After all issues are handled, give a brief closing summary: how many notes created, how many issues filed.
