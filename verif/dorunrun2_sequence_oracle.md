# Do! Run Run set 2 PCB sequence oracle

Use `check_dorunrun2_sequence.ps1` with both `dorunrun2.zip` and its parent
`dorunrun.zip`. The packer validates every ROM by CRC32 and SHA-1, selects game
ID 9, and forces both DIP banks to all OFF (`FF,FF`).

The real-board sequence documented by MAME for the first twelve demo rounds is:

1. Right; clears all monsters and takes E.
2. Left; takes A, then dies.
3. Right; clears all monsters.
4. Left; kills X.
5. Right.
6. Left; takes T.
7. Right.
8. Left; kills E, which is already held.
9. Right.
10. Left; kills R.
11. Right.
12. Moves, kills A, and shows the extra-Mr.-Do win.

The current workspace has no `dorunrun2.zip`, so deterministic RAM/frame
signatures for automatic action recognition cannot be recorded yet. Do not use
the parent `dorunrun` set as a substitute; its demo program differs.
