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

# Phone-width table cells: hyphenated ids and dates must not break at a hyphen, a timestamp
# may wrap between date and time, and a path wraps only after a slash.
def nowrap: "<span class=\"nw\">\(esc)</span>";
def stamp: split(" ") | map(nowrap) | join(" ");
def path_cell: esc | gsub("/"; "/<wbr>");

def caveats: [
  "Headless <code>claude -p</code> runs record no cost: the statusline that writes this data"
    + " does not run there.",
  "Subagent figures are partial, since fast-finishing subagents can be missed. They are never"
    + " added to a total.",
  "Quota is account-wide: usage from other machines and claude.ai counts against it but is not"
    + " recorded here.",
  "A new quota window is recorded only once a percentage changes, so a tile can show Reset"
    + " for a window that has already reopened.",
  "Each open session records quota, and one can report an older, lower figure than another"
    + " already did. A quota figure with a reset time is the highest recorded for its window, so"
    + " a genuine drop within a window would not show."
];

def level_label:
  if . == "red" then "well over pace"
  elif . == "yellow" then "over pace"
  elif . == "green" then "room to ramp"
  else "on pace"
  end;

# One window's tile. $t is the bash-formatted tile, $q the window's row from SQL.
def tile($window; $title):
  $tiles[$window] as $t
  | (.quota[$window] // {}) as $q
  | .generated_at as $as_of
  | "<div class=\"tile\"><h3>\($title)</h3>"
  + (if $t.state == "current" then
      "<p class=\"figure\">\($t.used | esc) used</p>"
      + "<p>Resets \($q.resets_local | esc), \($t.left | esc) left as of \($as_of | esc).</p>"
      + (if $t.pace == "" then ""
        else "<p class=\"pace level-\($t.level | esc)\">\($t.pace | esc) when last observed:"
          + " \($t.level | level_label).</p>"
        end)
    elif $t.state == "reset" then
      "<p class=\"figure\">Reset</p>"
      + "<p>Reset at \($q.resets_local | esc). No figure for the new window is recorded here.</p>"
      + "<p class=\"meta\">The highest figure recorded for that window was \($t.used | esc).</p>"
    elif $t.state == "unknown" then
      "<p class=\"figure\">\($t.used | esc) used</p><p>Reset time unknown.</p>"
    else
      "<p class=\"figure\">No data</p><p>No figure for this window is recorded here.</p>"
    end)
  + "</div>";

def dollar_note:
  if .kind == "subscription" then
    "These sessions ran on a subscription, so the dollars are an API-equivalent estimate, not"
    + " money spent."
  elif .kind == "api" then "Dollars are at API rates."
  else
    "$\(.subscription_usd | esc) from subscription sessions is an API-equivalent estimate, not"
    + " money spent; the other $\(.other_usd | esc) is at API rates."
  end;

def burn_tile($title; $figure; $detail):
  "<div class=\"tile\"><h3>\($title)</h3><p class=\"figure\">\($figure)</p><p>\($detail)</p></div>";

# Cost pace for a machine with no quota rows (Enterprise or API), the same tile row as the quota
# windows, longest window first. A figure that is not available arrives as an empty string,
# never null, and the tile says why instead.
def cost_pace:
  .cost as $c
  | $c.burn as $b
  | "<p class=\"meta\">No quota data on this machine, so this follows cost: this local calendar"
  + " month, and where it is heading at the recent daily rate. It counts only what this machine"
  + " recorded, so it is an estimate, not a bill. \($c | dollar_note)</p>"
  + "<div class=\"tiles\">"
  + burn_tile("Month to date"; "$\($b.mtd | esc)";
      "Local calendar month \($b.month | esc), through today.")
  + (if $b.state == "ready" then
      burn_tile("Daily rate"; "$\($b.rate | esc) a day";
        "Mean of the last \($b.rate_days | esc) complete days, not counting today.")
    else
      burn_tile("Daily rate"; "Not enough history";
        "Needs \($b.min_days | esc) complete days; \($b.rate_days | esc) so far.")
    end)
  + (if $b.state == "ready" then
      burn_tile("Projected month end"; "$\($b.projected | esc)";
        "By \($b.month_end | esc), if the rate holds. Today counts as at least one day at the"
        + " rate.")
    else
      burn_tile("Projected month end"; "Not enough history"; "A projection needs a daily rate.")
    end)
  + "</div>";

def quota_tiles:
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

# Quota rows pick the quota tiles; otherwise any cost picks the cost pace. Without a credit limit
# the cost view cannot say whether quota will run out, so its heading does not claim to.
def quota:
  if .quota_observed != 1 and .cost.burn.state != "none" then
    "<section><h2>How fast is cost building up?</h2>" + cost_pace + "</section>"
  else quota_tiles
  end;

# Burn-up chart geometry: a 640x260 viewBox with the plot inset for axis labels. Coordinates
# are rounded to one decimal, the only numbers jq prints itself.
def plot_x($day): (40 + ([[$day, 0] | max, 7] | min) / 7 * 580) * 10 | round / 10;
def plot_y($pct): (10 + (100 - ([[$pct, 0] | max, 100] | min)) / 100 * 220) * 10 | round / 10;

# Step-after: each figure holds until the next observed change, then the last one holds until
# quota was last observed. Points are a running maximum, so rows written for a 5h change and
# stale lower figures from another session repeat the last figure and drop out.
def step_path($points; $end_x):
  ($points
    | reduce .[] as $point ([];
        if length > 0 and .[-1][1] == $point[1] then . else . + [$point] end)) as $steps
  | ($steps | map([plot_x(.[0]), plot_y(.[1])])) as $p
  | "M\($p[0][0]),\($p[0][1])"
  + ([range(1; $p | length) as $i | "H\($p[$i][0])V\($p[$i][1])"] | join(""))
  + "H\(plot_x([$end_x, $steps[-1][0]] | max))";

# The current figure beside the line's end, the same rounding as the tile. Past 6 days it sits
# above the end instead, so it stays inside the plot.
def end_label($b; $used):
  ([$b.end_x // 0, $b.points[-1][0]] | max) as $x
  | plot_y($b.points[-1][1]) as $y
  | if $x > 6 then
      "<text class=\"end-label\" x=\"\(plot_x($x))\" y=\"\($y - 8)\" text-anchor=\"end\">"
      + "\($used | esc)</text>"
    else
      "<text class=\"end-label\" x=\"\(plot_x($x) + 6)\" y=\"\($y + 4)\">\($used | esc)</text>"
    end;

def burnup_axes:
  ([0, 25, 50, 75, 100] | map(plot_y(.) as $y
    | "<line class=\"grid\" x1=\"40\" x2=\"620\" y1=\"\($y)\" y2=\"\($y)\"/>"
    + "<text class=\"tick\" x=\"34\" y=\"\($y + 4)\" text-anchor=\"end\">\(.)%</text>")
    | join(""))
  + ([range(0; 8)] | map(plot_x(.) as $x
    | "<text class=\"tick\" x=\"\($x)\" y=\"248\" text-anchor=\"middle\">\(.)d</text>")
    | join(""));

def quota_burnup:
  if .quota_observed != 1 then ""
  else
    "<section><h2>How has 7-day usage built up this window?</h2>"
    + (if .burnup == null or (.burnup.points | length) == 0 then
        "<p>No open 7-day window is recorded, so there is nothing to chart.</p>"
      else
        "<p class=\"meta\">Days into the current window against the highest share used so far."
        + " Steps mark when this machine observed a change; the quota is account-wide.</p>"
        + "<svg class=\"chart\" viewBox=\"0 0 640 260\" role=\"img\""
        + " aria-labelledby=\"burnup-title burnup-desc\">"
        + "<title id=\"burnup-title\">7-day usage this window</title>"
        + "<desc id=\"burnup-desc\">A solid stepped line of the highest 7-day share used so far,"
        + " from the first observed figure to the last time quota was observed, against a dashed"
        + " even-pace diagonal from 0% to 100% over 7 days.</desc>"
        + burnup_axes
        + "<line class=\"even\" x1=\"\(plot_x(0))\" y1=\"\(plot_y(0))\" x2=\"\(plot_x(7))\""
        + " y2=\"\(plot_y(100))\"/>"
        + "<path class=\"used\" d=\"\(step_path(.burnup.points; .burnup.end_x // 0))\"/>"
        + end_label(.burnup; $tiles.seven_day.used)
        + "</svg>"
        + "<p class=\"meta\">Solid: share used. Dashed: even pace.</p>"
      end)
    + "</section>"
  end;

# Month-to-date cost chart for a machine with no quota rows: the same viewBox and left inset as
# the daily cost columns, with x as days into the local calendar month.
def month_x($day; $n): (56 + $day / $n * 564) * 10 | round / 10;
def month_y($usd; $max): (230 - $usd / $max * 220) * 10 | round / 10;

def month_axes($b):
  $b.chart as $ch
  | ([range(0; 5)] | map((230 - . * 55) as $y
      | "<line class=\"grid\" x1=\"56\" x2=\"620\" y1=\"\($y)\" y2=\"\($y)\"/>"
      + "<text class=\"tick\" x=\"50\" y=\"\($y + 4)\" text-anchor=\"end\">"
      + "\($ch.ticks[.] | esc)</text>") | join(""))
  + ([0, 7, 14, 21, 28] | map(month_x(.; $ch.days) as $x
      | "<text class=\"tick\" x=\"\($x)\" y=\"248\" text-anchor=\"middle\">\(.)d</text>")
    | join(""));

# The solid line runs from zero on the 1st through each day's running total, so its end is the
# month to date. The dashed line runs on from there to the projected month end.
def month_lines($b):
  $b.chart as $ch
  | ([[0, 0]] + $ch.points
    | map("\(month_x(.[0]; $ch.days)),\(month_y(.[1]; $ch.scale_max))")) as $pts
  | ($ch.points[-1]) as $last
  | "<path class=\"used\" d=\"M\($pts | join("L"))\"/>"
  + (if $b.state == "ready" then
      "<path class=\"proj\" d=\"M\(month_x($last[0]; $ch.days)),\(month_y($last[1]; $ch.scale_max))"
      + "L\(month_x($ch.days; $ch.days)),\(month_y($ch.projected_y; $ch.scale_max))\"/>"
    else "" end);

# The figure beside the line's end: the projection when there is one, else the month to date.
# Near the top of the plot it sits under the line so it stays inside the viewBox.
def month_end_label($b):
  $b.chart as $ch
  | (if $b.state == "ready" then {x: $ch.days, y: $ch.projected_y, text: $b.projected}
     else {x: $ch.points[-1][0], y: $ch.points[-1][1], text: $b.mtd} end) as $end
  | month_y($end.y; $ch.scale_max) as $y
  | "<text class=\"end-label\" x=\"\(month_x($end.x; $ch.days))\""
  + " y=\"\(if $y < 24 then $y + 18 else $y - 8 end)\" text-anchor=\"end\">"
  + "$\($end.text | esc)</text>";

def month_table($b):
  "<details><summary>Month figures</summary><table><thead><tr><th scope=\"col\">Day</th>"
  + "<th scope=\"col\">Cost</th><th scope=\"col\">Month to date</th></tr></thead><tbody>"
  + ($b.chart.rows | map("<tr><th scope=\"row\">\(.day | nowrap)</th><td>$\(.usd | esc)</td>"
      + "<td>$\(.cum | esc)</td></tr>") | join(""))
  + "</tbody></table></details>";

def month_desc($b):
  "A solid line of the cost so far this local calendar month, from the 1st to today, in US"
  + " dollars."
  + (if $b.state == "ready" then
      " A dashed line continues from there to a projected $\($b.projected | esc) on"
      + " \($b.month_end | esc), at the recent daily rate."
    else " No projection is drawn, because there is not yet a daily rate."
    end)
  + " The figures are in the table below.";

def cost_burnup:
  .cost as $c
  | $c.burn as $b
  | "<section><h2>How has cost built up this month?</h2>"
  + "<p class=\"meta\">Days into the local calendar month against the cost so far."
  + (if $b.state == "ready" then
      " The dashed line carries today's total to the projected month end at the daily rate."
    else " A projection is drawn once there is a daily rate."
    end)
  + " \($c | dollar_note)</p>"
  + "<svg class=\"chart\" viewBox=\"0 0 640 260\" role=\"img\""
  + " aria-labelledby=\"month-title month-desc\">"
  + "<title id=\"month-title\">Cost this month</title>"
  + "<desc id=\"month-desc\">\(month_desc($b))</desc>"
  + month_axes($b) + month_lines($b) + month_end_label($b)
  + "</svg>"
  + (if $b.state == "ready" then "<p class=\"meta\">Solid: cost so far. Dashed: projection.</p>"
     else "" end)
  + month_table($b)
  + "</section>";

# Quota rows pick the quota burn-up, as they pick the quota tiles; otherwise any cost picks the
# month-to-date chart.
def burnup:
  if .quota_observed != 1 and .cost.burn.state != "none" then cost_burnup else quota_burnup end;

# Daily cost columns: the same viewBox, with a wider left inset for dollar labels. Each day
# stacks its series bottom up in slot order, so Other sits on top. A segment above the first
# gives up its bottom 2 units to a surface gap, keeping the column's top at its true total.
def cost_x($i; $n): (56 + $i * 564 / $n) * 10 | round / 10;
def cost_h($usd; $max): ($usd / $max * 220) * 10 | round / 10;

def series_label:
  if .label == "Other" then "Other (" + (.members | map(esc) | join(", ")) + ")"
  else .label | esc
  end;

def capitalize: (.[0:1] | ascii_upcase) + .[1:];

# A dollar column header that matches the dollar note: $noun is "cost" or "estimate".
def dollar_header($noun):
  if .kind == "subscription" then "API-equivalent \($noun)"
  elif .kind == "api" then "\($noun | capitalize) at API rates"
  else $noun | capitalize
  end;

# Launches never add up, so their note names no amounts.
def launch_note:
  if .launch_kind == "subscription" then
    " Their sessions ran on a subscription, so these are API-equivalent estimates, not money"
    + " spent."
  elif .launch_kind == "api" then " Estimates are at API rates."
  elif .launch_kind == "mixed" then
    " Estimates from subscription sessions are API-equivalent, not money spent; the rest are at"
    + " API rates."
  else ""
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
        | (if .y < 230 then ([$h - 2, 0.5] | max) * 10 | round / 10 else $h end) as $drawn
        | .y = ((.y - $h) * 10 | round / 10)
        | .out += "<rect class=\"s\($cell[0])\" x=\"\(($x * 10 | round) / 10)\" y=\"\(.y)\""
          + " width=\"\($bar)\" height=\"\($drawn)\"><title>\($day.day | esc),"
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
      | "<tr><th scope=\"row\">\($day.day | nowrap)</th>"
      + ($c.series | map(.slot as $slot
          | ([$day.cells[] | select(.[0] == $slot)][0]) as $cell
          | "<td>" + (if $cell == null then "" else "$" + ($cell[2] | esc) end) + "</td>")
        | join(""))
      + "<td>$\($day.total | esc)</td></tr>") | join(""))
  + "</tbody></table></details>";

def cost:
  .cost as $c
  | "<section><h2>What did each day cost, by main-session model?</h2>"
  + (if ($c.days | length) == 0 then
      "<p>No cost is recorded for the last 31 days.</p>"
    else
      "<p class=\"meta\">One column per local day, for up to 31 days. Cost is booked to the"
      + " main-session model, including its subagents. \($c | dollar_note)</p>"
      + "<svg class=\"chart\" viewBox=\"0 0 640 260\" role=\"img\""
      + " aria-labelledby=\"cost-title cost-desc\">"
      + "<title id=\"cost-title\">Daily cost by model</title>"
      + "<desc id=\"cost-desc\">Stacked columns of each local day's cost in US dollars, one"
      + " color per model, from \($c.days[0].day | esc) to \($c.days[-1].day | esc)."
      + " \($c | dollar_note) The figures are in the table below.</desc>"
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
      "<p>No cost is recorded for the last 31 days.</p>"
    else
      ($c.projects | map(.usd) | max) as $max
      | "<p class=\"meta\">The same 31 days, by the project directory each snapshot reported."
      + " Paths under <code>/tmp</code>, <code>/private/tmp</code>, and <code>$TMPDIR</code>"
      + " count as Other. \($c | dollar_note)</p>"
      + "<table class=\"bars\"><thead><tr><th scope=\"col\" class=\"text\">Project</th>"
      + "<th scope=\"col\">Sessions</th><th scope=\"col\">\($c | dollar_header("cost"))</th>"
      + "<td aria-hidden=\"true\"></td></tr></thead><tbody>"
      + ($c.projects | map(
          "<tr><th scope=\"row\">\(.project | path_cell)</th><td>\(.sessions | esc)</td>"
          + "<td>\("$" + .total | nowrap)</td><td class=\"bar-cell\" aria-hidden=\"true\">"
          + "<span class=\"bar\" style=\"width: \((.usd / $max * 1000 | round) / 10)%\">"
          + "</span></td></tr>") | join(""))
      + "</tbody></table>"
    end)
  + "</section>";

def top_sessions:
  .cost as $c
  | "<section><h2>Which sessions cost the most?</h2>"
  + (if ($c.top_sessions | length) == 0 then
      "<p>No cost is recorded for the last 31 days.</p>"
    else
      "<p class=\"meta\">The costliest sessions in the same 31 days, counting only their cost"
      + " in those days. Model and project are where most of it went. \($c | dollar_note)</p>"
      + "<table><thead><tr><th scope=\"col\">Session</th><th scope=\"col\">Last active</th>"
      + "<th scope=\"col\" class=\"text\">Model</th><th scope=\"col\" class=\"text\">Project</th>"
      + "<th scope=\"col\">\($c | dollar_header("cost"))</th></tr></thead><tbody>"
      + ($c.top_sessions | map(
          "<tr><th scope=\"row\"><code title=\"\(.session_id | esc)\">"
          + "\(.session_id[0:8] | esc)</code></th>"
          + "<td>\(.last_active | stamp)</td><td class=\"text\">\(.model | nowrap)</td>"
          + "<td class=\"text\">\(.project | path_cell)</td><td>\("$" + .total | nowrap)</td>"
          + "</tr>")
        | join(""))
      + "</tbody></table>"
    end)
  + "</section>";

# Bars are widths relative to the costliest type; an unpriced type gets none.
def agent_types:
  .cost as $c
  | $c.agent_types as $t
  | "<section><h2>Which subagent types cost the most?</h2>"
  + "<p class=\"meta\">Partial: subagents that finish quickly can be missed. Each type's estimate"
  + " sums its priced launches in the same 31 days. Every estimate is already inside its"
  + " session's cost, so these figures are never added to a total." + ($c | launch_note) + "</p>"
  + (if ($t | length) == 0 then
      "<p>No subagent launch is recorded for the last 31 days.</p>"
    else
      ([$t[] | .usd // 0] | max) as $max
      | "<table class=\"bars\"><thead><tr><th scope=\"col\" class=\"text\">Agent type</th>"
      + "<th scope=\"col\">Launches</th><th scope=\"col\">Unpriced</th>"
      + "<th scope=\"col\">\({kind: $c.launch_kind} | dollar_header("estimate"))</th>"
      + "<td aria-hidden=\"true\"></td></tr></thead><tbody>"
      + ($t | map(
          "<tr><th scope=\"row\">\(.agent_type | nowrap)</th><td>\(.launches | esc)</td>"
          + "<td>\(.unpriced | esc)</td><td>\(.estimate | nowrap)</td>"
          + "<td class=\"bar-cell\" aria-hidden=\"true\">"
          + (if .usd == null or $max == 0 then ""
            else "<span class=\"bar\" style=\"width: \((.usd / $max * 1000 | round) / 10)%\">"
              + "</span>"
            end)
          + "</td></tr>") | join(""))
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

(header + "<main>" + quota + burnup + cost + projects + top_sessions + agent_types + "</main>"
  + footer) as $body
| ($tmpl | split("@@BODY@@")) as $parts
| if ($parts | length) != 2 then error("report.html.tmpl needs exactly one @@BODY@@")
  else $parts[0] + $body + $parts[1]
  end
