ACTION{"growl",
  ban   = { "@spylog.actions.growl", [["SpyLog ban <HOST>" "
Filter: <FILTER>
Jail:   <JAIL>
Host:   <HOST>
<MSG>"]]};

  unban = { "@spylog.actions.growl", [["SpyLog unban <HOST>" "
Filter: <FILTER>
Jail:   <JAIL>
Host:   <HOST>
<MSG>"]]};

  options = {
    address  = "127.0.0.1";
    -- port     = "23053";
    -- password = "secret";
    -- encrypt  = "AES";
    -- hash     = "SHA256";
  }
};
