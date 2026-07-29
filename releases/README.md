# Universal_DoCastle release staging

This directory contains nine generated MRAs. Every one selects:

    <rbf>Universal_DoCastle</rbf>

The active FPGA filename is Universal_DoCastle.rbf. It was built on 2026-07-29
with Quartus 17.0.2 for 5CSEBA6U23I7 after the software verification gates
passed. SHA-256:

    44DFFD87A3E86DD52EA669154B7AB1B2BF613EE9B59E6A643535DA2627CC7E88

The older DoCastle_20260729.rbf is retained under releases/legacy only as the
historical single-game baseline. It does not support the universal MRAs.

ROM ZIPs belong in /media/fat/games/mame/ and are not part of this project.
Deploy the universal RBF under /media/fat/_Arcade/cores/ and the individual
MRAs under /media/fat/_Arcade/ when an on-device test is requested.
