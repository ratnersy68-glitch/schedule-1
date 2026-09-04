# Fonts

## Inter (`InterVariable.ttf`)

Inter by Rasmus Andersson, used for the entire interface. A variable font, so
one 880 KB file covers every weight from Thin to Black; `UITheme` picks weights
off the `wght` axis rather than shipping a file per weight.

Chosen because it was drawn for user interfaces at small sizes on screens,
which is exactly this game's problem: dense HUD readouts on a phone. It also
has tabular figures, so money and clock readouts stop shuffling as the digits
change.

- Version 4.1, from https://github.com/rsms/inter
- Licensed under the SIL Open Font License 1.1, which permits bundling with
  software. The full licence is in `Inter-LICENSE.txt` and must stay with the
  font.
