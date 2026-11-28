# Six-park walking route audit

`SixParkRouteAudit.swift` asks MapKit for a walking route in both directions
between two representative priority-one attractions in every supported park.
It records route distance, ETA, step count, and how far MapKit snaps each
requested endpoint to its route network.

This is a live provider probe, not a deterministic test. Results can change as
Apple updates its routing graph. Keep each run as a dated TSV under `results/`.
The deterministic model tests use a fake provider and remain the CI gate.

Compile and run from the repository root:

```sh
xcrun swiftc -parse-as-library Tools/WalkingRoutes/SixParkRouteAudit.swift -o /tmp/parkio-six-park-route-audit
/tmp/parkio-six-park-route-audit
```

The 2026-10-20 audit returned 12 of 12 routes. The largest destination snap
remaining in that sample was 67 m at Hollywood Studios' Rise of the Resistance,
below the 75 m review threshold used for a targeted entrance override. Magic
Kingdom's Space Mountain uses a routing-only entrance coordinate; its forward
destination snap was 0 m. This sample supports the provider choice but does not
prove complete pedestrian-path coverage or accessibility of every route.
