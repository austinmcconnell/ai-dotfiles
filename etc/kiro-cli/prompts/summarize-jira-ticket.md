# Summarize JIRA Ticket

Fetch and summarize the specified JIRA ticket, including all comments.

Fetch all linked/related tickets as well. For each linked ticket, note the link type
(e.g., "blocks", "is blocked by", "relates to", "is caused by").

## Output

Write a markdown summary file for each ticket, named by issue key (e.g., `SCRN-1360.md`).

Each summary should include:

1. **Header**: Issue key, type, status, priority, and assignee
1. **Description**: Condensed summary of the description
1. **Comments**: Summary of comment thread (who said what, key decisions or context)
1. **Linked tickets**: List of linked issue keys with link type and one-line summary

For linked tickets, include a section at the top noting which parent ticket linked to it
and the relationship type, so the connection is clear when reading the file standalone.

Write all files to the current directory.
