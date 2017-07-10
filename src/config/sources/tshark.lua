SOURCE{"tshark-sip-request",
  'process:"C:/Program Files/Wireshark/tshark.exe" -l -i 6 -f "port 5060" -T fields -e ip.src -e ip.dst -e sip.Request-Line -Y "sip.Request-Line != """""',
  -- args = {}
  restart = 5;
  monitor = 'stdout';
  eol = {'\r\n', false};
  -- env = {};
  -- max_line = 4096
}
