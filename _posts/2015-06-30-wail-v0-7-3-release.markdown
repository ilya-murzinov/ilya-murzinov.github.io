---
layout: post
title: "WAIL v0.7.3 Release"
modified:
categories: 
excerpt:
image:
  feature:
tags: [java, android]
comments: on
date: 2015-06-30T21:55:38+00:00
---

Almost exactly half a year have passed since the latest [WAIL](https://github.com/artem-zinnatullin/android-wail-app) release (0.7.2), and I finally found the time to prepare the next one.

Even though this is a minor release, it contains a relatively major change - browser based (or "desktop", as LastFM API reference calls it) authentication. It allows WAIL to get session key for user without requiring him to type his username/password directly inside the app. This is obviously a great feature, because many people do not trust third-party applications. So this [pull request](https://github.com/artem-zinnatullin/android-wail-app/pull/150) is one of those, which I am proud of.

Of course this release as well contains lot of fixes of really annoying bugs (mostly in the scrobbling logic).

Also after a brief discussion with [@artem-zinnalullin](https://github.com/artem-zinnatullin) we decided to remove "Ignore player" functionality introduced in the previous release. The reason for this is that WAIL is unable to properly distinguish currently playing player based on intents they broadcast. Thus, this "feature" is not only useless, but also can interrupt the normal functioning.

The summary of the 0.7.3 release (links to issues work [here](https://github.com/artem-zinnatullin/android-wail-app/releases/tag/v0.7.3beta)):

 - Browser based authentication (#15)
 - Support for RocketPlayer (#58)
 - New launcher icons (#98)
 - Add option to "love" previously scrobbled track (#115)
 - Korean translation
 - Add option for minimum priority notification (#130)
 - Remove "ignore player" functionality (#155)
 - Bugfixes (#26, #61, #80, #132, #133, #134, #135, #162)
 
 I hope I will be able to work on the next release soon, because there are some new features I really want to implement.
 
 That's all for now, have a nice day!