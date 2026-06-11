# Copy Jokers Balatro Mod

A small Balatro mod that adds a set of Joker cards focused around copying or duplicating other Jokers, inspired by vanilla Jokers like **Blueprint**, **Brainstorm**, **DNA**, and **Invisible Joker**.

This mod was originally made for **Steamodded 0.9.8**.

## Jokers

This mod currently adds:

* **Mirror Joker**
  Copies the ability of the Joker to the left.

* **Tailgater Joker**
  Copies the ability of the rightmost compatible Joker.
  Prioritizes the far-right Joker, then searches left.

* **Appraiser**
  Copies the ability of the Joker with the highest sell value.
  If multiple Jokers are tied, it prioritizes the rightmost one.

* **Uncommon Ground**
  Copies the ability of an Uncommon Joker.
  Prioritizes Uncommon Jokers to the right, then searches left.

* **Stage Right**
  During scoring, copies the ability of the Joker to the right.

* **Receipt Printer**
  When the blind is selected, creates a temporary Negative copy of the newest valid Joker.
  Prioritizes the far-right Joker, then searches left. Temporary copies are removed at the end of the round.

* **Counterfeit Joker**
  When the blind is selected, if you have $0 or less, copies the Joker with the highest sell value, then destroys itself.
  If multiple Jokers are tied, it prioritizes the rightmost one.

* **Clone Stamp**
  When a Joker is sold, copies the Joker to the left, then destroys itself.

* **Echo**
  After 4 rounds, creates a Negative copy of the Joker to the right, then destroys itself.

* **Double or Nothing**
  When the blind is selected, has a 1 in 2 chance to copy the Joker to the right and destroy itself.
  If it fails, it destroys itself and the Joker it was trying to copy.

## Compatibility

This mod was made specifically around **Steamodded 0.9.8**.

It may work on newer versions of Steamodded, but I have **not** tested it on the latest version and cannot guarantee compatibility without changes.

I have a pretty niche use case: I mainly play Balatro mods on **Nintendo Switch**, so this mod was tested and used through **SteamoddedNX** by JonJaded:

https://github.com/JonJaded/SteamoddedNX

The mod has been tested with vanilla Jokers and has had limited testing with other modded Jokers. Since this mod depends on copying and duplicating other Joker effects, I cannot guarantee that every modded Joker will work correctly.

Some Jokers, especially ones with unusual timing, passive effects, destruction effects, custom scoring behavior, or custom modded logic, may not copy or duplicate cleanly.

## Installation

Install this mod the same way you would install other Steamodded mods.

Place the mod folder in your Steamodded mods directory, then launch the game with Steamodded enabled.

For SteamoddedNX users, follow the setup instructions from the SteamoddedNX repository:

https://github.com/JonJaded/SteamoddedNX

## Notes

Copy effects can be complicated because not every Joker activates in the same scoring context. This mod tries to keep the copy behavior general, but some edge cases may still exist.

If a copied Joker does not activate correctly, it may be because that Joker uses behavior that is not compatible with Blueprint-style copying.

Duplicate effects are generally more reliable than direct ability-copying effects because they create a real copy of the Joker card. However, duplicated modded Jokers can still behave unexpectedly depending on how the original Joker was coded.

Temporary copies are marked internally and are intended to be removed after the round ends.

## Disclaimer

This is a small personal-use mod made around my own setup and testing environment.

It was originally intended for **Steamodded 0.9.8** and tested through **SteamoddedNX** on Nintendo Switch.

It could work on higher versions of Steamodded, but compatibility is not guaranteed.
