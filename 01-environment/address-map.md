# Address Map

Process: water tank with an inlet pump and an outlet valve. The pump
fills the tank; the outlet valve drains it. The level is read as a
percentage (0-100). All addresses below are Modbus wire addresses
(0-based), as observed on the plc (192.168.56.4), function codes 1
(read coils) and 3 (read holding registers).

## Coils

| Address | IEC name  | Meaning              | Normal range / behavior                                  |
|---------|-----------|----------------------|-----------------------------------------------------------|
| 0       | %QX0.0    | Pump running         | 0 or 1 — on below Low_SP, off at/above High_SP (hysteresis) |
| 1       | %QX0.1    | Outlet valve open     | 1 (open) by default at start-up; program never changes it |
| 2       | %QX0.2    | High-high alarm (Alarm_HH) | 0 under normal operation; briefly 1 for ~1 scan (~100ms) only if level reaches 95% |

## Holding registers

| Address | IEC name | Meaning           | Normal range                       |
|---------|----------|-------------------|-------------------------------------|
| 0       | %QW0     | Tank level (%)    | ~19-81, cycling (fill/drain pattern)|
| 1       | %QW1     | High setpoint (%) | 80 (design range 70-90)             |
| 2       | %QW2     | Low setpoint (%)  | 20 (design range 10-30)             |

## Control logic (summary)

- Pump turns ON when `Level < Low_SP`, turns OFF when `Level >= High_SP`.
  Between the two thresholds, the pump keeps its previous state
  (hysteresis).
- `Alarm_HH` is a hard-coded, non-writable safety condition:
  `Level >= 95.0` (evaluated on the internal REAL value, not the
  rounded INT register). When true, it force-stops the pump
  regardless of the writable setpoints. It is independent of
  High_SP/Low_SP and cannot be disabled via Modbus.
- The outlet valve has no automatic control logic in this version of
  the program; it is only ever changed by an external Modbus write
  (coil 1).

## Baseline traffic footprint (established from a ~5 minute capture)

- Single source: the master, 192.168.56.3
- Single function code: 3 (READ_HOLDING_REGISTERS), reading addresses
  0-2 (level, high_sp, low_sp)
- Single persistent TCP connection, reused for the whole session
- Request rate: approximately 8 requests/second
- No writes, no exceptions, no other function codes, no other source,
  observed at any point in the baseline capture

This footprint is the basis for every detection rule: any deviation
from it (different function code, different source, a write, an
exception, or a volume/connection-count anomaly) is treated as
anomalous.
