# SANGA — Story Bible

The script, the hidden truth behind it, and the one mechanic that ties it together. Every
line the player reads comes from this file. If a line in `story/*.json` disagrees with this
file, this file wins.

Lines are in natural, modern Tagalog, the way people in Manila actually talk: short sentences,
contractions (`'yan`, `'di ba`, `n'yo`), a little English where a Manileño would use it
(*rider*, *delivery*, *operasyon*). No textbook Filipino. Ending cards and objectives stay in
English where they label the game's own screens.

---

## 1. Logline

**"You can't undo a death. You can only remember it."**

One weekend in one Manila parish. A priest hears confessions on Saturday afternoon. That night a
girl from the province wakes up locked in a room across the street. On Sunday afternoon a rider
buys a toy gun for a boy's birthday. The three stories are one story: what the priest hears on
Saturday decides who is shot on Sunday. The player can begin anywhere, and every death they see
becomes an **Alaala** (a memory) the save never forgets. Memories open choices that no first-time
player can make. Only a player who remembers everything reaches the run where nobody dies, and
finds out who has been confessing to them all along.

---

## 2. One story, three ways in (rule R10)

There is **one** version of events. It is told in story time as:

| Order | Story | When | You are |
|---|---|---|---|
| 1 | **Kumpisal** | Saturday, 3 to 6 pm | Father Eli |
| 2 | **Padala** | Saturday night | Mercy |
| 3 | **Tokhang** | Sunday afternoon | Peter (or Gwen) |

A run plays all three, beginning with the one the player picked on the start screen and going on
around the circle:

| Begin at | Plays |
|---|---|
| Tokhang (the market; always the first run) | Tokhang, Kumpisal, Padala |
| Kumpisal (the church) | Kumpisal, Padala, Tokhang |
| Padala (the room) | Padala, Tokhang, Kumpisal |

**R10. A cause reaches only what is later in story time and played later in the run.** A story
never changes because of something that happens after it in story time, and a story played before
its causes shows only what is true in every version of the past. Concretely:

- Kumpisal (earliest) never changes. It gains no lines from Padala or Tokhang, only from memories.
- Padala shows the echoes of Kumpisal when Kumpisal was played first in the run.
- Tokhang shows the echoes of both when they were played first: Gwen's confession on the phone,
  Mercy's death on the news, Peter seen at Eli's door, and Kulas alive and warning the buyer.
- The one place the player can *change* the future is the Alaala choice or a choice whose flag a
  later story reads (see the flag table in section 4).

Starting point changes what the player knows first. Beginning at the market, Peter is shot with no
idea why; beginning at the church, the player is Eli and has no idea yet what the girl is walking
into.

---

### The first run keeps its spine (rule R11)

The first run of a save has real choices, but they only change how the story feels, never what
happens. Fixed: Peter is shot at the market, Kulas is shot after the confessions, and Mercy dies
with the man at the door, whichever way out she takes.

- Tokhang's errand offers two ways to say yes (*Sige. Dadaanan ko na.* and *Sige. Anong oras ang
  handaan?*); both send Peter.
- In Padala on a save's first run, the poster ends at the door with Batista, the food flyer with
  Eli answering the door, and the key with Eli coming out of the bath and catching her (ending
  `padala_caught`). Each shows the man's face, so the reveal always lands. The poster and the key
  give memory 3 (Si Father Eli). From the second run the key leads to the street (run or hide).

---

## 3. The hidden truth (never shown all at once)

Nobody in the game says all of it. The player pieces it together, the way a parish does.

| Who | What they seem | What they are |
|---|---|---|
| **Father Eli** | The tired, kind parish priest. | Breaks the seal of confession. What he hears he passes to Batista, so people who know too much are shot in "operations". He keeps girls Gloria brings in the apartment across the street from the church. Mercy is the latest. |
| **Batista** | Eli's loud, loyal friend since they were altar boys. A police officer. | Carries out the shootings and writes *nanlaban*. In his confession he admits planting guns on two of the last three. Eli's names are his permission. When someone calls the police for help from that apartment, the call reaches Batista. |
| **Gloria** | The sweet vendor who calls everyone *anak*. | Brings girls from the province with promises of work. Never asks where they go. Also tips Batista off when someone buys a realistic toy gun from her stall: a "nanlaban" with a gun is a case closed. |
| **Kulas** | A tired addict, three weeks clean. | Is on Batista's list. Carried a suitcase for Gloria a month ago, something inside moved, and he delivered it to the apartment across the church. The only witness. |
| **Mercy** | A shy girl from Samar, here for a job to send money home. | The newest girl. Meets Eli in the church. That night she wakes up in the room. |
| **Peter** | A delivery rider. | In one version he answers a delivery call from the room and Eli reads his name from the receipt. In the next he is the "man with the gun" at the market. |
| **Gwen** | Peter's partner. Sharp, protective. | Pregnant. Tells Eli in confession, and Eli is told that Peter works around Sampaloc. |
| **Ben** | Gwen's little brother, turning seven. | Innocent. His birthday toy starts the day. |

**The frame (the last twist):** every run after the first begins with an unseen voice in a dark
confessional: *"Basbasan n'yo po ako, Padre, dahil nagkasala ako."* The player assumes it is a
stranger, or the story itself. Only in the true ending does it turn out to be **Father Eli**, in a
visiting booth, confessing, and the one he is confessing to is **the player**, who has heard every
confession in the game and remembered all of them. That is what the Alaala are.

