PROGRAM Master_Poll
  VAR
    Level_Remote AT %IW100 : INT;
    High_Remote  AT %IW101 : INT;
    Low_Remote   AT %IW102 : INT;
  END_VAR

  (* Keep the program body non-empty *)
  Level_Remote := Level_Remote;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK Tick(INTERVAL := T#100ms, PRIORITY := 0);
    PROGRAM Main WITH Tick : Master_Poll;
  END_RESOURCE
END_CONFIGURATION
