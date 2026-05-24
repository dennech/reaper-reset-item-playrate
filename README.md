# REAPER Voiceover Montage ReaScripts

Lua ReaScripts for REAPER that help reshape edited voiceover montage across one or more tracks.

These scripts are useful for edited narration sessions where one read is spread across several tracks. They treat selected items as one montage timeline, similar in spirit to ripple editing across selected material.

## Available Scripts

- [`reset_selected_item_playrate_preserve_gaps.lua`](Scripts/reset_selected_item_playrate_preserve_gaps.lua): resets selected item take playrate to `1.0` while preserving global edit timing.
- [`increase_selected_item_gaps_unified.lua`](Scripts/increase_selected_item_gaps_unified.lua): increases pauses between selected non-muted items to make speech feel more measured.

## Reset Playrate Script

## What It Does

- Processes selected media items across all tracks as one global timeline.
- Uses non-muted selected items as ripple drivers.
- Moves muted selected items with the ripple, resets their playrate, and resizes them, but muted items do not move later items.
- For every selected item with an active take:
  - reads the original item position, length, playrate, mute state, and fade lengths;
  - calculates the new length as `current length * current playrate`;
  - sets the active take playrate to `1.0`;
  - scales manual and auto fade lengths by the same playrate;
  - shifts the item by the accumulated length changes from earlier non-muted selected items.
- Keeps take start offset, pitch preservation settings, fade shapes, fade curves, and other take/item settings unchanged.
- Skips items without an active take or with an invalid playrate.
- Wraps the whole operation in a single REAPER undo step.

## Example

Before:

```text
Track 3 / Item A: non-muted, playrate 1.50, start 0.0 sec, length 2.0 sec
Track 1 / Item B: non-muted, playrate 1.25, start 2.4 sec, length 3.0 sec
Track 2 / Item C: muted,     playrate 1.40, start 2.7 sec, length 1.0 sec
```

After:

```text
Track 3 / Item A: non-muted, playrate 1.00, start 0.0 sec, length 3.0 sec
Track 1 / Item B: non-muted, playrate 1.00, start 3.4 sec, length 3.75 sec
Track 2 / Item C: muted,     playrate 1.00, start 3.7 sec, length 1.4 sec
```

Item A became 1.0 sec longer, so later selected items on all tracks moved 1.0 sec later. Item C is muted, so it follows the ripple and is resized, but its own length change does not shift anything else.

## Installation

1. Download the script you want from the [`Scripts`](Scripts) folder.
2. Open REAPER.
3. Go to `Actions` -> `Show action list...`.
4. Click `New Action...` -> `Load ReaScript...`.
5. Select the downloaded `.lua` file.
6. Optionally assign a shortcut from the Action List.

## Usage

1. Select the edited items you want to process on one or more tracks.
2. Run the action `Reset selected item playrate to 1.0 with unified ripple timing`.
3. Check the result.
4. Use REAPER's normal `Undo` command if you need to revert the operation.

## Important Notes

- Only selected items are moved. Unselected items later on the timeline are not moved.
- Muted selected items are followers only: they reset to `1.0`, resize, and move with earlier non-muted items, but they do not create ripple shifts.
- Non-muted selected items with the same start time do not shift each other; each contributes its own length change to later selected items.
- Overlaps and crossfades between sequential non-muted items are preserved as timeline relationships, and fade lengths are scaled with each item's playrate.
- The script does not try to detect special choir or parallel-performance groups. It follows the selected non-muted items in start-time order.
- The script is designed for media items with an active take. Empty items and other items without an active take are skipped.

## Suggested Checks

- Single track: select non-muted items with playrates such as `1.25`, `1.5`, and `1.0`, then verify that processed takes become `1.0` and global gaps are preserved.
- Multiple tracks: place an earlier non-muted item on track 3 and a later selected item on track 1; verify that the later item moves when the earlier item expands.
- Muted follower: place a muted selected item after a non-muted item; verify that it moves and resets to `1.0`, but does not shift later items because of its own length change.
- Muted-only selection: verify that selected muted items reset/stretch in place with no ripple shift.
- Crossfade or overlap: verify that an overlap between sequential non-muted items keeps the same timeline relationship, with fade lengths scaled.
- Same-start non-muted items: verify that same-start items stay aligned and only affect later-start items.
- Undo: run the script and undo it with one REAPER undo action.

## Increase Gaps Script

[`increase_selected_item_gaps_unified.lua`](Scripts/increase_selected_item_gaps_unified.lua) makes edited speech more measured by increasing positive pauses between selected non-muted items across all selected tracks.

When launched, it opens a small REAPER parameter window:

- `Gap increase %`: proportional pause increase, default `20`.
- `Add seconds`: fixed time added to every detected pause, default `0`.

Both values are applied together:

```text
extra gap = original gap * percent / 100 + add seconds
```

Examples:

- `20%` and `0 sec`: a 1.0 sec pause becomes 1.2 sec.
- `0%` and `0.15 sec`: a 1.0 sec pause becomes 1.15 sec.
- `20%` and `0.1 sec`: a 1.0 sec pause becomes 1.3 sec.

### Gap Expander Behavior

- Only positive gaps between selected non-muted montage regions are expanded.
- Overlaps, crossfades, and parallel selected non-muted items do not receive added space between them.
- Muted selected items are followers: they move according to the expanded timeline, but they do not define or increase gaps.
- Items inside an expanded gap move proportionally inside that gap.
- Item lengths, playrates, fades, take start offsets, and take settings are not changed.
- Only selected items are moved; unselected items are untouched.

Suggested checks:

- Single track: two selected non-muted items with a 1.0 sec gap and `20%, 0 sec` should become a 1.2 sec gap.
- Multi-track: selected non-muted items on different tracks should define one global montage timeline.
- Muted follower: a selected muted item inside a gap should move proportionally as that gap expands.
- Muted-only selection: the script should report that no non-muted selected montage items were found.
- Crossfade or overlap: overlapping selected non-muted items should keep their existing relationship.
- Undo: run the script and undo it with one REAPER undo action.

## License

MIT. You can use, modify, and distribute this script freely.
