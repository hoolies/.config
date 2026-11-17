-- Draw a charging bolt on the battery bar. Text layout is untouched.
require("cairo")

-- Matches conky.config: border_inner_margin 5 + border_width 2.
local text_start = 7
-- DejaVu Sans Mono / Hack Nerd Font Mono at size 14, 96 dpi.
local cell = 11
local ascent = 18
local line_h = 23
-- Uptime, then kernel. Comment lines are not drawn.
local lines_before = 2
local bar_offset = 1400
local bar_w = 75
local bar_h = 11

local function trim(value)
    return (tostring(value):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function bolt(cr, cx, top, height)
    -- Wider than the bar is tall, so the zigzag stays readable at 11px.
    local width = 18
    local x0 = math.floor(cx - width / 2 + 0.5)
    local y0 = math.floor(top + 0.5)
    local function at(nx, ny)
        return x0 + math.floor(nx * (width - 1) + 0.5), y0 + math.floor(ny * (height - 1) + 0.5)
    end
    local pts = {
        { 0.62, 0.00 },
        { 0.18, 0.00 },
        { 0.00, 0.55 },
        { 0.40, 0.42 },
        { 0.16, 1.00 },
        { 0.52, 1.00 },
        { 1.00, 0.38 },
        { 0.58, 0.52 },
    }
    cairo_set_antialias(cr, 1)
    local x1, y1 = at(pts[1][1], pts[1][2])
    cairo_move_to(cr, x1, y1)
    for i = 2, #pts do
        local px, py = at(pts[i][1], pts[i][2])
        cairo_line_to(cr, px, py)
    end
    cairo_close_path(cr)
    -- Dark on the bright bar, so the bolt stays visible.
    cairo_set_source_rgba(cr, 0.02, 0.05, 0.08, 1)
    cairo_fill(cr)
end

function conky_battery_bolt()
    local surface = conky_surface()
    if surface == nil then
        return
    end
    local status = trim(conky_parse("${battery_status BAT0}")):lower()
    if status ~= "charging" then
        return
    end
    local percent = trim(conky_parse("${battery_percent BAT0}"))
    if percent == "" then
        return
    end

    -- "Battery:  " is 10 cells, then the digits, then "%  ".
    local prefix = (10 + #percent + 3) * cell
    local bar_x = text_start + bar_offset + prefix
    local baseline = text_start + lines_before * line_h + ascent
    -- battery_bar is centered on the text line. See draw_each_line_inner.
    local bar_top = baseline - (ascent / 2) - 1 - (math.floor(bar_h / 2) - 1)

    local cr = cairo_create(surface)
    bolt(cr, bar_x + bar_w / 2, bar_top, bar_h)
    cairo_destroy(cr)
end

-- Right-align a CPU percentage in three digits: "  5%", " 50%", "100%".
-- Pass 0 for the overall CPU.
function conky_cpup(which)
    local query = "${cpu}"
    if which ~= nil and which ~= "" and which ~= "0" then
        query = "${cpu cpu" .. which .. "}"
    end
    local number = tonumber(trim(conky_parse(query)))
    if number == nil then
        return "  0%"
    end
    return string.format("%3d%%", number)
end
