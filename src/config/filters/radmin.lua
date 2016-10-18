FILTER{ "radmin-fail-access";
  enabled = false;
  -- radmin 2.2
  source  = "file:c:/logfile.txt";
  -- radmin 3.0
  -- source  = "file:C:/WINDOWS/system32/rserver30/Radm_log.htm";
  exclude = WHITE_IP;
  hint    = "Password is incorrect";
  failregex = {
    -- radmin 2.2
    "^[%d+%.<>: ]+Connection from ([%d+%.]+) : Password is incorrect or error occurs";
    -- radmin 3.0
    "^&lt;%d+&gt; RServer3 [^()]+%(([%d%.]+)%).-Password is incorrect or error occurs";
  };
}
