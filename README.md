# nextfin

nextfin is an open source jellyfin client built with flutter

it exists because i wanted a jellyfin app that felt a bit nicer to use day to day and did not immediately fall apart when talking to different server setups

it is still a work in progress but it is past the toy stage and actually usable

## what it does right now

- server login and saved sessions
- home screen with continue watching latest stuff next up favorites and library jumps
- library browsing and filtering
- search with live results and recent searches
- item details with play resume favorite and watched state actions
- playback with progress reporting resume support and player controls
- themes settings and some server diagnostics
- android pip and media controls work is in here too

## current state

android is the main target right now

the app runs and the core stuff works but there are still rough edges here and there especially around server specific playback quirks and some of the longer tail polish work

some settings are still pretty barebones and not everything is fully wired on every platform

## get it

if you just want to try nextfin the easiest move is to grab the latest apk from the releases page on github

that is the main way this repo is meant to be installed right now

## screenshots

![nextfin screenshot 1](https://cdn.getswift.cloud/4kb6l)

![nextfin screenshot 2](https://cdn.getswift.cloud/6asae)

![nextfin screenshot 3](https://cdn.getswift.cloud/f5ki3)

## project layout

- `lib/core` app level stuff like api routing theme storage and compatibility bits
- `lib/features` screens and feature code
- `lib/shared` models and reused widgets
- `android` android app config and launcher assets

## rough edges

- some jellyfin playback behavior still depends a lot on the server setup
- secure storage is not wired yet and sessions are still stored with shared preferences
- a few settings and diagnostics bits are still a little scrappy

## roadmap maybe

- more player polish
- better offline story
- nicer library views on bigger screens
- more cleanup around server specific playback weirdness

## contributing

issues and prs are welcome

if you find a bug or something feels off open an issue

if you want to send a fix go for it

## license

apache 2.0

see [LICENSE](LICENSE)
