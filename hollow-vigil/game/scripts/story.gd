class_name Story
## All written lore. Many documents change once the player has already been through the loop.


static func orders() -> Array:
	if Game.loop == 1:
		return ["FIELD ORDERS — EYES ONLY", "[b]AGENT E. ROOK[/b]\n\nSix days ago, a research team led by [b]Dr. Lena Hart[/b] stopped transmitting from the mountain village of [b]Grauwald[/b]. Their final transmission was a forty-second recording of church bells. Nothing else.\n\nLocate Dr. Hart. Recover the team if possible. Recover the data if not.\n\nExtraction will be waiting at the cliff pad beyond the old chapel. Do not provoke the locals.\n\n— Handler\n\n[i]P.S. The road is out past the tree line. You'll have to walk.[/i]"]
	elif Game.loop == 2:
		return ["FIELD ORDERS — EYES ONLY", "[b]AGENT E. ROOK[/b]\n\n[b]Seven years ago[/b], Agent [b]Elias Rook[/b] stopped transmitting from the mountain village of Grauwald. His final transmission was a forty-second recording of church bells.\n\nLocate Agent Rook.\n\n...\n\n[i]You read it three times. It is your name.[/i]\n\n[i]At the bottom of the page, in handwriting you recognise as your own:[/i]\n[b]THE BELL WAS BROKEN ONCE. FIVE PIECES ARE STILL OUT THERE. FIND THEM BEFORE YOU FIND HIM.[/b]"]
	return ["FIELD ORDERS — EYES ONLY", "[b]ELIAS.[/b]\n\nIf you're reading this again, you went back up the mountain again.\n\nWe've sent %d cars. Every one of them came back empty with the engine still running.\n\nFive shards. Lena hid them. Break the bell.\n\n[i]The rest of the page is covered in tally marks.[/i]" % Game.loop]


static func ledger() -> Array:
	return ["WOODCUTTER'S LEDGER", "Oct 2 — Doctor's people dug up the old bell under the chapel. Heavy thing. Warm to touch.\n\nOct 4 — Father Aldric rang it at vespers. Most beautiful sound. Mother cried.\n\nOct 6 — Mother hums at night with her mouth closed. I hum too.\n\nOct 7 — The Father says an outsider will come up the road soon. [b]He always does.[/b] We must bring him to the chapel.\n\nOct 8 — hmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm"]


static func notice() -> Array:
	var extra := "" if Game.loop == 1 else "\n\n[i]Someone has scratched beneath it:[/i] WELCOME BACK"
	return ["NOTICE NAILED TO A DOOR", "BY ORDER OF FATHER ALDRIC\n\nAny outsider who comes up the road is to be brought to the Chapel.\n\n[b]The Choir must have a new voice.\nThe Choir must always have a Father.[/b]\n\nAt the tolling of the bell, all shall stop what they are doing and come to prayer." + extra]


static func tally() -> Array:
	if Game.loop == 1:
		return ["BUTCHER'S TALLY", "||||  ||||  ||||  |||\n\n[i]Scrawled on the barn wall beside a hook:[/i]\n\nHe keeps coming. Same coat. Same gun. Same face.\nEvery time he comes, the Father gets happier.\nEvery time the Father dies, the Father comes back.\n\nI do not understand. I just keep count."]
	return ["BUTCHER'S TALLY", "||||  ||||  ||||  ||||  " + "| ".repeat(Game.loop) + "\n\n[i]The newest line is fresh. The blood is still wet.[/i]\n\nIt's you.\nIt's always you.\nWhy do you keep coming back, Father?"]


static func journal() -> Array:
	var p2 := "Day 9 — Aldric showed me a photograph. A man in a leather jacket, standing in front of this chapel. He said, [i]'He was the last Father. He came from outside too.'[/i]\n\nI know that face. It was in our briefing files as our [b]emergency contact[/b].\n\n"
	if Game.is_haunted():
		p2 += "Day 11 — I've hidden the pieces. Five shards of the first bell — the one that broke. If he comes back, if [b]you[/b] come back, Elias: find them. Only something broken can break it."
	else:
		p2 += "Day 11 — They're coming for me. If anyone finds this: [b]don't let him ring you in.[/b]"
	return ["DR. HART'S FIELD JOURNAL", "Day 3 — The bell is not bronze. Spectrography says it's [b]organic[/b]. It grows. The frequency it rings at rewires the auditory cortex. It doesn't kill. [b]It recruits.[/b]\n\nThe villagers call it the Choir. Aldric calls it family.\n\n" + p2]


static func hymn() -> Array:
	Game.flags["hymn_read"] = true
	return ["HYMN OF THE THREE BELLS", "[i]Carved above a child's coffin:[/i]\n\nFirst ring the [b]Lost[/b], who sleep below and do not wake.\nThen ring the [b]Found[/b], who were given wings and flew above.\nLast ring the [b]Mourning[/b], caught between, who weep for both.\n\nRing them so, and the Father will open His house."]


static func grave() -> Array:
	if Game.loop == 1:
		return ["A FRESH GRAVE", "The headstone reads:\n\n[b]E. R—[/b]\n[i](the rest has been scratched away)[/i]\n\n[b]HE CAME HOME.[/b]\n\nSomething metal glints in the loose soil."]
	return ["A FRESH GRAVE", "The headstone reads:\n\n[b]ELIAS ROOK[/b]\n[b]ELIAS ROOK[/b]\n[b]ELIAS ROOK[/b]\n\nHE CAME HOME. HE CAME HOME. HE CAME HOME. HE CAME HOME. HE CAME HOME.\n\n[i]There are %d dates carved beneath the name.[/i]" % Game.loop]


static func confession() -> Array:
	return ["FATHER ALDRIC'S CONFESSION", "I was not born in Grauwald.\n\nI came up the mountain road in a car, to find someone who had gone missing. I found the bell instead.\n\nI killed the Father, as I was trained to do. And when he fell, the Choir sang [b]my[/b] name.\n\nIt is not a curse. It is a [b]succession[/b].\n\nWhoever kills the Father becomes the Father. The bell only needs a voice.\n\nI am so tired. I think someone is coming up the road.\n\n— A.\n\n[i]In the corner, a faded photograph of a man in a leather jacket. The name on the back has been rubbed out.[/i]"]


static func lena_lines() -> Array:
	if Game.loop == 1:
		return [
			["LENA", "You're... you're not one of them. Your eyes are clear."],
			["ROOK", "Dr. Hart? Agent Rook. I'm getting you out of here."],
			["LENA", "Rook...? No. No, that's not possible. You're in our files. You've been missing for years."],
			["ROOK", "I've been missing for about three hours. Where's the key?"],
			["LENA", "Take it. The Father's in the sanctum. But Elias — whatever he tells you down there... don't listen. Please."],
		]
	return [
		["LENA", "...You again."],
		["ROOK", "Dr. Hart, I'm—"],
		["LENA", "Agent Rook. Here to get me out. I know. You said that last time. And the time before."],
		["LENA", "Look at your left hand, Elias. Count them."],
		["LENA", "Take the key. And if you found the shards — %s" % ("you did. I can hear them humming. Break it. Please, this time, break it." if Game.shards >= 5 else "you haven't. I can tell. Then it's going to happen again.")],
	]
