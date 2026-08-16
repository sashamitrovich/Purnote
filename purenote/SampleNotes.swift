//
//  SampleNotes.swift
//  purenote
//
//  The notes written into an empty library on first run, so a fresh install is
//  never a blank screen. They double as a gentle tour of what the app can do --
//  headings, checklists, tables, quotes, links, folders -- and one of them
//  explains how to delete everything, since the files are the user's to keep or
//  throw away. This is also the library shown in the App Store screenshots.
//

import Foundation

enum SampleNotes {

    /// Path relative to the notes root (subfolders are created as needed) and
    /// the Markdown to write there.
    static let all: [(path: String, content: String)] = [
        ("Welcome to Purnote.md", """
        # Welcome to Purnote 👋

        Every note you write is a **plain Markdown file** in your own iCloud Drive — no database, no proprietary format, nothing to export. Ever.

        ## Why it matters
        - [x] Your notes are just files
        - [x] Open them on your Mac, or in any editor
        - [ ] Never think about lock-in again

        ## What you can do
        - Write in **Markdown**, or tap the bar above the keyboard and let it write the syntax for you
        - Organise notes into folders
        - Search every note instantly
        - Render headings, tables, checklists and code

        ## It syncs itself
        Write on your phone and it is on your Mac a moment later. Edit it on your Mac and it changes here while you watch.

        ## Built to stay out of the way
        - No accounts, no sign-in
        - No ads, no tracking, no analytics
        - Works offline, syncs when you are back

        > The best note is the one you can actually find again — and still have in ten years.

        Happy writing.
        """),

        ("Managing your notes.md", """
        # Managing your notes

        Every note in Purnote is a plain Markdown file in your iCloud Drive, inside a folder called **purnote**. That folder *is* the whole database — there is nothing hidden anywhere else.

        ## Delete one note
        Swipe left on it in the list, or open the **Files** app and delete the `.md` file.

        ## Delete everything
        There is no "delete all" button, on purpose — your notes are just files. To wipe the slate clean:

        1. Open the **Files** app
        2. Go to **iCloud Drive → purnote**
        3. Delete the whole **purnote** folder

        Purnote will simply show whatever is left. Because the files are yours, nothing is locked in — and nothing is ever deleted behind your back.

        > These sample notes appear only once, on a brand-new install. Delete any you don't want and they stay gone.
        """),

        ("Marathon training.md", """
        # Marathon training

        Sixteen weeks to Berlin. Keep it boring, keep it consistent, and trust the plan on the days you would rather not.

        ## This week — build 3
        - [x] Mon — easy 8 km, nose-breathing only
        - [x] Wed — intervals, 6 × 800 m @ 3:45/km
        - [ ] Fri — easy 6 km + strides
        - [ ] Sat — long run, 28 km
        - [ ] Sun — rest, actually rest

        ## The block at a glance
        | Week | Long run | Quality | Total |
        |---|---|---|---|
        | 11 | 26 km | 8 × 800 | 52 km |
        | 12 | 28 km | 3 × 2 km | 55 km |
        | 13 | 30 km | 10 km tempo | 58 km |
        | 14 | 32 km | 6 × 1 km | 60 km |
        | 15 | 24 km | taper | 42 km |

        ## Race-pace targets
        - Goal sub-3:30 → **4:58 / km**
        - Long-run pace 5:40–6:00 / km
        - Easy pace stays conversational

        ## Fuelling
        - A gel every 5 km from km 10
        - Sip at every station, do not gulp
        - Rehearse the race breakfast on long-run mornings

        > Nothing new on race day. Not the shoes, not the breakfast, not the pace.
        """),

        ("Home espresso dial-in.md", """
        # Home espresso dial-in

        Chasing 1:2 in about 28 seconds.

        | Setting | Today |
        |---|---|
        | Dose | 18 g |
        | Yield | 36 g |
        | Time | 29 s |
        | Grind | 2.4 |

        *Tastes sour?* Grind finer. *Bitter?* Coarser, or drop the temperature a degree.

        > Weigh everything. Guessing is how you get sad coffee.
        """),

        ("Ideas worth keeping.md", """
        # Ideas worth keeping

        - A notes app that is *just files* — no lock-in ✓
        - A weekend with no wifi and a stack of books
        - Learn to develop black-and-white film at home
        - Write one postcard a week to someone I miss

        > Keep the list short. Cross things off, or delete them.
        """),

        // ---------- Journal ----------
        ("Journal/Morning pages.md", """
        # Morning pages

        *Three pages, before anything else.* Today, typed.

        The fog hasn't lifted off the hills yet and the coffee is doing its slow work. One idea keeps circling:

        > Make the thing small enough that starting is easy.

        Tomorrow: ship one paragraph.
        """),

        ("Journal/Gratitude.md", """
        # Gratitude

        Three, most nights:

        - Black coffee, second cup
        - The quiet before the street wakes up
        - A week with nothing urgent in it
        """),

        ("Journal/One line a day.md", """
        # One line a day

        **Mon** — Ran in the rain and didn't mind it.
        **Tue** — Fixed the thing I'd avoided for a month.
        **Wed** — Long lunch, no phone.
        **Thu** — Started the book everyone talks about.
        """),

        // ---------- Recipes ----------
        ("Recipes/Sourdough.md", """
        # Sourdough

        A loaf that fits a weekend if you feed the starter on Friday night.

        | Step | When |
        |---|---|
        | Feed starter | Fri 21:00 |
        | Mix & fold | Sat 09:00 |
        | Shape | Sat 13:00 |
        | Bake | Sun 08:00 |

        1. Autolyse flour and water, 45 min
        2. Add starter and salt, fold every 30 min × 4
        3. Cold-proof overnight, then bake at 250°C

        > The crust should sing quietly as it cools.
        """),

        ("Recipes/Weeknight pasta.md", """
        # Weeknight pasta

        **Serves 2.** About 20 minutes, start to plate.

        1. Salt the water like the sea
        2. Garlic in *cold* oil, low heat
        3. Chilli, then the tomatoes

        > Reserve a cup of pasta water before draining — it's the sauce.
        """),

        ("Recipes/Ragu, the slow way.md", """
        # Ragù, the slow way

        No shortcuts. Three hours, mostly waiting.

        - Soffritto: onion, carrot, celery, patient
        - Beef and pork, browned in batches
        - Milk first, then wine, then tomatoes
        - Barely a bubble for three hours
        """),

        ("Recipes/Negroni.md", """
        # Negroni

        Equal parts, stirred, orange.

        | | |
        |---|---|
        | Gin | 30 ml |
        | Campari | 30 ml |
        | Sweet vermouth | 30 ml |

        > Stir, don't shake. Big ice. One orange peel.
        """),

        // ---------- Travel ----------
        ("Travel/Weekend in Lisbon.md", """
        # Weekend in Lisbon

        Three days, good shoes, no rush.

        ## Friday — Alfama & Graça
        - Tram **28** early, before the crowds
        - Miradouro de Santa Luzia for the tiles and the view
        - Lunch: grilled sardines in a side street
        - Fado in a tiny room after dark

        ## Saturday — Belém
        - [x] Pastéis de Belém before 10
        - [ ] Jerónimos Monastery
        - [ ] Torre de Belém from the outside
        - [ ] Coffee by the river as the sun drops

        ## Sunday — slow
        Coffee, a bookshop, no plan. Maybe the [tile museum](https://www.museudoazulejo.gov.pt) if the legs allow.

        | Getting around | Viva Viagem card |
        |---|---|
        | Cash | Small notes for fado |
        | Weather | Layers, evenings cool |

        > The whole city is a staircase — and every landing has a view.
        """),

        ("Travel/Packing list.md", """
        # Packing list

        - [ ] Passport
        - [ ] Charger + EU adapter
        - [ ] Light jacket for the evenings
        - [x] Offline map downloaded
        - [ ] A book for the plane

        **One bag only.** If it doesn't fit, it doesn't come.
        """),

        ("Travel/Kyoto in autumn.md", """
        # Kyoto in autumn

        Peak colour, late November.

        - Early train to Arashiyama
        - Philosopher's Path on foot
        - Kaiseki dinner, booked months ahead

        > Temples open at dawn and so should you.
        """),

        // ---------- Reading ----------
        ("Reading/Piranesi.md", """
        # Piranesi — notes

        Susanna Clarke. Read it in two sittings.

        > The House is the world, and the world is the House.

        - The statues as a memory palace
        - Kindness as the whole moral of it
        - That last page, again
        """),

        ("Reading/To read.md", """
        # To read

        - [ ] *The Dispossessed* — Le Guin
        - [ ] *Station Eleven*
        - [x] *The Left Hand of Darkness*
        - [ ] *A Wizard of Earthsea*

        **2026 so far:** 14 books.
        """),

        ("Reading/Quotes.md", """
        # Quotes

        > The purpose of a storyteller is not to tell you how to think, but to give you questions to think upon.

        > We cross our bridges when we come to them and burn them behind us.

        > Attention is the rarest and purest form of generosity.
        """),
    ]
}
