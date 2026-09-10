-- Hyperdertale - monster definitions.
-- `acts` drive the mercy route: each one nudges `mercy` up, and once mercy
-- reaches `spareAt` the monster can be spared instead of killed.

return {
  critter = {
    name = "HYPERLING",
    sprite = "critter",
    tiredSprite = "critterTired",
    hp = 42,
    maxhp = 42,
    at = 5,
    df = 2,
    exp = 12,
    gold = 8,
    spareAt = 2,
    check = "* HYPERLING - ATK 5 DEF 2\n* Four legs, no plan. Curious about everything.",
    intro = "* A HYPERLING blocks the way!",
    -- One flavour line per turn, chosen at random.
    idle = {
      "* The HYPERLING sniffs at your shoes.",
      "* The HYPERLING is walking in a small circle.",
      "* Something rattles softly inside the HYPERLING.",
      "* The HYPERLING watches your every move.",
    },
    tired = {
      "* The HYPERLING is breathing hard.",
      "* The HYPERLING keeps glancing at the exit.",
      "* The HYPERLING would rather be anywhere else.",
    },
    acts = {
      {
        name = "CHECK",
        mercy = 0,
        text = "* HYPERLING - ATK 5 DEF 2\n* Four legs, no plan. Curious about everything.",
      },
      {
        name = "TALK",
        mercy = 1,
        text = "* You talk about the weather down here.\n* The HYPERLING has never seen weather.",
        repeatText = "* You keep talking. The HYPERLING listens, head tilted.",
      },
      {
        name = "PET",
        mercy = 1,
        text = "* You pet the HYPERLING.\n* It leans into your hand and rattles happily.",
        repeatText = "* You pet the HYPERLING again. It has decided you are fine.",
      },
      {
        name = "PLAY",
        mercy = 1,
        text = "* You throw an imaginary stick.\n* The HYPERLING chases it seriously.",
        repeatText = "* You throw it again. The HYPERLING is delighted every time.",
      },
    },
    spareText = "* You spared the HYPERLING.\n* It trots off, tail rattling.",
    killText = "* The HYPERLING crumbles into dust.",
    patterns = {"rain", "sideBars", "radial", "sweep"},
  },
}
