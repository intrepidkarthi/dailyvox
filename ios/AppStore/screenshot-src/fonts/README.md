# Fonts used to compose the store frames

`Caveat-SemiBold.ttf` — SIL Open Font License 1.1, from Google Fonts.

It is here rather than in the app bundle because the app does not use it: it
appears only in the App Store frames, as the handwritten accent line the store
canvas (`DailyVox Store Images.dc.html`) specifies. Vendored rather than fetched
so the frames render identically without a network.

Nunito, Inter and DM Mono are NOT duplicated here — `make_frames.py` reads them
straight out of `ios/solyn/Fonts/`, which is the same file the app ships, so a
frame can never drift from the product's actual typography.
