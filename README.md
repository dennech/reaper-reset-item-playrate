# REAPER Reset Item Playrate

Lua ReaScript for REAPER that resets selected media item take playrate to `1.0` while preserving the edit structure.

This is useful for edited voiceover sessions where narration has already been cut into many items, pauses and overlaps have been shaped by hand, and different items may have different playback rates. After running the script, every processed active take is reset to normal speed, the items become longer or shorter as needed, and the selected sequence expands while keeping the original gaps, overlaps, and order.

## What It Does

- Processes only selected media items.
- Handles each track independently.
- For every selected item with an active take:
  - reads the original item position, length, and take playrate;
  - calculates the new length as `current length * current playrate`;
  - sets the active take playrate to `1.0`;
  - shifts later selected items on the same track by the accumulated length difference.
- Preserves gaps, overlaps, item order, take start offset, pitch preservation settings, and other take/item settings.
- Skips items without an active take or with an invalid playrate.
- Wraps the whole operation in a single REAPER undo step.

## Example

Before:

```text
Item A: playrate 1.50, length 2.0 sec
Gap: 0.4 sec
Item B: playrate 1.25, length 3.0 sec
```

After:

```text
Item A: playrate 1.00, length 3.0 sec
Gap: 0.4 sec
Item B: playrate 1.00, length 3.75 sec
```

The gap between items stays the same, but the whole selected sequence becomes longer.

## Installation

1. Download [`Scripts/reset_selected_item_playrate_preserve_gaps.lua`](Scripts/reset_selected_item_playrate_preserve_gaps.lua).
2. Open REAPER.
3. Go to `Actions` -> `Show action list...`.
4. Click `New Action...` -> `Load ReaScript...`.
5. Select the downloaded `.lua` file.
6. Optionally assign a shortcut from the Action List.

## Usage

1. Select the items you want to process on one or more tracks.
2. Run the action `Reset selected item playrate to 1.0 while preserving gaps`.
3. Check the result.
4. Use REAPER's normal `Undo` command if you need to revert the operation.

## Important Notes

- The script moves only selected items. Unselected items later on the timeline are not moved.
- If unselected items sit after or near the selected sequence, the expanded narration may overlap them.
- The script is designed for media items with an active take. Empty items and other items without an active take are skipped.
- Multi-track processing is independent: each track expands according to its own selected item sequence.

## Suggested Checks

- Single track: select items with playrates such as `1.25`, `1.5`, and `1.0`, then verify that all processed takes become `1.0` and the gaps are preserved.
- Multiple tracks: select items on two tracks and verify that each track expands independently.
- Overlap or crossfade: verify that a negative gap between adjacent selected items is preserved.
- Item without an active take: verify that the script does not fail and reports skipped items.
- Undo: run the script and undo it with one REAPER undo action.

## License

MIT. You can use, modify, and distribute this script freely.
