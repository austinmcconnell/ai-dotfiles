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

# Burn-up chart geometry: a 640x260 viewBox with the plot inset for axis labels. Coordinates
# are rounded to one decimal, the only numbers jq prints itself.
def plot_x($day): (40 + ([[$day, 0] | max, 7] | min) / 7 * 580) * 10 | round / 10;
def plot_y($pct): (10 + (100 - ([[$pct, 0] | max, 100] | min)) / 100 * 220) * 10 | round / 10;

# Step-after: each figure holds until the next observed change, then the last one holds until
# quota was last observed. Rows written for a 5h change repeat the 7d figure, so they drop out.
def step_path($points; $end_x):
  ($points
    | reduce .[] as $point ([];
        if length > 0 and .[-1][1] == $point[1] then . else . + [$point] end)
    | map([plot_x(.[0]), plot_y(.[1])])) as $p
  | "M\($p[0][0]),\($p[0][1])"
  + ([range(1; $p | length) as $i | "H\($p[$i][0])V\($p[$i][1])"] | join(""))
  + "H\(plot_x([$end_x, $points[-1][0]] | max))";

def burnup_axes:
  ([0, 25, 50, 75, 100] | map(plot_y(.) as $y
    | "<line class=\"grid\" x1=\"40\" x2=\"620\" y1=\"\($y)\" y2=\"\($y)\"/>"
    + "<text class=\"tick\" x=\"34\" y=\"\($y + 4)\" text-anchor=\"end\">\(.)%</text>")
    | join(""))
  + ([range(0; 8)] | map(plot_x(.) as $x
    | "<text class=\"tick\" x=\"\($x)\" y=\"248\" text-anchor=\"middle\">\(.)d</text>")
    | join(""));

def burnup:
  if .quota_observed != 1 then ""
  else
    "<section><h2>How has 7-day usage built up this window?</h2>"
    + (if .burnup == null or (.burnup.points | length) == 0 then
        "<p>No open 7-day window is recorded, so there is nothing to chart.</p>"
      else
        "<p class=\"meta\">Days into the current window against the share used. Steps mark when"
        + " this machine observed a change; the quota is account-wide.</p>"
        + "<svg class=\"chart\" viewBox=\"0 0 640 260\" role=\"img\""
        + " aria-labelledby=\"burnup-title burnup-desc\">"
        + "<title id=\"burnup-title\">7-day usage this window</title>"
        + "<desc id=\"burnup-desc\">A solid stepped line of the 7-day share used, from the first"
        + " observed figure to the last time quota was observed, against a dashed even-pace"
        + " diagonal from 0% to 100% over 7 days.</desc>"
        + burnup_axes
        + "<line class=\"even\" x1=\"\(plot_x(0))\" y1=\"\(plot_y(0))\" x2=\"\(plot_x(7))\""
        + " y2=\"\(plot_y(100))\"/>"
        + "<path class=\"used\" d=\"\(step_path(.burnup.points; .burnup.end_x // 0))\"/>"
        + "</svg>"
        + "<p class=\"meta\">Solid: share used. Dashed: even pace.</p>"
      end)
    + "</section>"
  end;

# Daily cost columns: the same viewBox, with a wider left inset for dollar labels. Each day
# stacks its series bottom up in slot order.
def cost_x($i; $n): (56 + $i * 564 / $n) * 10 | round / 10;
def cost_h($usd; $max): ($usd / $max * 220) * 10 | round / 10;

def series_label:
  if .label == "Other" then "Other (" + (.members | map(esc) | join(", ")) + ")"
  else .label | esc
  end;

def dollar_note:
  if .kind == "subscription" then
    "These sessions ran on a subscription, so the dollars are an API-equivalent estimate, not"
    + " money spent."
  elif .kind == "api" then "Dollars are at API rates."
  else
    "$\(.subscription_usd | esc) from subscription sessions is an API-equivalent estimate, not"
    + " money spent; the other $\(.other_usd | esc) is at API rates."
  end;

def cost_columns($c):
  ($c.days | length) as $n
  | ([$n, 1] | max) as $n
  | ((564 / $n * 0.7) * 10 | round / 10) as $bar
  | ($c.series | map({key: (.slot | tostring), value: .label}) | from_entries) as $names
  | [range(0; $c.days | length) as $i | $c.days[$i] as $day
    | (cost_x($i; $n) + (564 / $n - $bar) / 2) as $x
    | reduce $day.cells[] as $cell ({y: 230, out: ""};
        cost_h($cell[1]; $c.scale_max) as $h
        | .y = ((.y - $h) * 10 | round / 10)
        | .out += "<rect class=\"s\($cell[0])\" x=\"\(($x * 10 | round) / 10)\" y=\"\(.y)\""
          + " width=\"\($bar)\" height=\"\($h)\"><title>\($day.day | esc),"
          + " \($names[$cell[0] | tostring] | esc): $\($cell[2] | esc)</title></rect>")
    | .out]
  | join("");

