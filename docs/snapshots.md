# Topaz Snapshot Status

No verified Topaz snapshot is configured.

Valley of Gnoland blocks snapshot application until a Topaz-specific provider, archive format, and integrity verification are confirmed. The former UTSA archive is for Test13 and must not be extracted into `~/gno/gnoland-data` after migrating to Topaz.

Menu option `1c` and `resources/apply_snapshot.sh` are intentionally non-mutating. They report the unavailable status and exit without stopping the service or changing files.

Use normal peer sync from the official Topaz seeds:

```text
g19q07ssuafhmg6r7ys7wp7rpc4jxc85cpvdy426@seed-1.topaz.testnets.gno.land:26656,g15k98e65gm8h7fdr3yr4tqn82lvch4a97a3sg3j@seed-2.topaz.testnets.gno.land:26656
```

Check progress with menu option `1e. Show Node Status`.

last updated by: John
