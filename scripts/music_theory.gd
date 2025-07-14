class_name MusicTheory
extends Node

## An enumeration of all the pitches we can place on the staff.
## Naming is based on a standard G-Clef staff, starting from below the staff.
enum Pitch {
    DO_LEDGER,  # C4 on a ledger line below the staff
    RE_BELOW,   # D4 just below the staff
    MI_LINE1,   # E4 on the first (bottom) line
    FA_SPACE1,  # F4 in the first space
    SOL_LINE2,  # G4 on the second line (the G-clef line)
    LA_SPACE2,  # A4 in the second space
    SI_LINE3,   # B4 on the third line
    DO_SPACE3,  # C5 in the third space
    RE_LINE4,   # D5 on the fourth line
    MI_SPACE4,  # E5 in the fourth space
    FA_LINE5,   # F5 on the fifth (top) line
    SOL_ABOVE   # G5 just above the staff
}

# We use the Y-coordinates you provided for the lines and calculate the spaces.
# Line 1 (bottom): 190
# Line 2: 78
# Line 3: -33
# Line 4: -144
# Line 5 (top): -256
const PITCH_Y_COORDINATES = {
    Pitch.DO_LEDGER: 192,
    Pitch.RE_BELOW: 156,
    Pitch.MI_LINE1: 100,
    Pitch.FA_SPACE1: 44,
    Pitch.SOL_LINE2: -12,
    Pitch.LA_SPACE2: -68,
    Pitch.SI_LINE3: -124,
    Pitch.DO_SPACE3: -180,
    Pitch.RE_LINE4: -236,
    Pitch.MI_SPACE4: -292,
    Pitch.FA_LINE5: -348,
    Pitch.SOL_ABOVE: -404
}

## Returns the global Y coordinate for a given musical pitch.
static func get_y_for_pitch(pitch: Pitch) -> float:
    if PITCH_Y_COORDINATES.has(pitch):
        return PITCH_Y_COORDINATES[pitch]
    else:
        # This is a fallback in case a pitch is not in our map.
        printerr("MusicTheory: Pitch '", Pitch.keys()[pitch], "' not found in coordinate map!")
        return 0.0