def cost_chart($c):
  ($c.days | length) as $n
  | ([range(0; 5)] | map((230 - . * 55) as $y
      | "<line class=\"grid\" x1=\"56\" x2=\"620\" y1=\"\($y)\" y2=\"\($y)\"/>"
      + "<text class=\"tick\" x=\"50\" y=\"\($y + 4)\" text-anchor=\"end\">"
      + "\($c.ticks[.] | esc)</text>") | join(""))
  + ([range(0; $n) | select(($n - 1 - .) % 7 == 0)] | map(
      "<text class=\"tick\" x=\"\(cost_x(. + 0.5; $n))\" y=\"248\" text-anchor=\"middle\">"
      + "\($c.days[.].label | esc)</text>") | join(""))
  + cost_columns($c);

def cost_legend($c):
  "<ul class=\"legend\">"
  + ($c.series | map("<li><span class=\"swatch s\(.slot)\"></span>\(series_label):"
      + " $\(.total | esc)</li>") | join(""))
  + "</ul>";

def cost_table($c):
  "<details><summary>Daily figures</summary><table><thead><tr><th scope=\"col\">Day</th>"
  + ($c.series | map("<th scope=\"col\">\(.label | esc)</th>") | join(""))
  + "<th scope=\"col\">Total</th></tr></thead><tbody>"
  + ($c.days | map(. as $day
      | "<tr><th scope=\"row\">\($day.day | esc)</th>"
      + ($c.series | map(.slot as $slot
          | ([$day.cells[] | select(.[0] == $slot)][0]) as $cell
          | "<td>" + (if $cell == null then "" else "$" + ($cell[2] | esc) end) + "</td>")
        | join(""))
      + "<td>$\($day.total | esc)</td></tr>") | join(""))
  + "</tbody></table></details>";

def cost:
  .cost as $c
  | "<section><h2>What did each day cost, by model?</h2>"
  + (if ($c.days | length) == 0 then
      "<p>No cost is recorded for the last 30 days.</p>"
    else
      "<p class=\"meta\">One column per local day, for up to 30 days. Cost is booked to the"
      + " main-session model, including its subagents. \($c | dollar_note)</p>"
      + "<svg class=\"chart\" viewBox=\"0 0 640 260\" role=\"img\""
      + " aria-labelledby=\"cost-title cost-desc\">"
      + "<title id=\"cost-title\">Daily cost by model</title>"
      + "<desc id=\"cost-desc\">Stacked columns of each local day's cost in US dollars at API"
      + " rates, one color per model, from \($c.days[0].day | esc) to"
      + " \($c.days[-1].day | esc). The figures are in the table below.</desc>"
      + cost_chart($c)
      + "</svg>"
      + cost_legend($c)
      + cost_table($c)
    end)
  + "</section>";

# Bars are widths relative to the costliest row, set inline: the CSP allows inline styles.
def projects:
  .cost as $c
  | "<section><h2>Which projects is the cost going to?</h2>"
  + (if ($c.projects | length) == 0 then
      "<p>No cost is recorded for the last 30 days.</p>"
    else
      ($c.projects | map(.usd) | max) as $max
      | "<p class=\"meta\">The same 30 days, by the project directory each snapshot reported."
      + " Paths under <code>/tmp</code>, <code>/private/tmp</code>, and <code>$TMPDIR</code>"
      + " count as Other. \($c | dollar_note)</p>"
      + "<table class=\"projects\"><thead><tr><th scope=\"col\">Project</th>"
      + "<th scope=\"col\">Sessions</th><th scope=\"col\">Cost at API rates</th>"
      + "<td aria-hidden=\"true\"></td></tr></thead><tbody>"
      + ($c.projects | map(
          "<tr><th scope=\"row\">\(.project | esc)</th><td>\(.sessions | esc)</td>"
          + "<td>$\(.total | esc)</td><td class=\"bar-cell\" aria-hidden=\"true\">"
          + "<span class=\"bar\" style=\"width: \((.usd / $max * 1000 | round) / 10)%\">"
          + "</span></td></tr>") | join(""))
      + "</tbody></table>"
    end)
  + "</section>";

def header:
  "<header><h1>AI usage</h1><p class=\"meta\">Generated \(.generated_at | esc) "
  + "(\(.utc_offset | esc)). All times are local.</p></header>";

def footer:
  "<footer><h2>Caveats</h2><ul>"
  + (caveats | map("<li>" + . + "</li>") | join(""))
  + "</ul></footer>";

(header + "<main>" + quota + burnup + cost + projects + "</main>" + footer) as $body
| ($tmpl | split("@@BODY@@")) as $parts
| if ($parts | length) != 2 then error("report.html.tmpl needs exactly one @@BODY@@")
  else $parts[0] + $body + $parts[1]
  end
