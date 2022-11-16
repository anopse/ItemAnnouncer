# ItemAnnouncer

WoW Classic Addon to automatically send some messages when specific item links is sent in chat.

This addon use an external configuration that is supposed to be imported, as a way to know which messages to send when a specific item is linked in chat.

I currently use it myself in a GDKP raid to announce minimum bid prices of linked items and other information like that.

# Import Format

If you're reading this on CurseForge, because CurseForge Markdown does not support blocks of code properly, you should look at examples and format explanation directly on [GitHub](https://github.com/anopse/ItemAnnouncer).

## Basic example

```
;
/rw;/raid
Foo-Benediction;Bar-Benediction
32247;/g Ring of Captured Storms is good for casters;/raid Ring of Captured Storms Minbid is 100
32234;/g Fists of Mukoa is good for enhancement shaman;/raid Fists of Mukoa Minbid is 200
32238;/g Ring of Calming Waves is good for healers;/raid Ring of Calming Waves Minbid is 200
```

The import data is splitted into two parts, the header (always 3 lines), and the items data.

### Header

#### First header line : Separator

First header line should contain only 1 character which will be used as a separator in ALL other lines, in this example it's the character `;`, any character except new lines are accepted as a separator and no escape sequence is currently supported, so make sure this character appears nowhere in your actual data.

#### Second header line : Channels to watch

Second header line should contains channels where the messages will be scanned for item links in it. The supported channels are :

 - Say (`/s`, `/say`)
 - Yell (`/y`, `/yell`)
 - Party (`/p`, `/party`)
 - Raid (`/raid`)
 - Raid Warning (`/rw`, `/raidwarning`)
 - Guild (`/g`, `/guild`)
 - Officer (`/o`, `/officer`)

#### Third header line : Characters to watch messages from

Third header line should contains the names of the characters you want the addon to be triggered by, only those in this list will trigger it, the name of the character should be the full player name (`name-server`). There is currently no way to specify a wildcard.

### Items data

There can be as many lines as you want, each line start with the item id then followed by messages to send when specific item id. (duplicated lines will return an error, you should have only 1 line per item ID) 

The supported channels to send to are the same as the ones in the header, beware that some channel have some restriction from WoW API for sending message, for example addons can't send a message in `/s` except inside instances. This addon will just not send the message if the condition to send it isn't met.

## Advanced example

```
$
/raid
Foo-Benediction$Bar-Benediction
32247$[Announce]/g Ring of Captured Storms is good for casters$[^Minbid]/raid Ring of Captured Storms Minbid is 100
32234$[^Gargul][Announce]/g Fists of Mukoa is good for enhancement shaman$[Announce][^Minbid]/raid Fists of Mukoa Minbid is 200
32238$[Announce][Healer]/g Ring of Calming Waves is good for healers$/raid Ring of Calming Waves Minbid is 200
```

### Blacklisting and whitelisting

Before each message you can put a list of string to match against in the content of the message to decide if the message should be sent or not. This feature is particularly useful to avoid sending a message when the item is linked by another addon, like for example Gargul looting or trading message.

- `[Announce]` means the received message should contains `Announce` for the automatic message to be sent.
- `[^Announce]` means the received message should NOT contains `Announce` for the automatic message to be sent.
- `[Announce][Healer]` means the received message should contains `Announce` AND `Healer` for the automatic message to be sent.
- `[^Announce][Healer]` means the received message should NOT contains `Announce` AND should CONTAINS `Healer` for the automatic message to be sent.

Those condition applies to the specific message only, so if you have multiple messages for the same item, each message has its own condition, see third line of the example)
