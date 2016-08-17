-- Configure system
-- 1. Install SNMP Service
--  * Dism.exe /online /enable-feature /featurename:SNMP
--  * Dism.exe /online /enable-feature /featurename:"WMISnmpProvider"
-- 2. Go to Services->`SNMP Service`
-- 3. Go to Traps tab
-- 3.1 Add `public` to Community list
-- 3.2 Add `127.0.0.1` to trap destinations
-- 4. Go to Security tab
-- 4.1 Check send authentications trap
-- 4.2 Add `public`/`READ ONLY` to accepted community
-- 5. Run `evntwin`
-- 5.1 Check `Custom` configuration
-- 5.2 Press `Edit>>>`
-- 5.3 Select `Security/Security`
-- 5.4 Add events 529 or 4625 (depend on Windows version)
-- 6. Run `gpedit.msc`
-- 6.1 Go to Computer / Windows Settings / Security Settings / Local Policies / Audit Policy
-- 6.2 Set `Audit account logon`  events = Success, Failure

FILTER{ "rdp-fail-access";
  enabled = false;
  source  = "trap:udp://127.0.0.1";
  exclude = WHITE_IP;
  trap    = {529, 4625};
  failregex = {
    "Source Network Address:%s+([0-9.]+)";
    --cp1251
    "Адрес сети источника:%s+([0-9.]+)";
  }
};