---

## 4. The Alaala mechanic (final rules)

**Writing choices:** a choice never hints at what it leads to. Both options read as things the
character would plausibly say. Every choice fits on one line. Stage directions inside a line are
Tagalog, between asterisks: *Tumawa*, *Mahina, sa cellphone*.

- **R1.** Three kinds of choices: **branch** (the Tokhang errand, the Padala way out), **Alaala**
  (needs a memory, changes the ending), **ordinary** (changes only the lines right after it, and
  may set a flag a later story reads).
- **R2.** Alaala come only from deaths. Each death ending awards one Alaala; several deaths can
  award the same one.
- **R3.** Each Alaala unlocks exactly one Alaala choice, in one fixed scene.
- **R4.** An Alaala can add **revelation lines** to scenes the player has already seen: a name
  where there was only "???", one more sentence in a confession.
- **R5.** Alaala belong to the save slot and are never lost. Flags and choices reset each run.
- **R6.** No timers, no meters, no hidden stats. The player cannot fail a choice.
- **R7.** No new places, no new characters.
- **R8.** An Alaala choice shows a faint **✦**, and taking one plays a soft chime and a golden ring.
  The book gives each Alaala a faint hint of where it matters, never what it changes.
- **R9. Echoes.** An ordinary choice can come back later in the same run as an **echo**: one line,
  somewhere else, that answers what was said. Echoes follow R10: they flow forward in story time.
  An echo never changes an ending, never adds a choice, and is quoted in the run's recap, marked ↳.
- **R10.** See section 2.

### The end of a run: "Ang Nangyari", then "Ayusin ayon sa oras"

Every run ends in the old book. First **Ang Nangyari**: the run as it was played. Then the ink
fades and the book writes the run again **in true time order**, Kumpisal, Padala, Tokhang, and red
threads draw down the margins from each cause to its effect. A thread is drawn only between two
things the player saw in this run, and only forward in time. After any ending but the true one, the
voice speaks once over black: *"Hindi pa po iyon ang buong kumpisal, Padre."*

### The flags a later story reads

| Set in | Flag | Read in | What it does there |
|---|---|---|---|
| Kumpisal (Mercy) | `run_echo_mercy_reassured`, `run_echo_mercy_asked` | Padala opening | Mercy repeats what the priest said |
| Kumpisal (Gloria) | `run_echo_gloria_repent`, `run_echo_gloria_judged` | Padala opening | What Gloria did when she left |
| Kumpisal (Batista) | `run_echo_batista_careful`, `run_echo_batista_warned` | Padala, police at the door | What Batista says when he sees Eli |
| Kumpisal (Batista confession) | `run_echo_batista_stop`, `run_echo_batista_weight` | Padala, after the shot outside | What Batista says over the body |
| Kumpisal (Gwen confession) | `run_echo_gwen_tell` | Tokhang phone call | Gwen asks Peter to come home early |
| Kumpisal (Kulas, Alaala) | `run_kulas_safe` | Tokhang | Kulas warns the buyer away from the realistic gun, which offers the water gun |
| Kumpisal (last prayer, Alaala) | `run_eli_confessed` | Padala | Eli opens the door: **Pinalaya** |
| Padala (food call) | `run_peter_seen` | Tokhang | Peter asks Gwen about the priest; Eli and Batista talk about "the rider from last night" |
| Padala (outside) | `run_echo_mercy_ran` | Tokhang | The news mentions an unidentified woman |
| Padala (rider, Alaala) | `run_tanod` | Padala | **Tanod**: Mercy is rescued |

### The five Alaala

| # | Name | Memory text | From (deaths) | Unlocks | Revelation lines (R4) |
|---|---|---|---|---|---|
| 1 | **Ang Laruang Baril** | *Isang laruan. Isang text. Isang bala.* | Peter or Gwen shot (Tokhang) | Tokhang: the water gun | Tokhang: Gloria's phone call after the sale |
| 2 | **Ang Pagtakbo ni Kulas** | *Tumakbo siya palabas ng simbahan. Hindi na siya nakarating sa kanto.* | Kulas shot (Kumpisal) | Kumpisal: *Hintayin mo 'ko. Sabay na tayong lumabas.* | Kumpisal: Kulas tells about the suitcase |
| 3 | **Si Father Eli** | *Ang taong nakikinig sa lahat ng kasalanan... may sarili palang itinatago.* | Mercy dies (Padala, police, or caught with the key on the first run) | Kumpisal: *Ama, aaminin ko na ang lahat.* | "???" becomes "Batista" in every shout; Eli's call before the gunshot |
| 4 | **Ang Baril ni Batista** | *Sa dilim, lahat ng tumatakbo ay suspek.* | Mercy shot running (Padala) | Padala: *Magtago hanggang magliwanag.* | none |
| 5 | **Ang Rider** | *Dumating siya. Nakita niya ako. Umalis siya.* | Food delivery (Padala) | Padala: *Pakisabi pong magsama siya ng tanod.* | none |

