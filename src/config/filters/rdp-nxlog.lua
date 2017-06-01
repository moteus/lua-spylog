-- When use NTLM auth event 4625 has no IP address
-- so we should use different event but this event can not 
-- be forwarded by SNMP so we have to use some external tool.
--
-- Forward eventlogs using nxlog (http://nxlog.co)
--
-- <Input eventlog>
--   Module       im_msvistalog
--   SavePos      TRUE
--   ReadFromLast TRUE
--   Channel      "Microsoft-Windows-RemoteDesktopServices-RdpCoreTS/Operational"
--   <QueryXML>
--     <QueryList>
--       <Query Id="0" Path="Microsoft-Windows-RemoteDesktopServices-RdpCoreTS/Operational">
--         <Select Path="Microsoft-Windows-RemoteDesktopServices-RdpCoreTS/Operational">*[System[(EventID=140)]]</Select>
--       </Query>
--     </QueryList>
--   </QueryXML>
-- </Input>
-- 
-- <Output spylog>
--   Module      om_udp
--   Host        127.0.0.1
--   Port        614
--   Exec        $raw_event = "EventID: " + $EventID + "; " + $Message;
-- </Output>
-- 
-- <Route 1>
--   Path        eventlog => spylog
-- </Route>
--
FILTER{ "rdp-fail-access-140-nxlog";
  enabled = false;
  source = "nxlog";
  exclude = WHITE_IP;
  hint = "EventID: 140;";
  failregex = {
    "^EventID: 140; A connection from the client computer with an IP address of ([%d%.:]+)";
    -- UTF8
    "^EventID: 140; Не удалось подключить клиентский компьютер с IP%-адресом ([%d%.:]+)";
  };
};
