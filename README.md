# smart-test-monitor
Monitor the progress of your SMART selftest.

```
+------------------------------------------------------------------------------------------+
| SMART Test Progress Monitor                                                              |
+------------------------------------------------------------------------------------------+
1) /dev/sdb [▰▰▰▰▰▰▰▱▱▱][70%] 12h / 18h (5h remaining)
2) /dev/sdd [▰▰▰▰▰▱▱▱▱▱][47%] 8h / 18h (9h remaining)
3) /dev/sde [▰▰▰▰▰▰▰▱▱▱][64%] 11h / 18h (6h remaining)
4) /dev/sdf [▰▰▰▰▰▰▰▱▱▱][61%] 11h / 18h (7h remaining)
5) /dev/sdg [▰▰▰▰▰▰▱▱▱▱][57%] 10h / 18h (7h remaining)
```

## Usage
`./smart-test-monitor <DISKS>`

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






