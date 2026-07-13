# sheet_music_notes

A Flutter library that renders music notation. It currently supports:

- staff systems (one or two staves) with G, F, C and tenor clefs
- key signatures and time signatures
- notes from whole to thirty-second, augmentation dots, and rests of all lengths
- accidentals with the standard within-measure carry-over rule (an explicit sign applies to
  the same pitch until the bar line; naturals cancel key-signature accidentals)
- beamed note groups, including secondary (sixteenth) beams that stay parallel to the
  primary beam
- chord overlays: a `chord` note is drawn at the exact x of the preceding note without
  advancing the rhythmic grid — used e.g. as recolourable feedback copies (stems and whole
  beam groups can be recoloured per overlay)
- per-note colours and decorative note highlights (translucent background band or cursor
  caret) for trainer-style apps
- bar lines (regular, dashed, light-heavy end bar, repeats) and line justification to a
  forced width (`MusicLineOptions.lineWidth`)

Known limitations: no tuplets, ties/slurs, ornaments, dynamics or lyrics; the MusicXML
parser only supports what the renderer can draw; multi-part scores beyond two staves are
untested.

I only work on this infrequently when I have time and feel like it 🙂

In the example folder you find a small dummy app showing the library in action.

### Screenshot
![Screenshot](/screenshot.png)
