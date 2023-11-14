# smart-test-monitor
Monitor the progress of your SMART selftest.


> **Currently only supports SAS drives.**


```
+------------------------------------------------------------------------------------------+
 SMART Test Progress Monitor - Refresh in 9m 23s
+------------------------------------------------------------------------------------------+
1) /dev/sdb [▰▰▰▰▰▰▰▱▱▱][70%] 12h / 18h (5h remaining)
2) /dev/sdd [▰▰▰▰▰▱▱▱▱▱][47%] 8h / 18h (9h remaining)
3) /dev/sde [▰▰▰▰▰▰▰▱▱▱][64%] 11h / 18h (6h remaining)
4) /dev/sdf [▰▰▰▰▰▰▰▱▱▱][61%] 11h / 18h (7h remaining)
5) /dev/sdg [▰▰▰▰▰▰▱▱▱▱][57%] 10h / 18h (7h remaining)
```

## Usage
```
./smart-test-monitor.sh [Options] <DISKS>

Options               Description
----------            ---------------
-r SECONDS            Set the refresh interval between smartctl polls
-s SECONDS            Set the update interval of the internal script
```

### Examples
For single disk: 
```
./smart-test-monitor /dev/sda
```

For multiple disks:
```
./smart-test-monitor /dev/sda sdb sdc
```

> `/dev/` directory may be omitted







