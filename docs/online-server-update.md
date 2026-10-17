# Dedicated room capacity — 1.1.6

Default app endpoint: `18.143.103.253:47520/UDP`.

The updated native dedicated server defaults to 64 players per room. A server
started with an explicit limit of 32 still has a 32-player limit. Different room
names and game-mode prefixes select separate rooms. Updating the IPA cannot
change a capacity limit in the running server executable.

Start the matching Linux x64 release asset with:

```sh
chmod +x mugoat-server
./mugoat-server 47520 64
```

For an existing systemd service, preserve its current user, working directory,
room/network configuration and rollback executable. Replace the executable and
set its existing command's port/capacity arguments to `47520 64`, then restart
that service. Keep UDP 47520 allowed in the existing host/firewall configuration.
Do not start a second process on the occupied port.

CI starts isolated local server processes and tests 32 and 64 real UDP sockets:
unique IDs, state/name/shot relay, every peer reaching the first/last client,
rejection of the 33rd/65th client, room isolation (including room changes), and
reuse of a departed player's slot. This is a transport/capacity test, not a
64-phone rendering/performance benchmark or proof of the live server deployment.

Vehicle damage no longer treats a replica's local physics death as permission
to explode the owner's car. Hits must originate from local player damage, target
the owner's current vehicle model/instance and be applied while PVP is enabled
and the owner is driving. The vehicle-death bit in the owner's STATE remains
authoritative. Older unscoped VHIT packets are ignored by the new client; update
players together for matching hit synchronization.
