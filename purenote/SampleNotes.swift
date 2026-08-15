//
//  SampleNotes.swift
//  purenote
//
//  The notes written into an empty library on first run, so a fresh install is
//  never a blank screen. They double as a gentle tour of what the app can do --
//  headings, checklists, tables, quotes, links, folders -- and one of them
//  explains how to delete everything, since the files are the user's to keep or
//  throw away.
//

import Foundation

enum SampleNotes {

    /// Path relative to the notes root (subfolders are created as needed) and
    /// the Markdown to write there.
    static let all: [(path: String, content: String)] = [
        ("Welcome to Purnote.md", """
        # Welcome to Purnote 👋

        Every note you write is just a **plain `.md` file** in your iCloud Drive — \
        nothing locked away, nothing to export. Open the same notes on your Mac, \
        back them up anywhere.

        ## Write the way you like

        - Type **Markdown** by hand, *or*
        - Tap the bar above the keyboard and let it write the syntax for you

        ## A few things to try

        - [x] Read this note
        - [ ] Create your first note
        - [ ] Make a checklist
        - [ ] Find a note with search

        > The best note is the one you can actually find again.

        Happy writing.
        """),

        ("Managing your notes.md", """
        # Managing your notes

        Every note in Purnote is a plain Markdown file in your iCloud Drive, inside \
        a folder called **purnote**. That folder *is* the whole database — there is \
        nothing hidden anywhere else.

        ## Delete one note
        Swipe left on it in the list, or open the **Files** app and delete the \
        `.md` file.

        ## Delete everything
        There is no "delete all" button, on purpose — your notes are just files. \
        To wipe the slate clean:

        1. Open the **Files** app
        2. Go to **iCloud Drive → purnote**
        3. Delete the whole **purnote** folder

        Purnote will simply show whatever is left. Because the files are yours, \
        nothing is locked in — and nothing is ever deleted behind your back.

        > These sample notes appear only once, on a brand-new install. Delete any \
        you don't want and they stay gone.
        """),

        ("Reading list.md", """
        # Reading list

        ## Reading now
        - [ ] *Piranesi* — Susanna Clarke
        - [x] *The Left Hand of Darkness* — Ursula K. Le Guin

        ## Up next
        - [ ] *The Dispossessed*
        - [ ] *A Wizard of Earthsea*
        - [ ] *Station Eleven*

        > Started *Piranesi* on the train. The House is the world, and the world is the House.

        **2026 so far:** 14 books.
        """),

        ("Morning pages.md", """
        # Morning pages

        *Three pages, before anything else.* Today, typed.

        The fog hasn't lifted off the hills yet and the coffee is doing its slow \
        work. I keep circling one idea:

        > Make the thing small enough that starting is easy.

        Grateful for:

        - black coffee, second cup
        - the quiet before the street wakes up
        - a week with nothing urgent in it

        Tomorrow: start the small version. Ship one paragraph.
        """),

        ("Ideas.md", """
        # Ideas

        - A notes app that is *just files* — no lock-in ✓
        - A weekend cabin, no wifi, a stack of books
        - Learn to develop black-and-white film at home
        - Write one postcard a week to someone I miss
        - A slow walk with no destination

        > Keep the list short. Cross things off, or delete them.
        """),

        ("Recipes/Sourdough.md", """
        # Sourdough

        A loaf that fits a weekend if you feed the starter on Friday night.

        ## Timeline
        | Step | When |
        |---|---|
        | Feed starter | Fri 21:00 |
        | Mix & autolyse | Sat 09:00 |
        | Folds | Sat 09:30–11:30 |
        | Shape | Sat 13:00 |
        | Bake | Sun 08:00 |

        ## Method
        1. Autolyse flour and water, 45 min
        2. Add starter and salt, fold every 30 min × 4
        3. Shape, then cold-proof in the fridge overnight
        4. Bake at 250°C in a dutch oven — lid on 20 min, lid off 20 min

        > The crust should sing quietly as it cools.
        """),

        ("Recipes/Weeknight pasta.md", """
        # Weeknight pasta

        **Serves 2.** About 20 minutes, start to plate.

        1. Salt the water like the sea
        2. Garlic in *cold* oil, low heat — never let it brown
        3. Chilli flakes, then the tomatoes

        | Ingredient | Amount |
        |---|---|
        | Spaghetti | 200 g |
        | Garlic | 3 cloves |
        | Cherry tomatoes | 250 g |

        > Reserve a cup of pasta water before draining — it's the sauce.
        """),

        ("Travel/Lisbon in three days.md", """
        # Lisbon, three days

        ## Day 1 — Alfama
        - Tram **28** early, before the queues
        - Miradouro de Santa Luzia for the view
        - Dinner: grilled sardines in a side street

        ## Day 2 — Belém
        - [ ] Pastéis de Belém (get there before 10)
        - [ ] Jerónimos Monastery
        - [ ] Sunset by the river

        ## Day 3 — slow
        Coffee, a bookshop, no plan. Maybe the [tile museum](https://www.museudoazulejo.gov.pt).

        > Bring good shoes. The whole city is a staircase.
        """),

        ("Travel/Packing list.md", """
        # Packing list

        - [ ] Passport
        - [ ] Charger + EU adapter
        - [ ] Light jacket for the evenings
        - [x] Offline map downloaded
        - [ ] Sunglasses
        - [ ] A book for the plane

        **One bag only.** If it doesn't fit, it doesn't come.
        """),

        ("Travel/Cabin notes.md", """
        # Cabin notes

        Off-grid for a week. What actually mattered:

        - The wood stove takes 20 minutes — light it *before* the sun drops
        - Water from the rain butt, boiled twice
        - No signal past the second gate

        ## Bring next time
        - [ ] A sharper axe
        - [ ] More coffee than seems reasonable
        - [x] The good torch

        > The quiet is the point. Don't fill it.
        """),
    ]
}
