# nextfin

nextfin is an open source jellyfin client for android built with flutter

it started as a nicer way to watch stuff from jellyfin without ending up in a clunky utility app and it has slowly turned into a real daily driver

the goal is pretty simple

- keep playback solid
- keep the app fast
- make it feel good to use
- keep supporting weird real world jellyfin setups instead of only the easy cases

## current state

android is the main target right now

the app is usable and the core flow is there

- login with saved accounts
- home recommendations continue watching and pinned stuff
- library browsing search and details pages
- movie episode and live tv playback
- subtitles resume pip and android media controls
- watch history downloads and live channel favorites
- themes settings and account switching

there are still things to tighten up here and there but this is not a toy repo anymore

## get it

if you just want to try it grab the latest apk from the github releases page

that is the main install path right now

## screenshots

![nextfin screenshot 1](https://cdn.getswift.cloud/ji60v)

![nextfin screenshot 2](https://cdn.getswift.cloud/qs2dy)

![nextfin screenshot 3](https://cdn.getswift.cloud/ayrou)

## repo layout

- `lib/core` app wiring api routing theme storage and compatibility bits
- `lib/features` actual screens and feature code
- `lib/shared` models and shared widgets
- `android` android config activity code and launcher assets

## rough edges

- jellyfin servers can still differ a lot in how they expose playback sources
- the offline story is now usable but still young compared to the rest of the app
- there is still a lot of room for more polish around edge cases and server quirks

## contributing

issues and prs are welcome

if something is broken open an issue

if you want to send a fix go for it

## license

apache 2.0

see [LICENSE](LICENSE)
