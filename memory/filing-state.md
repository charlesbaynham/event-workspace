# Memory filing state

<!--
Written by the memory-compact skill's filing pass, and by nothing else.
last_run is when the last pass started gathering: the next pass reads the
sessions, commits and log entries that came after it. retry lists sessions
whose review failed and must be read next time. Git history keeps the earlier
values.
-->

last_run: never
last_commit: none
last_sessions: 0
retry:
