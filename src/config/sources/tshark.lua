local tshark = 'process:C:/Program Files/Wireshark/tshark.exe'
local args = '-l -i 6 -f "port 5060" '
  .. '-o gui.column.format:Time,%Yt -T fields '
  .. '-e _ws.col.Time -e ip.src -e sip.Method '
  .. '-e ip.dst -e sip.r-uri.host -e sip.r-uri.user '

SOURCE{"tshark-sip-request", tshark;
  args = args .. '-Y "sip.Request-Line != """""';
  restart = 5;
  monitor = 'stdout';
  eol = {'\r\n', false};
  -- env = {};
  -- max_line = 4096
}

SOURCE{"tshark-sip-options", tshark;
  args = args .. '-Y "sip.Method == ""OPTIONS"""';
  restart = 5;
  monitor = 'stdout';
  eol = {'\r\n', false};
  -- env = {};
  -- max_line = 4096
}
