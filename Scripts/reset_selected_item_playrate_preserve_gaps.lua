-- @description Reset selected item playrate to 1.0 while preserving gaps
-- @version 1.0.0
-- @author dennech
-- @about
--   Resets active take playrate to 1.0 for selected media items.
--   Selected items are processed independently per track.
--   Original gaps and overlaps between selected items on the same track are preserved.

local SCRIPT_NAME = "Reset selected item playrate to 1.0 while preserving gaps"
local EPSILON = 0.000000001

local function show_message(text)
  reaper.ShowMessageBox(text, SCRIPT_NAME, 0)
end

local function sorted_track_groups()
  local selected_count = reaper.CountSelectedMediaItems(0)
  local groups_by_track = {}
  local track_order = {}
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
        local track = reaper.GetMediaItem_Track(item)
        if not groups_by_track[track] then
          groups_by_track[track] = {}
          track_order[#track_order + 1] = track
        end

        local group = groups_by_track[track]
        group[#group + 1] = {
          item = item,
          take = take,
          position = reaper.GetMediaItemInfo_Value(item, "D_POSITION"),
          length = length,
          playrate = playrate,
          selected_index = selected_index,
        }
      end
    end
  end

  for _, track in ipairs(track_order) do
    table.sort(groups_by_track[track], function(left, right)
      if math.abs(left.position - right.position) > EPSILON then
        return left.position < right.position
      end

      return left.selected_index < right.selected_index
    end)
  end

  return track_order, groups_by_track, skipped_without_take, skipped_invalid_rate
end

local function apply_group(group)
  local accumulated_delta = 0

  for _, data in ipairs(group) do
    local new_position = data.position + accumulated_delta
    local new_length = data.length * data.playrate

    reaper.SetMediaItemInfo_Value(data.item, "D_POSITION", new_position)
    reaper.SetMediaItemInfo_Value(data.item, "D_LENGTH", new_length)
    reaper.SetMediaItemTakeInfo_Value(data.take, "D_PLAYRATE", 1.0)

    accumulated_delta = accumulated_delta + (new_length - data.length)
  end
end

local function apply_changes(track_order, groups_by_track)
  for _, track in ipairs(track_order) do
    apply_group(groups_by_track[track])
  end
end

local selected_count = reaper.CountSelectedMediaItems(0)
if selected_count == 0 then
  show_message("No selected media items.")
  return
end

local track_order, groups_by_track, skipped_without_take, skipped_invalid_rate = sorted_track_groups()
local processed_count = 0

for _, track in ipairs(track_order) do
  processed_count = processed_count + #groups_by_track[track]
end

if processed_count == 0 then
  show_message("No selected items with a valid active take playrate were found.")
  return
end

local ok, error_message

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

ok, error_message = xpcall(function()
  apply_changes(track_order, groups_by_track)
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
      .. "\nSkipped items without an active take: "
      .. tostring(skipped_without_take)
      .. "\nSkipped items with invalid playrate: "
      .. tostring(skipped_invalid_rate)
  )
end
