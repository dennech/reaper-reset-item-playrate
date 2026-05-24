-- @description Increase selected item gaps with unified montage timing
-- @version 1.0.0
-- @author dennech
-- @about
--   Increases positive gaps between selected non-muted media items.
--   All selected items are treated as one global montage timeline.
--   Muted selected items follow the expanded timing but do not define gaps.

local SCRIPT_NAME = "Increase selected item gaps with unified montage timing"
local EPSILON = 0.000000001
local FIELD_SEPARATOR = "|"

local function show_message(text)
  reaper.ShowMessageBox(text, SCRIPT_NAME, 0)
end

local function trim(text)
  return tostring(text or ""):match("^%s*(.-)%s*$")
end

local function parse_number(text)
  local normalized = trim(text):gsub(",", ".")
  return tonumber(normalized)
end

local function split_fields(text)
  local fields = {}
  local position = 1

  while position <= #text + 1 do
    local next_separator = text:find(FIELD_SEPARATOR, position, true)
    if next_separator then
      fields[#fields + 1] = text:sub(position, next_separator - 1)
      position = next_separator + 1
    else
      fields[#fields + 1] = text:sub(position)
      break
    end
  end

  return fields
end

local function read_parameters()
  local ok, values = reaper.GetUserInputs(
    SCRIPT_NAME,
    2,
    "separator=|,Gap increase %,Add seconds",
    "20|0"
  )

  if not ok then
    return nil
  end

  local fields = split_fields(values)
  local percent = parse_number(fields[1])
  local add_seconds = parse_number(fields[2])

  if not percent or not add_seconds then
    show_message("Please enter valid numeric values.")
    return nil
  end

  if percent < 0 or add_seconds < 0 then
    show_message("Gap increase values cannot be negative.")
    return nil
  end

  if percent <= EPSILON and add_seconds <= EPSILON then
    show_message("No gap increase requested.")
    return nil
  end

  return percent, add_seconds
end

local function collect_selected_items()
  local selected_count = reaper.CountSelectedMediaItems(0)
  local items = {}
  local drivers = {}

  for selected_index = 0, selected_count - 1 do
    local item = reaper.GetSelectedMediaItem(0, selected_index)
    if item then
      local position = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
      local is_muted = reaper.GetMediaItemInfo_Value(item, "B_MUTE_ACTUAL") >= 0.5
      local data = {
        item = item,
        position = position,
        length = length,
        end_position = position + length,
        is_muted = is_muted,
        selected_index = selected_index,
      }

      items[#items + 1] = data

      if not is_muted then
        drivers[#drivers + 1] = data
      end
    end
  end

  local function sort_by_position(left, right)
    if math.abs(left.position - right.position) > EPSILON then
      return left.position < right.position
    end

    return left.selected_index < right.selected_index
  end

  table.sort(items, sort_by_position)
  table.sort(drivers, sort_by_position)

  return items, drivers
end

local function build_gap_segments(drivers, percent, add_seconds)
  local segments = {}

  if #drivers < 2 then
    return segments
  end

  local frontier = drivers[1].end_position

  for index = 2, #drivers do
    local driver = drivers[index]

    if driver.position > frontier + EPSILON then
      local gap_start = frontier
      local gap_end = driver.position
      local gap_length = gap_end - gap_start
      local extra = gap_length * (percent / 100) + add_seconds

      if extra > EPSILON then
        segments[#segments + 1] = {
          start_position = gap_start,
          end_position = gap_end,
          length = gap_length,
          extra = extra,
        }
      end
    end

    if driver.end_position > frontier then
      frontier = driver.end_position
    end
  end

  return segments
end

local function clamp(value, minimum, maximum)
  if value < minimum then
    return minimum
  end

  if value > maximum then
    return maximum
  end

  return value
end

local function map_position(position, segments)
  local accumulated_extra = 0

  for _, segment in ipairs(segments) do
    if position < segment.start_position - EPSILON then
      return position + accumulated_extra
    end

    if position <= segment.end_position + EPSILON then
      local ratio = 0

      if segment.length > EPSILON then
        ratio = clamp((position - segment.start_position) / segment.length, 0, 1)
      end

      return position + accumulated_extra + segment.extra * ratio
    end

    accumulated_extra = accumulated_extra + segment.extra
  end

  return position + accumulated_extra
end

local function apply_gap_expansion(items, segments)
  for _, data in ipairs(items) do
    local new_position = map_position(data.position, segments)
    reaper.SetMediaItemInfo_Value(data.item, "D_POSITION", new_position)
  end
end

local selected_count = reaper.CountSelectedMediaItems(0)
if selected_count == 0 then
  show_message("No selected media items.")
  return
end

local percent, add_seconds = read_parameters()
if not percent then
  return
end

local items, drivers = collect_selected_items()

if #drivers == 0 then
  show_message("No non-muted selected items were found to define montage gaps.")
  return
end

local segments = build_gap_segments(drivers, percent, add_seconds)

if #segments == 0 then
  show_message("No positive gaps were found between non-muted selected items.")
  return
end

local ok, error_message

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

ok, error_message = xpcall(function()
  apply_gap_expansion(items, segments)
end, debug.traceback)

reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock(SCRIPT_NAME, -1)

if not ok then
  reaper.ShowConsoleMsg(tostring(error_message) .. "\n")
  error(error_message)
end
