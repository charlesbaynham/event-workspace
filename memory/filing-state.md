# Memory filing state

<!--
Written by the memory-compact skill's filing pass (last_run, last_commit,
last_sessions, retry) and the migrate skill (migrated), and by nothing else.
last_run is when the last pass started gathering: the next pass reads the
sessions, commits and log entries that came after it. retry lists sessions
whose review failed and must be read next time. migrated lists the major-
version migrations this memory has been through; a workspace born on a major
already has that major's structure. Git history keeps the earlier values.
-->

last_run: never
last_commit: none
last_sessions: 0
retry:
migrated: 1.0.0
