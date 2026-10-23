PROGRAM Tank_Control
  VAR
    (* ---------- Coils ---------- *)
    Pump_Run   AT %QX0.0 : BOOL;   (* status: program-driven *)
    Valve_Open AT %QX0.1 : BOOL;   (* command: written over Modbus *)
    Alarm_HH   AT %QX0.2 : BOOL;   (* status: level >= 95 % *)

    (* ---------- Holding registers ---------- *)
    Level_Pct  AT %QW0 : INT;      (* measurement, 0..100 % *)
    High_SP    AT %QW1 : INT;      (* setpoint: pump stops at or above *)
    Low_SP     AT %QW2 : INT;      (* setpoint: pump starts below *)
  END_VAR
  VAR
    Level      : REAL := 50.0;     (* simulated tank level, % *)
    Inflow     : REAL;
    Outflow    : REAL;
    First_Scan : BOOL := TRUE;
  END_VAR

  (* Defaults applied once at start-up; later Modbus writes persist *)
  IF First_Scan THEN
    Valve_Open := TRUE;
    High_SP    := 80;
    Low_SP     := 20;
    First_Scan := FALSE;
  END_IF;

  (* Alarm and pump control with hysteresis *)
  Alarm_HH := Level >= 95.0;

  IF Alarm_HH THEN
    Pump_Run := FALSE;
  ELSIF Level < INT_TO_REAL(Low_SP) THEN
    Pump_Run := TRUE;
  ELSIF Level >= INT_TO_REAL(High_SP) THEN
    Pump_Run := FALSE;
  END_IF;

  (* Simulated tank: pump adds 2 %/s, open valve removes 1 %/s *)
  Inflow := 0.0;
  Outflow := 0.0;
  IF Pump_Run THEN
    Inflow := 2.0;
  END_IF;
  IF Valve_Open AND Level > 0.0 THEN
    Outflow := 1.0;
  END_IF;

  Level := Level + (Inflow - Outflow) * 0.1;   (* 0.1 s per scan *)
  IF Level > 100.0 THEN
    Level := 100.0;
  END_IF;
  IF Level < 0.0 THEN
    Level := 0.0;
  END_IF;

  Level_Pct := REAL_TO_INT(Level);
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK Tick(INTERVAL := T#100ms, PRIORITY := 0);
    PROGRAM Main WITH Tick : Tank_Control;
  END_RESOURCE
END_CONFIGURATION
