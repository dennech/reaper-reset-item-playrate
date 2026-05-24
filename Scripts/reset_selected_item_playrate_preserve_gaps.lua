-- @description Reset selected item playrate to 1.0 with unified ripple timing
-- @version 2.0.0
-- @author dennech
-- @about
--   Resets active take playrate to 1.0 for selected media items.
--   All selected items are treated as one global montage timeline.
--   Non-muted items create ripple shifts; muted items follow the shifts but do not create them.

local SCRIPT_NAME = "Reset selected item playrate to 1.0 with unified ripple timing"
local EPSILON = 0.000000001

local function show_message(text)
  reaper.ShowMessageBox(text, SCRIPT_NAME, 0)
end

local function scale_fade_length(value, playrate, max_length)
  if value and value > 0 then
    return math.min(value * playrate, max_length)
  end

  return value or 0
end

local function collect_selected_items()
  local selected_count = reaper.CountSelectedMediaItems(0)
  local items = {}
  local drivers = {}
  local skipped_without_take = 0
  local skipped_invalid_rate = 0

  for selected_index = 0, selected_count - 1 do
    local item = reaper.GetSelectedMediaItem(0, selected_index)
    local take = item and reaper.GetActiveTake(item)

    if not take then
      skipped_without_take = skipped_without_take + 1
    else
      local playrate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
      local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

      if not playrate or playrate <= EPSILON or not length or length < 0 then
        skipped_invalid_rate = skipped_invalid_rate + 1
      else
        local position = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local new_length = length * playrate
        local is_muted = reaper.GetMediaItemInfo_Value(item, "B_MUTE_ACTUAL") >= 0.5
        local data = {
          item = item,
          take = take,
          position = position,
          length = length,
          playrate = playrate,
          new_length = new_length,
          delta = new_length - length,
          is_muted = is_muted,
          fade_in = reaper.GetMediaItemInfo_Value(item, "D_FADEINLEN"),
          fade_out = reaper.GetMediaItemInfo_Value(item, "D_FADEOUTLEN"),
          auto_fade_in = reaper.GetMediaItemInfo_Value(item, "D_FADEINLEN_AUTO"),
          auto_fade_out = reaper.GetMediaItemInfo_Value(item, "D_FADEOUTLEN_AUTO"),
          selected_index = selected_index,
        }

        items[#items + 1] = data

        if not is_muted then
          drivers[#drivers + 1] = data
        end
      end
    end
  end

  table.sort(items, function(left, right)
    if math.abs(left.position - right.position) > EPSILON then
      return left.position < right.position
    end

    return left.selected_index < right.selected_index
  end)

  table.sort(drivers, function(left, right)
    if math.abs(left.position - right.position) > EPSILON then
      return left.position < right.position
    end

    return left.selected_index < right.selected_index
  end)

  return items, drivers, skipped_without_take, skipped_invalid_rate
end

local function apply_ripple_positions(items, drivers)
  local driver_index = 1
  local accumulated_delta = 0

  for _, data in ipairs(items) do
    while driver_index <= #drivers and drivers[driver_index].position < data.position - EPSILON do
      accumulated_delta = accumulated_delta + drivers[driver_index].delta
      driver_index = driver_index + 1
    end

    data.new_position = data.position + accumulated_delta
  end
end

local function apply_item_changes(data)
  reaper.SetMediaItemInfo_Value(data.item, "D_POSITION", data.new_position)
  reaper.SetMediaItemInfo_Value(data.item, "D_LENGTH", data.new_length)
  reaper.SetMediaItemInfo_Value(data.item, "D_FADEINLEN", scale_fade_length(data.fade_in, data.playrate, data.new_length))
  reaper.SetMediaItemInfo_Value(data.item, "D_FADEOUTLEN", scale_fade_length(data.fade_out, data.playrate, data.new_length))
  reaper.SetMediaItemInfo_Value(data.item, "D_FADEINLEN_AUTO", scale_fade_length(data.auto_fade_in, data.playrate, data.new_length))
  reaper.SetMediaItemInfo_Value(data.item, "D_FADEOUTLEN_AUTO", scale_fade_length(data.auto_fade_out, data.playrate, data.new_length))
  reaper.SetMediaItemTakeInfo_Value(data.take, "D_PLAYRATE", 1.0)
end

local function apply_changes(items, drivers)
  apply_ripple_positions(items, drivers)

  for _, data in ipairs(items) do
    apply_item_changes(data)
  end
end

local selected_count = reaper.CountSelectedMediaItems(0)
if selected_count == 0 then
  show_message("No selected media items.")
  return
end

local items, drivers, skipped_without_take, skipped_invalid_rate = collect_selected_items()
local processed_count = #items

if processed_count == 0 then
  show_message("No selected items with a valid active take playrate were found.")
  return
end

local ok, error_message

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

ok, error_message = xpcall(function()
  apply_changes(items, drivers)
end, debug.traceback)

reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock(SCRIPT_NAME, -1)

if not ok then
  reaper.ShowConsoleMsg(tostring(error_message) .. "\n")
  error(error_message)
end

if skipped_without_take > 0 or skipped_invalid_rate > 0 then
  show_message(
    "Done.\n\nProcessed items: "
      .. tostring(processed_count)
      .. "\nRipple driver items: "
      .. tostring(#drivers)
      .. "\nSkipped items without an active take: "
      .. tostring(skipped_without_take)
      .. "\nSkipped items with invalid playrate: "
      .. tostring(skipped_invalid_rate)
  )
end
