-- https://www.badips.com
-- in jail e.g. `action = {'ipsec', {'badips', {category='sip'}}}`

ACTION{"badips",
  ban = 'curl --fail --user-agent "SpyLog" https://www.badips.com/add/<category>/<host>';

  parameters = {
    category = 'sip';
  };

  options = {
    timeout = 10000;
  };

};
