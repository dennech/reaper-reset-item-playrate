-- @description Create unnamed region from selected items
-- @version 1.0.0
-- @author dennech
-- @about
--   Creates one unnamed region spanning all selected media items.
--   The region starts at the earliest selected item start and ends at the latest selected item end.

local SCRIPT_NAME = "Create unnamed region from selected items"

local function show_message(text)
  reaper.ShowMessageBox(text, SCRIPT_NAME, 0)
end

local function get_selected_item_bounds()
  local selected_count = reaper.CountSelectedMediaItems(0)

  if selected_count == 0 then
    return nil
  end

  local region_start = math.huge
  local region_end = -math.huge

  for selected_index = 0, selected_count - 1 do
    local item = reaper.GetSelectedMediaItem(0, selected_index)
    if item then
      local position = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
      local item_end = position + length

      if position < region_start then
        region_start = position
      end

      if item_end > region_end then
        region_end = item_end
      end
    end
  end

  return region_start, region_end
end

local region_start, region_end = get_selected_item_bounds()

if not region_start then
  show_message("No selected media items.")
  return
end

if region_end <= region_start then
  show_message("Selected media items do not span a positive time range.")
  return
end

reaper.Undo_BeginBlock()
reaper.AddProjectMarker2(0, true, region_start, region_end, "", -1, 0)
reaper.UpdateArrange()
reaper.Undo_EndBlock(SCRIPT_NAME, -1)
