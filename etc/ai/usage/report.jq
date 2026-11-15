# Renders the usage report blob (stdin, from report.sh) into the page template ($tmpl).
# Targets jq 1.6: if/then/else/end only, no pick/abs/trim, and @html only after a null check,
# since null renders as the text "null".

# Display numbers arrive as strings from SQL or bash: jq 1.7+ prints a raw 42.0 as "42.0"
# where 1.6 prints "42", so a number reaching a text sink is an error, not a format.
def esc:
  if . == null then ""
  elif type == "string" then @html
  else error("esc takes a string or null, got \(type)")
  end;

def caveats: [
  "Headless <code>claude -p</code> runs record no cost: the statusline that writes this data"
    + " does not run there.",
  "Subagent figures are partial, since fast-finishing subagents can be missed. They are never"
    + " added to a total.",
  "Quota is account-wide: usage from other machines and claude.ai counts against it but is not"
    + " recorded here.",
  "A new 5-hour window that opens at the same percentage as the last one leaves no boundary row."
];

def header:
  "<header><h1>AI usage</h1><p class=\"meta\">Generated \(.generated_at | esc) "
  + "(\(.utc_offset | esc)). All times are local.</p></header>";

def recorded:
  "<section><h2>What is recorded on this machine?</h2><p>\(.sessions | esc). "
  + "Models they last ran on, most recent first: "
  + (if (.models | length) == 0 then "none" else (.models | map(esc) | join(", ")) end)
  + ".</p></section>";

def footer:
  "<footer><h2>Caveats</h2><ul>"
  + (caveats | map("<li>" + . + "</li>") | join(""))
  + "</ul></footer>";

(header + "<main>" + recorded + "</main>" + footer) as $body
| ($tmpl | split("@@BODY@@")) as $parts
| if ($parts | length) != 2 then error("report.html.tmpl needs exactly one @@BODY@@")
  else $parts[0] + $body + $parts[1]
  end
