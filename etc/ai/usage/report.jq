# Renders the usage report blob (stdin, from report.sh) into the page template ($tmpl), with
# the quota tiles ($tiles) that report.sh computes in bash.
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

def level_label:
  if . == "red" then "well over pace"
  elif . == "yellow" then "over pace"
  elif . == "green" then "room to ramp"
  else "on pace"
  end;

# One window's tile. $t is the bash-formatted tile, $q the window's newest row from SQL.
def tile($window; $title):
  $tiles[$window] as $t
  | (.quota[$window] // {}) as $q
  | .generated_at as $as_of
  | "<div class=\"tile\"><h3>\($title)</h3>"
  + (if $t.state == "current" then
      "<p class=\"figure\">\($t.used | esc) used</p>"
      + "<p>Resets \($q.resets_local | esc), \($t.left | esc) left as of \($as_of | esc).</p>"
      + (if $t.pace == "" then ""
        else "<p class=\"pace level-\($t.level | esc)\">\($t.pace | esc) points against an even"
          + " pace when last observed: \($t.level | level_label).</p>"
        end)
    elif $t.state == "reset" then
      "<p class=\"figure\">Reset</p>"
      + "<p>Reset at \($q.resets_local | esc). No figure for the new window is recorded here.</p>"
      + "<p class=\"meta\">The last recorded figure before the reset was \($t.used | esc).</p>"
    elif $t.state == "unknown" then
      "<p class=\"figure\">\($t.used | esc) used</p><p>Reset time unknown.</p>"
    else
      "<p class=\"figure\">No data</p><p>No figure for this window is recorded here.</p>"
    end)
  + "</div>";

def quota:
  "<section><h2>Am I on pace to run out of quota?</h2>"
  + (if .quota_observed == 1 then
      "<p class=\"meta\">Quota observed on this machine, most recently"
      + " \(.last_observed | esc). It is account-wide.</p>"
      + "<div class=\"tiles\">" + tile("seven_day"; "7-day window")
      + tile("five_hour"; "5-hour window") + "</div>"
    else
      "<p>No quota data on this machine (Enterprise credits and API usage are not tracked"
      + " here).</p>"
    end)
  + "</section>";

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

(header + "<main>" + quota + recorded + "</main>" + footer) as $body
| ($tmpl | split("@@BODY@@")) as $parts
| if ($parts | length) != 2 then error("report.html.tmpl needs exactly one @@BODY@@")
  else $parts[0] + $body + $parts[1]
  end
