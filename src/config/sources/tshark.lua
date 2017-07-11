SOURCE{"tshark-sip-request",
  'process:C:/Program Files/Wireshark/tshark.exe';
  args = '-i 6 -f "port 5060" -o gui.column.format:"Time,%Yt" -T fields '
      .. '-e _ws.col.Time -e ip.src -e ip.dst -e sip.r-uri.host -e sip.r-uri.user -e sip.Request-Line '
      .. '-Y "sip.Request-Line != """""';
  restart = 5;
  monitor = 'stdout';
  eol = {'\r\n', false};
  -- env = {};
  -- max_line = 4096
}