**True ending, "Walang Namatay":** one run in which Kulas is walked home (2), the water gun is
bought (1) and Eli confesses (3). A first run at the market that ends at the police poster already
gives memories 1, 2 and 3 (Peter shot, Kulas shot, Mercy dead), so a careful player can reach it on
the second run, beginning at the church: Kumpisal (walk Kulas home, Eli confesses), Padala (he opens
the door), Tokhang (Kulas warns, the water gun). Beginning at the market works too (Tokhang's water
gun needs memory 1, Kumpisal's choices need 2 and 3). **Beginning in the room cannot earn it**:
Padala is played before Kumpisal there, so Eli has not confessed when Mercy's door is tried (R10).
In Tokhang the water gun is offered either by memory 1 or, with no memory, by Kulas' warning.

---

## 5. Voice guide

| Character | How they talk | Never |
|---|---|---|
| **Father Eli** | Always a priest, in every line and every choice: calm, warm, unhurried, calls people *anak*, speaks of God, prayer and forgiveness. Short, quotable sentences. Never raises his voice. He says *pare* only in secret (his phone calls, the door with Batista): that slip is the reveal. | Sermons longer than two lines. Slang in public. |
| **Peter** | Pagod pero pabiro. Taglish of a rider: *delivery, traffic, joke lang*. Calls Gwen *mahal*. | Self-pity. |
| **Gwen** | Mabilis magsalita, matapang, makulit kay Ben. Soft only when scared. | Being helpless. |
| **Ben** | Bata: simple, excited, one idea at a time. | Long sentences. |
| **Gloria** | Sweet tindera voice: *anak, suki, naku*. Laughs things off. | Saying anything directly. |
| **Batista** | Malakas, kanto-cop, laughs too loud. Says *Father* in public and *pare* only when alone with Eli. Hard when alone. | Formal Tagalog. |
| **Kulas** | Paos, pagod. Very short sentences, trails off with "...". | Jokes. |
| **Mercy** | Probinsyana, magalang (*po, opo*), soft, apologises too much. Grows firmer in Padala. | Swearing. |

---

## 6. Prologue: the voice and the start screen

The first run starts cold in the market, with no hint of what comes after it (New Game always
starts at the market). Every run after it begins on the **start screen**, which replaces the old
"answer as the priest" menu. Three upright 3:4 cards:

| Card | Opens |
|---|---|
| **Continue** | The save as it stands (a run in progress, or the next run). |
| **Tokhang** | Under the heading "Select your starting point": the run begins at the market. |
| **Kumpisal** | The run begins at the church. Closed until the first run is finished. |
| **Padala** | The run begins in the room. Closed until the first run is finished. |

After a pick, the prologue plays. Black screen. The confessional's small door, a grille
(`prologue_booth.png`). Text only, no name plate. Two opening lines, the same every time:

> **(Isang boses):** Basbasan n'yo po ako, Padre, dahil nagkasala ako.
> **(Isang boses):** Matagal na po mula nung huli akong nangumpisal.

Then the voice's `last_line`, which begins where the player chose:

| Start | The voice |
|---|---|
| Tokhang | Magsisimula po ako sa palengke. Linggo ng hapon. |
| Kumpisal | Magsisimula po ako sa simbahan. Sabado, bago magdilim. |
| Padala | Magsisimula po ako sa kwarto. Sa likod ng pintong nakakandado. |

Then the story's title card.

**After every ending but the true one**, once the book has shown the run in time order, the same
voice speaks once over black (`more`), so the player knows there is more without being told how
much:

> **(Isang boses):** Hindi pa po iyon ang buong kumpisal, Padre.

**The epilogue** (the true ending, section 10) lives in `prologue.json` under `"epilogue"`: the
voice turns out to be Father Eli.

---

## 7. TOKHANG (Sunday afternoon; player: Peter, or Gwen when she is the buyer)

One version for every run. It is the latest story in time, so what was played before it in this
run reaches it as echoes (marked below).

### 7.1 Intro

Three frames, one line of travel: the skyway, the news, the market. They are drawn in 3D from nothing (`tools/intro_frames.py`, `tools/bike_parts.py`, `tools/tv_store.py`); the same pink-fendered scooter and the same Peter (pink helmet, black jacket, pink backpack) are in frames 1 and 3.

`tokhang_skyway.png` (caption *Linggo ng hapon*): a low shot from the side as Peter rides the elevated skyway: front wheel, scooter and rider, a green exit gantry (SAMPALOC / ESPAÑA), hazy Manila ahead with a Gothic church spire among the towers.
> **Peter:** Huling biyahe na 'to. Birthday ni Ben, bawal akong ma-late.

`tokhang_tv_news.png`
> **Reporter:** ...tatlo ang patay sa magkakahiwalay na operasyon kagabi dito sa Sampaloc. Nanlaban umano ang mga suspek, ayon sa pulisya.
> **Reporter:** Kabilang sa mga nasawi ang isang babaeng hindi pa nakikilala. *(echo, flag `run_echo_mercy_ran`)*
> **Peter:** Nanlaban na naman.

`tokhang_market_arrival.png` (no line, a short hold): the scooter parked at the edge of the palengke in daylight, seen from waist level beside its left side with Peter gone from the picture: his pink helmet hangs by its straps from the left mirror, the dashboard and the phone on the bar (Gwen: *umuwi ka nang maaga*) still lit, and beyond it a crowded market: vendors and shoppers, stalls of vegetables, fish, meat, fruit, rice and grilled isaw with price cards and painted boards, tarpaulin roofs, tangled wires, shafts of sun and a PALENGKE banner. No lamp is on. It cuts straight to the phone call.

### 7.2 The phone call (branch choice)

> **Peter:** Mahal, ano nga ulit 'yung gusto ni Ben?
> **Gwen:** Baril. 'Yung parang sa pulis daw. Hindi ko alam kung saan niya napulot 'yan.
> **Ben:** 'Yung itim, Kuya! 'Yung mabigat!
> **Gwen:** Kay Aling Gloria ka na lang bumili, mura do'n.
> **Gwen:** Saka umuwi ka nang maaga, ha. May sasabihin ako. Importante. *(echo, flag `run_echo_gwen_tell`)*

If `run_peter_seen` (Peter was seen at Eli's door the night before):

> **Peter:** Mahal... si Father Eli ba, may kasambahay? *(echo)*
> **Gwen:** Ha? Bakit?
> **Peter:** Wala. Mamaya na lang.

| Choice | Buyer | After |
|---|---|---|
| Sige. Dadaanan ko na. | Peter | **Ben:** Yehey! Bilisan mo, Kuya! / **Gwen:** Ingat ka. |
| Ikaw na lang muna. May pickup pa 'ko. *(from the second run)* | Gwen | **Gwen:** Ako na naman? Sige na nga. Ikaw maghuhugas ng pinggan mamaya. |

### 7.3 Gloria's stall

Objectives: Talk to Gloria → Choose a realistic toy gun → Talk to Gloria.

> **[Buyer]:** Ate, may laruang baril po kayo? 'Yung mukhang totoo.
> **Gloria:** Ay, meron, anak. Nandiyan sa harap, pili ka lang. Dalhin mo rito pag may napili ka na, ibabalot ko.

If the buyer tries the gun first: *Magtatanong muna ako kay Aling Gloria.*

**Kulas warns the buyer** (when `run_kulas_safe`: Kulas was walked home in Kumpisal earlier in
this run). He passes behind the buyer:
> **Kulas:** *Pabulong, dumaan sa likod* Huwag 'yung itim. *(echo)*
> **Kulas:** May mga nakabantay sa labasan. Kilala ko 'yung mga 'yan.

**The guns**

| Object | Line | Buyer |
|---|---|---|
| Pink toy gun | Pang-Barbie 'to. Iiyak si Ben. | Peter |
| Water gun | Water gun. Mas bagay sana sa edad niya... pero 'yung itim ang gusto niya. | Peter, Gwen |
| Realistic toy gun | Ito. Kahit malapitan, mukhang totoo. *(moves the story on)* | Peter, Gwen |

**The water-gun choice** appears on the water gun only when the player may take it: with Alaala 1
(`laruang_baril`) **or** with `run_kulas_safe`. Both options read the same:

| Choice | Effect |
|---|---|
| Ito na lang. Ako na'ng bahala kay Ben. | Buys the water gun. Ending: **Ligtas**. (✦ with Alaala 1) |
| Titingin pa ako. | Back to browsing. |

**Paying** (after the realistic gun is brought back)

> **Gloria:** Two-fifty, anak. Matibay 'yan, hindi basta nababasag.

| Choice | After |
|---|---|
| Dos na lang, Ate. | **Gloria:** Naku, ikaw talaga. O sige na, para sa bata. |
| Sige po. | **Gloria:** Buti ka pa, hindi tumatawad. |

> **Gloria:** Para kay Ben 'yan, 'no? Nakita ko siya kahapon sa simbahan, takbo nang takbo. Si Father Eli lang ang nakakapagpaupo sa kanya.

**Revelation line (Alaala 1 held)**, as the buyer walks away:
> **Gloria:** *Mahina, sa cellphone* ...Oo. 'Yung may bitbit. Papalabas na.

### 7.4 Endings

There is no Kulas death and no Trade ending here any more: Kulas dies in Kumpisal.

**Peter** (`tokhang_peter`)
If `run_peter_seen` first, the optional altar scene, `tokhang_trade.png` (Batista and Father Eli
at the altar, the night after Peter was seen at the door):
> **Batista:** 'Yung rider kagabi. Sigurado kang namukhaan ka?
> **Father Eli:** Tinawag niya akong “Father.”
> **Father Eli:** Bibili raw siya ng laruan kay Gloria mamayang hapon. Para sa birthday ng bata.

`tokhang_peter_holding.png`
> **???:** May baril 'yan! May baril! *(Alaala 3 held: the speaker reads **Batista**)*

`tokhang_peter_shot.png` — gunshot, hold.
Card: **Peter** — *Nanlaban daw.* → Alaala 1.

**Gwen** (`tokhang_gwen`)
`tokhang_gwen_holding.png`
> **???:** May baril 'yan! May baril! *(Alaala 3 held: **Batista**)*

`tokhang_gwen_shot.png` — gunshot, hold. Card: **Gwen** — *Nanlaban daw.*
`tokhang_flashback_ben.png`, caption *Flashback*:
> **Gwen:** Ben, ubusin mo 'yang gulay, kundi walang regalo bukas.
> **Ben:** Inubos ko na po!

→ Alaala 1.

**Ligtas** (`tokhang_safe`)
`tokhang_safe_market.png`
> **Batista:** ...Laruan.
> **Batista:** *Sa radyo* Negative. Tubig lang ang laman. Atras muna.

`tokhang_safe_home.png`
> **Ben:** *Binasa si Peter* Bang! Patay ka na, Kuya!
> **Peter:** Aray. Tinamaan ako. *Humiga sa sahig*
> **Gwen:** Tumayo ka na diyan. May sasabihin ako.

Card: **Ligtas** — *Walang nabaril sa palengke.*

---

## 8. KUMPISAL (Saturday afternoon; player: Father Eli)

One version for every run: it is the earliest story in time, so nothing played before it can change
it. It gains lines only from memories.

### 8.1 Opening

`church_nave` background
> **Father Eli:** Sabado. Alas-tres hanggang alas-sais, bukas ang kumpisalan.
> **Father Eli:** Ang naririnig ko rito, dito lang.

### 8.2 The nave (route: Gloria → Gwen and Ben → Mercy → Batista → booth)

Objectives: Talk to Gloria, Talk to Gwen and Ben, Talk to Mercy, Talk to Batista, Go to
confessional booth.

**Gloria**
> **Father Eli:** Gloria. Hindi ka nagtinda ngayon?
> **Gloria:** Mamaya pa po, Father. Sinundo ko pa sa terminal 'yung pamangkin ko. Galing Samar.
> **Gloria:** 'Yun pong nabanggit ko sa inyo. Naghahanap ng mapapasukan.
> **Father Eli:** Nasaan siya?
> **Gloria:** Nandiyan po sa likod, nagdadasal. Mahiyain lang, Father, pero masipag 'yan.

**Gwen and Ben** (together)
> **Ben:** Father! Birthday ko bukas!
> **Father Eli:** Talaga? Ilang taon ka na?
> **Ben:** Pito! Bibilhan ako ni Kuya Peter ng baril! 'Yung mukhang totoo!
> **Gwen:** Laruan, Ben. Laruan.
> **Gwen:** Pasensya na po, Father. Kung anu-ano kasi ang napapanood sa TV.
> **Father Eli:** Ikaw, Gwen? Matagal na kitang hindi nakikita sa pila.
> **Gwen:** ...Mamaya po, Father. Pipila po ako.

**Mercy** (ordinary choice)
> **Mercy:** Magandang hapon po, Father. Ako po si Mercy, pamangkin po ni Tita Gloria.
> **Mercy:** Pasensya na po sa abala. Sabi po ni Tita, may kakilala raw po kayong naghahanap ng kasambahay.
> **Father Eli:** Malayo ang Samar. Kumain ka na ba?
> **Mercy:** Opo. Okay lang po ako. Basta po may trabaho, kahit ano po.

| Choice | After | Flag |
|---|---|---|
| Wala kang dapat ipag-alala, anak. | **Mercy:** Salamat po, Father. Ngayon lang po kasi ako lumuwas. | `run_echo_mercy_reassured` |
| May naghihintay ba sa'yo sa inyo? | **Mercy:** Si Nanay po, saka dalawa kong kapatid. Ako na lang po ang inaasahan nila. / **Father Eli:** Gano'n ba. | `run_echo_mercy_asked` |

> **Father Eli:** Hintayin mo 'ko pagkatapos ng kumpisal. Ako na ang maghahatid sa'yo.

**Batista** (ordinary choice)
> **Batista:** Father! Pasensya na, hindi ako nakaabot sa misa. Duty.
> **Father Eli:** Lagi ka namang duty.
> **Batista:** *Tumawa* Parang kailan lang, pareho pa tayong sakristan dito.
> **Batista:** May lakad kami mamayang gabi, diyan lang sa likod. Baka maingay. Pakisabi na lang sa mga kapitbahay mo.

| Choice | After | Flag |
|---|---|---|
| Mag-ingat kayo. | **Batista:** Lagi naman, Father. | `run_echo_batista_careful` |
| Hindi dito pinag-uusapan 'yan. | **Batista:** *Tumingin sa paligid* Oo nga pala. Mamaya na lang. | `run_echo_batista_warned` |

### 8.3 The confessions (in the booth)

Order, in every run: **Gwen, Batista, Gloria, Kulas.**

**Gwen** (ordinary choice)
> **Gwen:** Basbasan n'yo po ako, Father, dahil nagkasala ako. Dalawang taon na po mula nung huli akong nangumpisal.
> **Gwen:** Buntis po ako. Hindi pa po kami kasal.
> **Gwen:** Hindi ko pa po nasasabi kay Peter. Kulang na nga po 'yung kinikita namin. Gabi-gabi pa siyang nasa daan.

| Choice | After | Flag |
|---|---|---|
| Sabihin mo na sa kanya, anak. | **Gwen:** ...Bukas po. Pagkatapos ng birthday ni Ben. | `run_echo_gwen_tell` |
| Ipagdasal mo muna, anak. | **Gwen:** Opo, Father. Pero natatakot po ako. | none |

> **Father Eli:** Ang bata, hindi kasalanan.
> **Father Eli:** Tatlong Aba Ginoong Maria. Humayo ka nang mapayapa.

**Batista** (ordinary choice)
> **Batista:** Father. *Huminga nang malalim* Ayoko sanang dito 'to sabihin.
> **Batista:** 'Yung tatlo nung Martes. Isa lang do'n ang may baril talaga.
> **Batista:** 'Yung dalawa... kami na ang naglagay.
> **Batista:** Hindi ako humihingi ng tawad, Father. Gusto ko lang may ibang nakakaalam.

| Choice | After | Flag |
|---|---|---|
| Walang kapatawaran kung itutuloy mo. | **Batista:** Alam ko. Pero kung hihinto ako, sino'ng tutuloy? | `run_echo_batista_stop` |
| Alam ng Diyos ang bigat ng trabaho mo. | **Batista:** Buti pa Siya, alam. | `run_echo_batista_weight` |

> **Father Eli:** Pinapatawad ka na. Humayo ka.

**Gloria** (ordinary choice)
> **Gloria:** Father... may mga pinapaluwas po akong bata galing probinsya. Para magtrabaho.
> **Gloria:** Pag naibigay ko na po sa amo, hindi ko na po sila kinukumusta. Hindi ko na po tinatanong kung saan napunta.
> **Gloria:** Kasalanan po ba 'yon, Father? 'Yung hindi pagtatanong?

| Choice | After | Flag |
|---|---|---|
| Alam mo na ang sagot, Gloria. | **Gloria:** *Matagal bago sumagot* ...Opo. | `run_echo_gloria_repent` |
| Ang Diyos ang huhusga sa puso mo. | **Gloria:** Salamat po, Father. Gumaan po ang loob ko. | `run_echo_gloria_judged` |

> **Gloria:** 'Yung pamangkin ko po, Father. Kayo na po ang bahala sa kanya.
> **Father Eli:** Oo.

**Kulas** (Alaala choice)
> **Kulas:** Father... hindi ko alam kung paano 'to.
> **Kulas:** Tatlong linggo na 'kong malinis. Gusto ko na talagang tumigil.
> **Kulas:** Nasa listahan daw ako. *Tumawa nang mahina* Kaya nga nandito ako.

**Memory-gated lines (Alaala 2, `pagtakbo_ni_kulas`):**
> **Kulas:** May isa pa, Father. Nung isang buwan, binayaran ako para magbuhat ng maleta.
> **Kulas:** Mabigat. Tapos... gumalaw.
> **Kulas:** Hinatid ko sa apartment diyan sa tapat. Third floor. Hindi na 'ko nagtanong.
> **Father Eli:** ...Sino'ng nagbayad sa'yo?
> **Kulas:** Si Aling Gloria po.

Without the memory, instead:
> **Father Eli:** Umuwi ka muna, Kulas. Ako na'ng bahala sa'yo.

With the memory, the final choice:

| Choice | Effect |
|---|---|
| Umuwi ka muna, anak. | **Father Eli:** Ako na'ng bahala sa'yo. The usual ending: Kulas is shot. |
| Hintayin mo 'ko. Sabay na tayong lumabas. | ✦ (Alaala 2) Sets `run_kulas_safe`. Ending: **Sinamahan**. |

### 8.4 The ending steps

**Kulas shot** (unless `run_kulas_safe`; outcome `kumpisal_kulas` → Alaala 2)
If Alaala 3 is held, `kumpisal_eli_hears.png`:
> **Father Eli:** *Mahina, sa cellphone* Pare. Palabas na. Payat, naka-sumbrero.

`tokhang_kulas_runs.png`
> **???:** Hoy! Huminto ka! *(Alaala 3 held: **Batista**)*

`kumpisal_gunshot.png` — gunshot, hold.
Card: **Kulas** — *Nanlaban daw.*

**Sinamahan** (`run_kulas_safe`; outcome `kumpisal_sinamahan`)
`kumpisal_eli_kulas_walk.png`
> **Batista:** Father. *Tiningnan si Kulas* Kasama mo pala 'yan.
> **Father Eli:** Ihahatid ko siya pauwi.
> **Batista:** ...Sigurado ka?
> **Father Eli:** Ihahatid ko siya, Batista.

Card: **Sinamahan** — *Nakauwi si Kulas.*

**Mercy crosses the street** (both versions), `church_nave` background:
> **Mercy:** Father, malayo po ba 'yung bahay ng amo ko?
> **Father Eli:** Hindi. Diyan lang sa tapat.

**Eli's last prayer** (Alaala choice), `kumpisal_eli_forgiveness.png`:

| Choice | Effect |
|---|---|
| Panginoon... patawarin Mo ako. | The usual end of the story. |
| Ama, aaminin ko na ang lahat. | ✦ (Alaala 3) Sets `run_eli_confessed` (Padala: **Pinalaya**). `kumpisal_eli_penitent.png`: **Father Eli:** Basbasan Mo ako, Ama, dahil nagkasala ako. |

---

## 9. PADALA (Saturday night; player: Mercy)

One version for every run. Mercy is locked in the apartment across the street while the man
bathes. If Father Eli confessed in Kumpisal earlier in this run (`run_eli_confessed`), **Pinalaya**
replaces the room.

### 9.1 Intro (echoes of Kumpisal, when it was played earlier in the run)

`padala_gloria_mercy.png`
> **Mercy:** Sabi ni Tita, mabait daw ang pari. May kakilala raw siyang naghahanap ng kasambahay.
> **Mercy:** “Wala kang dapat ipag-alala,” sabi niya. *(echo, `run_echo_mercy_reassured`)*
> **Mercy:** Tinanong pa niya kung may naghihintay sa'kin sa probinsya. Akala ko, nag-aalala lang siya. *(echo, `run_echo_mercy_asked`)*
> **Mercy:** Umiyak si Tita nung iniwan niya ako. Hindi ko alam kung bakit. *(echo, `run_echo_gloria_repent`)*
> **Mercy:** Hindi man lang lumingon si Tita. *(echo, `run_echo_gloria_judged`)*

`padala_luggage.png`
> **Mercy:** May maletang nakabukas sa sahig. Walang laman.

`padala_beaten.png` — no line, hold.

`padala_bath.png`
> **Mercy:** Naliligo siya. May oras pa ako.

### 9.2 The room

Objectives: Read the police emergency poster / Or the food delivery flyer / Or find the right
key. After a card is read: Use the telephone / Or find the right key.

| Moment | Line |
|---|---|
| Door | **Mercy:** Naka-lock. Sa labas ang kandado. |
| Phone, no number yet | **Mercy:** Wala akong kabisadong numero. |
| Reads the poster | **Mercy:** May numero ng pulis. |
| Reads the flyer | **Mercy:** Delivery. Kung may darating... may makakakita sa'kin. |
| Wrong key | **Mercy:** Hindi 'to. |
| First wrong key | **???:** *Sa banyo* Mercy? Ano 'yang ingay? (heard from the bathroom; with Alaala 3 the speaker reads **Father Eli**) / **Mercy:** W-wala po. |
| After two wrong keys | **Mercy:** Teka... 'yung isa, kupas na. Parang laging ginagamit. |

The right key is one of five.

### 9.3 Police poster (`padala_police`; Alaala 3)

`padala_phone_call.png`
> **Mercy:** *Pabulong* Hello? Pulis po ba 'to? Tulungan n'yo po ako. Nakakulong po ako.
> **Boses:** Saan ka?
> **Mercy:** Hindi ko po alam ang address. May simbahan po sa tapat. Third floor po.
> **Boses:** ...Diyan ka lang. Papunta na kami.

`padala_police_car.png`
> **Batista:** ...Father?
> **Batista:** Ikaw pala 'yan, pare.
> **Batista:** Mag-ingat daw kami, sabi mo kanina. *(echo, `run_echo_batista_careful`)*
> **Batista:** Hindi raw doon pinag-uusapan. *Tumingin sa loob* Dito na lang pala. *(echo, `run_echo_batista_warned`)*

`padala_eyes_widen.png`, `padala_luggage_closed.png` — hold.
Card: **Police Poster** — *Hindi na nakauwi si Mercy.*
`padala_dressing.png`
> **Father Eli:** Panginoon... patawarin Mo ako.

`padala_reveal_eli.png`, caption *Father Eli*, hold.

### 9.4 Food delivery (`padala_food`; Alaala 5)

Sets `run_peter_seen` (Tokhang reads it).

`padala_phone_call.png`
> **Mercy:** Hello po? Magpapadeliver po ako. Kahit ano po.
> **Mercy:** *Pabulong* Pakisabi po sa rider, tulungan n'yo po ako. Room 3B, sa tapat ng simbahan.

**Alaala choice (Alaala 5, `rider`):**

| Choice | Effect |
|---|---|
| 'Yun lang po. | The usual ending. |
| Pakisabi pong magsama siya ng tanod. | ✦ Sets `run_tanod`. Ending: **Tanod**. |

**Usual:** `padala_peter_arrives.png`, where Eli answers the door
> **Peter:** Delivery po!
> **???:** *Binuksan ang pinto* Ako na.
> **Peter:** ...Father Eli? Kayo po pala.
> **Peter:** Pasensya na po. Parang may sumigaw po kasi sa loob—
> **Father Eli:** TV lang 'yon, hijo. Salamat. Ingat ka sa daan.
> **Father Eli:** *Binasa ang resibo* ...Peter.

`padala_luggage_closed.png` — hold.
Card: **Food Delivery** — *Umalis ang rider. Hindi na nakauwi si Mercy.* → Alaala 5.

**Tanod** (`padala_tanod`)
`padala_tanod.png`
> **Peter:** Delivery po. *Lumingon sa tanod* Dito po, Kuya.
> **Tanod:** Barangay po. Pakibuksan ang pinto.
> **Tanod:** ...Father?

Card: **Tanod** — *Nakalabas si Mercy.*

### 9.5 The right key: outside

`padala_collar.png`
> **Mercy:** ...Pari?

`padala_escape.png` — hold.
`padala_still_manila.png`
> **Mercy:** Hindi ko alam kung nasaan ako. May mga ilaw sa dulo ng kalye.

| Choice | Effect |
|---|---|
| Tumakbo papunta sa ilaw. | Sets `run_echo_mercy_ran`. Ending **Run**. |
| Magtago hanggang magliwanag. | ✦ (Alaala 4, `baril_ni_batista`) Ending **Nagtago**. |

**Run** (`padala_run`; Alaala 4)
`padala_run.png`
> **???:** Hoy! Huminto ka! *(Alaala 3 held: **Batista**)*

`padala_run_shot.png` — gunshot, hold; over the body:
> **Batista:** *Hinihingal* ...Sino'ng tutuloy kung hihinto ako. *(echo, `run_echo_batista_stop`)*
> **Batista:** Alam ng Diyos ang bigat nito. Alam Niya. *(echo, `run_echo_batista_weight`)*

Card: **Run** — *Nanlaban daw.*

**Nagtago** (`padala_nagtago`)
`padala_hide_dawn.png`
> **Mercy:** 'Nay? ...Ako po 'to.
> **Mercy:** Uuwi na po ako.

Card: **Nagtago** — *Umuwi si Mercy.*

### 9.6 Pinalaya (`padala_pinalaya`, when `run_eli_confessed`)

`padala_eli_unlocks.png`
> **Mercy:** Huwag po... huwag po.
> **Father Eli:** *Iniwan ang susi sa sahig* Nasa baba ang mga tanod. Sinabi ko na sa kanila ang lahat.
> **Father Eli:** Umuwi ka na, Mercy.

Card: **Pinalaya** — *Pinalaya si Mercy.*

---

## 10. TRUE ENDING: "Walang Namatay"

Played by `end_run` after the last story of any run whose outcomes include `kumpisal_sinamahan`,
`padala_pinalaya` and `tokhang_safe`, (reachable when the run begins at the market or the church; see section 4), using `prologue.json`
`"epilogue"`. It adds the outcome `walang_namatay`, and the recap's closing voice line is skipped.

`true_morning_family.png`
> **Gwen:** Mahal... buntis ako.
> **Peter:** ...Seryoso? *Tumawa, tapos naiyak*

`true_morning_kulas.png`, `true_morning_mercy.png`, `true_morning_batista.png` — three pictures, no
lines, each held about 3 seconds.

`true_visiting.png`: a prison visiting booth, glass and a small grille like a confessional.
> **Father Eli:** Basbasan n'yo po ako, Padre, dahil nagkasala ako.
> **Father Eli:** Matagal na po mula nung huli akong nangumpisal.
> **Father Eli:** Ito na po ang buong kumpisal.

Card: **Walang Namatay** — *SANGA*.

---

## 11. Art list

| File | Scene |
|---|---|
| `tokhang_safe_market.png` | Batista holding up the water gun at Gloria's stall |
| `tokhang_safe_home.png` | Ben squirting Peter at the door, Gwen laughing |
| `kumpisal_eli_kulas_walk.png` | Eli walking Kulas past Batista |
| `kumpisal_eli_penitent.png` | Eli kneeling on the penitent's side of his own booth |
| `padala_tanod.png` | Peter with tanods at the door |
| `padala_hide_dawn.png` | Mercy at a jeepney terminal at dawn, on the phone |
| `padala_eli_unlocks.png` | Eli at the open door, the keys left on the floor |
| `true_morning_family.png`, `true_morning_kulas.png`, `true_morning_mercy.png`, `true_morning_batista.png` | Peter and Gwen, Kulas, Mercy, Batista |
| `true_visiting.png` | Eli behind the visiting-booth grille |
| `prologue_booth.png` | The confessional's small door, in darkness |
| `padala_collar.png` | A black clerical shirt with a white collar hanging on the bathroom door |

No longer used by the script: `tokhang_kulas_shot.png`, `kumpisal_eli_sacrifice.png`,
`padala_peter_fights.png`, `padala_peter_stabbed.png`, `padala_eli_attacks.png`,
`padala_police_car_leaves.png`, `padala_jeep.png`, `padala_police_laugh.png`.

### Art to re-check against the new lines

Existing files that now show a different moment than before (no new files are to be invented):

- `tokhang_trade.png`: now Batista and Father Eli at the altar the night after Peter was seen at the door (only when `run_peter_seen`), not a trade.
- `kumpisal_eli_kulas_walk.png`: Eli walking Kulas out; Batista only asks, no men at the gate.
- `padala_peter_arrives.png`: Eli answers the door and Peter recognises him.
- `tokhang_kulas_runs.png` and `kumpisal_gunshot.png`: now used in Kumpisal (Kulas shot after leaving the church), not Tokhang.
- `padala_tanod.png`: Peter and the tanod at the door, Eli in the hallway.
- `padala_eli_unlocks.png`: Eli leaves the key on the floor and does not kneel with it.
- `kumpisal_eli_hears.png`: Eli on the phone saying Kulas is leaving.
- `padala_run_shot.png`: Batista over the body, out of breath.
- `padala_police_car.png`: Batista says "Father?" and "pare" (he recognises Eli).

## 12. Presentation: 2D with 2.5D staging (decided)

The game stays **2D**. It gains depth through **2.5D staging**, not a 3D rebuild.

**Why not 3D:** a 3D rebuild means new models, rigs, lighting and a new art style, and it
would replace the hand-painted 90s anime look that sets SANGA apart. Judges score the
concept, the story and how finished it feels. A polished 2D game with a strong mechanic beats
a rough 3D one.

**What 2.5D adds (in this order):**

1. **Layered places.** Each of the four places is split into three depth layers
   (background, middle, foreground). The camera drifts slowly; nearer layers move more, so
   the room has real depth. The foreground layer already exists in the market (the blurred
   motorcycle); the rest follows that example.
2. **Living cutscenes.** Every cutscene picture gets a slow push-in, and the key reveals
   (Eli at the door, the trade, the visiting booth) are split into two or three layers for
   parallax.
3. **Breathing characters.** A subtle breathing and sway shader on standing characters and
   dialogue portraits.
4. **Light.** Light pools and moving shadows (window light in the apartment, candles in the
   church), building on the existing prop grounding.
