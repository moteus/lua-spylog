-- https://www.badips.com
-- to set Key you need call `curl http://www.badips.com/set/key/<key>`
-- in jail e.g. `action = {'ipsec', {'badips', {category='sip'}}}`

ACTION{"badips",
  ban = 'curl --fail --user-agent "SpyLog" https://www.badips.com/add/<category>/<host>';

  unique = 'badips <HOST>';

  parameters = {
    category = 'sip';
  };

  options = {
    timeout = 10000;
  };

};
