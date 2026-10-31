# Changelog

## 0.2.1
- **START pauses instead of ending.** An accidental press no longer ends the session. START pauses (time freezes, the Garmin activity timer stops, no vibrations); on the Paused screen START resumes and BACK finishes to the summary. Paused time is not counted in the duration, and the 30 s pulses and the target alert continue from the active time (an already reached target does not fire again). A short vibration confirms pause and resume.
- **Readable heart rate:** a large white number with a small heart icon replaces the "HR 71" text ("--" when there is none).
- **Target always visible:** the top line shows "Target 2:00" before and after the target. After the target the big number is the total time; before it, the countdown. Both stay blue (green for 5 s at the target).
- Home: the three-dot marker next to the LIGHT button is gone; "Hold UP to switch" is written on Home instead.

## 0.2.0
- **Cold plunges.** ColdStart now has two session types, Cold Shower and Cold Plunge. Hold UP on Home to switch; the choice is remembered, shown at the top of Home, and becomes the name of the Garmin activity. The streak and "Last" count both types together.
- Wording is neutral for both ("Discard session?", "No sessions yet"). Hold UP does nothing during a session or on the summary, and the summary no longer opens the discard prompt from the menu key (BACK does).
- README notes that optical heart rate is unreliable under water.

## 0.1.3
- **Target alert reworked.** The target now gives a single 1 s vibration at full strength, then a second 1 s vibration 2 s later. The tone plays with the second one, so it can't cut the first short. 0.1.2's three-part pattern with pauses gave no vibration on a Forerunner 965.
- **Stronger 30 s pulses:** 300 ms at full strength (was 200 ms at 60 %).
- **"Target!" cue:** for 5 s after the target, the ring and time turn green and "Target!" shows.
- **Summary heart rate in labelled columns:** MIN, AVG and MAX, with "HR bpm" underneath.
- README notes that Do Not Disturb can silence app vibrations.

## 0.1.2
- **Touch is ignored.** Every screen now reads the physical buttons directly. In 0.1.1, a tap on a touchscreen watch could start or stop a shower.
- Shorter discard-prompt hint ("START ok · BACK no") so it fits the round screen.

## 0.1.1
- **Crash recovery.** A shower in progress is saved every 30 s. If the app dies mid-shower, the next launch keeps the streak day and the last duration and shows "Recovered m:ss". The Garmin activity itself can't be recovered.
- **Steadier timer.** It no longer jumps if the watch syncs its clock mid-shower.
- **Heart rate simplified** to min, avg and max. The cold-shock response and HRV were removed.
- **New app icon:** an ice-blue snowflake with a green start badge, with a 40 px version for smaller watches.
- Fixes found by the strict compile check.

## 0.1.0
- **First release.** A cold-shower timer for 53 five-button Garmin watches on Connect IQ 5 or later:
  - target countdown, set with UP/DOWN in 15 s steps
  - pulses every 30 s and an alert at the target
  - overtime count after the target
  - Garmin Connect activity (Meditation/Breathing) with heart rate
  - daily streak and the last duration on Home

**Not yet confirmed on a real watch:** the 0.1.3 vibrations, and touch being ignored.
